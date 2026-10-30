#!/usr/bin/env python3
"""Index hook activity from the hook-run log and session transcripts, then build a local portal."""
import argparse
import html
import importlib.util
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from urllib.parse import quote

WINDOW_DAYS = 30
EXCERPT = 200
SILENT_AFTER_DAYS = 7
REFUSAL = re.compile(r"(PreToolUse:\w+) hook error: \[(.+?)\]: (.*)", re.S)

here = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("delegation_stats", here / "delegation-guard-stats.py")
stats = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stats)

SCHEMA = """
create table if not exists files(path text primary key, offset integer not null);
create table if not exists runs(
  source text not null, kind text not null, at integer not null, hook text not null, event text,
  ms integer, exit integer, blocked integer not null default 0, bytes integer not null default 0,
  session text, excerpt text, uid text unique
);
create index if not exists runs_hook_at on runs(hook, at);
"""


def hook_name(command):
    wrapped = re.search(r"hook-run\s+\S+\s+(\S+)", command)
    if wrapped:
        return wrapped.group(1)
    scripts = re.findall(r"[\w./${}-]+\.(?:sh|py|mjs|js|cmd)\b", command)
    if scripts:
        return re.sub(r"\.\w+$", "", scripts[-1].rsplit("/", 1)[-1])
    return command.split()[0].rsplit("/", 1)[-1] if command.split() else "unknown"


def is_internal(command):
    # Claude Code stores a hook's status message or "callback" in this field for some hooks.
    return "/" not in command


def timestamp(entry):
    try:
        return int(datetime.fromisoformat(entry["timestamp"].replace("Z", "+00:00")).timestamp())
    except (KeyError, ValueError, AttributeError):
        return None


def row(kind, at, command, event, session, ms=None, code=None, blocked=0, size=0, excerpt=None):
    return ("transcript", kind, at, hook_name(command), event, ms, code, blocked, size, (session or "")[:8], excerpt, None)


def rows_from_entry(entry):
    """Forked sessions copy their history with its uuids, so the uuid keeps one run from counting twice."""
    if not isinstance(entry, dict):
        return []
    uuid = entry.get("uuid")
    rows = parse_entry(entry)
    return [(*r[:-1], f"{uuid}:{i}" if uuid else None) for i, r in enumerate(rows)]


def refusals(entry, at):
    """A PreToolUse refusal is recorded only as the text of the failed tool result."""
    content = (entry.get("message") or {}).get("content")
    found = []
    for block in content if isinstance(content, list) else []:
        text = block.get("content") if isinstance(block, dict) and block.get("type") == "tool_result" else None
        match = REFUSAL.match(text) if isinstance(text, str) else None
        if match and not is_internal(match[2]):
            found.append(row("block", at, match[2], match[1], entry.get("sessionId"), blocked=1, excerpt=match[3][:EXCERPT]))
    return found


def parse_entry(entry):
    """Turn one transcript line into run rows. Lines without a command cannot be attributed."""
    at = timestamp(entry)
    if at is None:
        return []
    session = entry.get("sessionId")
    if entry.get("type") == "user":
        return refusals(entry, at)
    if entry.get("subtype") == "stop_hook_summary":
        return [
            row("run", at, info["command"], "Stop", session, ms=info.get("durationMs"))
            for info in entry.get("hookInfos") or []
            if isinstance(info, dict) and info.get("command") and not is_internal(info["command"])
        ]
    attachment = entry.get("attachment")
    if not isinstance(attachment, dict):
        return []
    kind = attachment.get("type")
    event = attachment.get("hookEvent")
    if kind == "hook_blocking_error":
        error = attachment.get("blockingError")
        if isinstance(error, dict) and error.get("command") and not is_internal(error["command"]):
            text = str(error.get("blockingError", ""))[:EXCERPT]
            return [row("block", at, error["command"], attachment.get("hookName") or event, session, blocked=1, excerpt=text)]
        return []
    command = attachment.get("command")
    if not command or is_internal(command):
        return []
    # Stop runs already come from stop_hook_summary.
    if kind == "hook_success" and event != "Stop":
        size = len(str(attachment.get("stdout") or "").encode())
        return [row("run", at, command, attachment.get("hookName") or event, session, attachment.get("durationMs"), attachment.get("exitCode"), 0, size)]
    if kind == "hook_non_blocking_error":
        text = str(attachment.get("stderr") or attachment.get("stdout") or "")[:EXCERPT]
        return [row("error", at, command, attachment.get("hookName") or event, session, attachment.get("durationMs"), attachment.get("exitCode"), excerpt=text)]
    return []


def rows_from_wrapper(entry):
    if not isinstance(entry.get("at"), int) or not entry.get("hook"):
        return []
    code = entry.get("exit")
    # Exit 2 is how a hook refuses, so it is a block rather than a failure.
    kind = "error" if code not in (0, 2, None) else "run"
    return [("wrapper", kind, entry["at"], entry["hook"], entry.get("event"), entry.get("ms"), code, int(bool(entry.get("blocked"))), entry.get("bytes") or 0, entry.get("session"), None, None)]


def read_new_lines(db, path):
    """Yield complete new lines since the stored offset, so a line still being written waits."""
    try:
        size = os.path.getsize(path)
    except OSError:
        return
    known = db.execute("select offset from files where path = ?", (str(path),)).fetchone()
    offset = known[0] if known else 0
    if size < offset:
        offset = 0
    if size == offset:
        return
    with open(path, "rb") as source:
        source.seek(offset)
        for line in source:
            if not line.endswith(b"\n"):
                break
            offset += len(line)
            yield line
    db.execute("insert into files(path, offset) values(?, ?) on conflict(path) do update set offset = excluded.offset", (str(path), offset))


def insert(db, rows):
    db.executemany("insert or ignore into runs values(?,?,?,?,?,?,?,?,?,?,?,?)", rows)


def index(db, projects, wrapper_log):
    for line in read_new_lines(db, wrapper_log):
        try:
            insert(db, rows_from_wrapper(json.loads(line)))
        except (ValueError, AttributeError):
            continue
    for root, _, names in os.walk(projects):
        for name in names:
            if not name.endswith(".jsonl"):
                continue
            batch = []
            for line in read_new_lines(db, Path(root) / name):
                if b"hook" not in line:
                    continue
                try:
                    batch += rows_from_entry(json.loads(line))
                except (ValueError, AttributeError):
                    continue
            insert(db, batch)
    db.commit()


def registered_hooks(settings):
    """Own hooks named in settings.json, so one that never produced anything still gets a row."""
    try:
        data = json.loads(Path(settings).read_text())
    except (OSError, ValueError):
        return {}
    found = {}
    for groups in (data.get("hooks") or {}).values():
        for group in groups:
            for hook in group.get("hooks", []):
                match = re.search(r"hook-run\s+\S+\s+(\S+)", hook.get("command", ""))
                if match:
                    found[match.group(1)] = True
    return found


def percentile(values, share):
    ordered = sorted(values)
    return ordered[min(int(len(ordered) * share), len(ordered) - 1)] if ordered else None


def load_runs(db, since):
    """Prefer wrapper data: once a hook has it, transcript runs from then on would double count."""
    first_wrapper = dict(db.execute("select hook, min(at) from runs where source = 'wrapper' group by hook"))
    runs = defaultdict(list)
    for source, kind, at, hook, event, ms, code, blocked, size, excerpt in db.execute(
        "select source, kind, at, hook, event, ms, exit, blocked, bytes, excerpt from runs where at >= ? order by at", (since,)
    ):
        if source == "transcript" and kind != "block" and at >= first_wrapper.get(hook, at + 1):
            continue
        if source == "transcript" and kind == "block" and at >= first_wrapper.get(hook, at + 1):
            kind = "block_text"
        runs[hook].append({"source": source, "kind": kind, "at": at, "event": event, "ms": ms, "exit": code, "blocked": blocked, "bytes": size, "excerpt": excerpt})
    return runs, first_wrapper


def summarize_hook(rows):
    runs = [r for r in rows if r["kind"] in ("run", "error")]
    wrapper_at = [r["at"] for r in rows if r["source"] == "wrapper"]
    blocks = [r for r in rows if r["kind"] == "block" or (r["source"] == "wrapper" and r["blocked"])]
    ms = [r["ms"] for r in runs if isinstance(r["ms"], (int, float))]
    return {
        "runs": len(runs),
        "blocks": len(blocks),
        "errors": sum(r["kind"] == "error" for r in rows),
        "p50": percentile(ms, 0.5),
        "p95": percentile(ms, 0.95),
        "total_ms": sum(ms),
        "bytes": sum(r["bytes"] for r in rows),
        "last": max((r["at"] for r in rows), default=None),
        "wrapper": bool(wrapper_at),
        "wrapper_days": (max(wrapper_at) - min(wrapper_at)) / 86400 if wrapper_at else 0,
    }


def ms_text(value):
    if value is None:
        return "-"
    if value >= 3_600_000:
        return f"{value / 3_600_000:.1f} ч"
    if value >= 60_000:
        return f"{value / 60_000:.0f} мин"
    return f"{value / 1000:.1f} с" if value >= 1000 else f"{round(value)} мс"


def size_text(value):
    if not value:
        return "-"
    return f"{value / 1024 / 1024:.1f} МБ" if value >= 1024 * 1024 else f"{max(value / 1024, 0.1):.1f} КБ"


def when(at):
    return datetime.fromtimestamp(at).strftime("%d.%m %H:%M") if at else "никогда"


def page_name(hook):
    return "hook-" + re.sub(r"[^\w-]+", "_", hook) + ".html"


def status(s, own):
    if s["errors"]:
        return "ошибки"
    if s["blocks"]:
        return "блокирует"
    if s["bytes"]:
        return "подсказывает"
    if not own or not s["wrapper"]:
        return "нет данных" if own else "-"
    return "молчит" if s["wrapper_days"] >= SILENT_AFTER_DAYS else "мало данных"


def render_table(hooks, own):
    head = (
        '<tr><th>Хук</th><th class="n">Запуски</th><th class="n">Блоки</th><th class="n">Ошибки</th>'
        '<th class="n">p50</th><th class="n">p95</th><th class="n">Контекст</th><th>Последний раз</th><th>Роль</th></tr>'
    )
    body = []
    for name, s in hooks:
        runs = f"{s['runs']}" if s["wrapper"] or not s["runs"] else f"≈{s['runs']}"
        body.append(
            f'<tr><td><a href="{quote(page_name(name))}">{html.escape(name)}</a></td><td class="n">{runs}</td>'
            f'<td class="n">{s["blocks"]}</td><td class="n">{s["errors"]}</td><td class="n">{ms_text(s["p50"])}</td>'
            f'<td class="n">{ms_text(s["p95"])}</td><td class="n">{size_text(s["bytes"])}</td>'
            f'<td class="when">{when(s["last"])}</td><td>{status(s, name in own)}</td></tr>'
        )
    return f'<div class="wrap"><table>{head}{"".join(body)}</table></div>'


def chart_events(rows):
    events = []
    for r in rows:
        if r["kind"] == "block" or (r["source"] == "wrapper" and r["blocked"]):
            events.append({"at": r["at"], "outcome": "blocked"})
        elif r["kind"] in ("run", "error"):
            events.append({"at": r["at"], "outcome": "cleared"})
    return events


def excerpts(rows, kinds):
    picked = [r for r in rows if r["kind"] in kinds and r["excerpt"]][-stats.RECENT:]
    if not picked:
        return '<p class="empty">Пусто.</p>'
    lines = [
        f'<tr><td class="when">{when(r["at"])}</td><td>{html.escape(r["excerpt"])}</td></tr>'
        for r in reversed(picked)
    ]
    return f'<div class="wrap"><table>{"".join(lines)}</table></div>'


def fill(**values):
    page = stats.PAGE.read_text()
    for key, value in values.items():
        page = page.replace("{" + key + "}", value)
    return page


def render_hook(name, rows, today, delegation):
    s = summarize_hook(rows)
    runs_note = "все запуски" if s["wrapper"] else "только запуски с выводом, из транскриптов"
    kpis = "".join([
        stats.kpi(s["runs"], "запусков", runs_note),
        stats.kpi(s["blocks"], "блоков"),
        stats.kpi(s["errors"], "ошибок"),
        stats.kpi(ms_text(s["p50"]), "медиана", f"p95 {ms_text(s['p95'])}"),
        stats.kpi(size_text(s["bytes"]), "вывод в контекст"),
        stats.kpi(when(s["last"]), "последний раз"),
    ])
    extra = '<p class="sub"><a href="delegation-guard.html">Подробный дашборд</a></p>' if name == delegation else ""
    return fill(
        title=html.escape(name),
        period="За 30 дней.",
        back='<a href="index.html">Все хуки</a>' + extra,
        kpis=kpis,
        chart_title="Запуски по дням",
        chart=stats.render_chart(chart_events(rows), today),
        blocks_title="Последние блоки",
        blocks=excerpts(rows, ("block", "block_text")),
        errors="<h2>Последние ошибки</h2>" + excerpts(rows, ("error",)) if s["errors"] else "",
    )


def render_index(hooks, runs, own, today):
    total = lambda key: sum(s[key] for _, s in hooks)
    silent = sum(status(s, name in own) == "молчит" for name, s in hooks)
    kpis = "".join([
        stats.kpi(len(hooks), "хуков", f"своих {len(own)}"),
        stats.kpi(stats.compact(total("runs")), "запусков", "за 30 дней"),
        stats.kpi(total("blocks"), "блоков"),
        stats.kpi(total("errors"), "ошибок"),
        stats.kpi(ms_text(total("total_ms")), "суммарное время", "там, где оно известно"),
        stats.kpi(silent, "молчат", f"{SILENT_AFTER_DAYS}+ дней без блоков и вывода"),
    ])
    events = [event for rows in runs.values() for event in chart_events(rows)]
    return fill(
        title="Хуки Claude Code",
        period="За 30 дней. ≈ значит, что видны только запуски с выводом, из транскриптов. Тихие запуски своих хуков считаются с установки обёртки, а блоки за все 30 дней, поэтому блоков может быть больше запусков.",
        back="",
        kpis=kpis,
        chart_title="Запуски по дням",
        chart=stats.render_chart(events, today),
        blocks_title="Все хуки",
        blocks=render_table(hooks, own),
        errors="",
    )


def build(db, out, settings, delegation_log, now=None):
    now = now or time.time()
    today = datetime.fromtimestamp(now).date()
    runs, _ = load_runs(db, int(now - WINDOW_DAYS * 86400))
    own = registered_hooks(settings)
    names = set(runs) | set(own)
    summaries = {name: summarize_hook(runs.get(name, [])) for name in names}
    hooks = sorted(summaries.items(), key=lambda item: (-(item[0] in own), -item[1]["runs"], item[0]))
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(render_index(hooks, runs, own, today))
    for name in names:
        (out / page_name(name)).write_text(render_hook(name, runs.get(name, []), today, "delegation-guard"))
    (out / "delegation-guard.html").write_text(stats.render(stats.load(delegation_log), today, back=f'<a href="{page_name("delegation-guard")}">delegation-guard</a>'))
    return out / "index.html"


def main():
    home = Path.home() / ".claude"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-open", action="store_true")
    parser.add_argument("--db", default=home / ".hooks-telemetry.sqlite")
    parser.add_argument("--out", default=home / ".hooks-portal")
    args = parser.parse_args()
    db = sqlite3.connect(args.db)
    db.executescript(SCHEMA)
    index(db, home / "projects", home / ".hook-runs.jsonl")
    page = build(db, args.out, home / "settings.json", home / ".delegation-guard.log")
    print(page)
    if not args.no_open:
        subprocess.run(["open", str(page)], check=False)


if __name__ == "__main__":
    sys.exit(main())
