#!/usr/bin/env python3
"""Build a local HTML dashboard from the delegation-guard log and open it."""
import argparse
import html
import json
import statistics
import subprocess
import sys
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path

DAYS = 30
RECENT = 25
BAR_AREA = (720, 180)

PAGE = Path(__file__).resolve().with_suffix(".html")


def load(path):
    events = []
    try:
        lines = Path(path).read_text(errors="ignore").splitlines()
    except OSError:
        return events
    for line in lines:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict) and isinstance(event.get("at"), (int, float)):
            event.setdefault("outcome", legacy_outcome(event))
            events.append(event)
    return events


def legacy_outcome(event):
    if "error" in event:
        return "error"
    return "blocked" if event.get("delegates") else "cleared"


def day_of(event):
    return datetime.fromtimestamp(event["at"]).date()


def summarize(events):
    counts = Counter(e["outcome"] for e in events)
    # Lines written before every stop was logged have no not_candidate partner, so they would inflate the share.
    full = [e for e in events if "session" in e]
    full_counts = Counter(e["outcome"] for e in full)
    full_stops = full_counts["not_candidate"] + full_counts["cleared"] + full_counts["blocked"]
    full_checks = full_counts["cleared"] + full_counts["blocked"]
    after = [e for e in events if e["outcome"] == "after_block"]
    checks = counts["cleared"] + counts["blocked"]
    ms = [e["ms"] for e in events if isinstance(e.get("ms"), int)]
    tokens = [e["tokens"] for e in events if isinstance(e.get("tokens"), int)]
    return {
        "checks": checks,
        "blocked": counts["blocked"],
        "errors": counts["error"],
        "stops": full_stops,
        "candidate_share": full_checks / full_stops if full_stops else None,
        "block_share": counts["blocked"] / checks if checks else None,
        "after": len(after),
        "acted": sum(e.get("tools_after", 0) > 0 for e in after),
        "median_ms": statistics.median(ms) if ms else None,
        "tokens": sum(tokens),
    }


def share(value):
    return "-" if value is None else f"{round(value * 100)}%"


def compact(number):
    if number >= 1_000_000:
        return f"{number / 1_000_000:.1f} млн"
    if number >= 1_000:
        return f"{number / 1_000:.0f} тыс."
    return str(number)


def kpi(value, label, note=""):
    small = f"<small>{html.escape(note)}</small>" if note else ""
    return f'<div class="kpi"><b>{html.escape(str(value))}</b><span>{html.escape(label)}</span>{small}</div>'


def render_kpis(s):
    acted = f"{s['acted']} из {s['after']}" if s["after"] else "-"
    seconds = "-" if s["median_ms"] is None else f"{s['median_ms'] / 1000:.1f} с"
    return "".join([
        kpi(s["blocked"], "блоков", f"{share(s['block_share'])} от {s['checks']} проверок"),
        kpi(acted, "вернулись к работе", "вызвали инструмент после напоминания"),
        kpi(share(s["candidate_share"]), "дошло до модели", f"из {s['stops']} остановок"),
        kpi(seconds, "медиана проверки"),
        kpi(compact(s["tokens"]) if s["tokens"] else "-", "токенов Codex"),
        kpi(s["errors"], "ошибок"),
    ])


def render_chart(events, today):
    days = [today - timedelta(days=i) for i in range(DAYS - 1, -1, -1)]
    cleared, blocked = Counter(), Counter()
    for event in events:
        if event["outcome"] == "cleared":
            cleared[day_of(event)] += 1
        elif event["outcome"] == "blocked":
            blocked[day_of(event)] += 1
    top = max([cleared[d] + blocked[d] for d in days] + [1])
    width, height = BAR_AREA
    slot = width / DAYS
    bar = max(slot - 6, 2)
    unit = (height - 24) / top
    base = height - 20
    parts = [f'<line x1="0" x2="{width}" y1="{base}" y2="{base}" stroke="var(--rule)"/>']
    parts.append(f'<text x="0" y="10">{top}</text>')
    rows = []
    for index, day in enumerate(days):
        x = index * slot + 3
        ok, bad = cleared[day], blocked[day]
        label = day.strftime("%d.%m")
        tip = html.escape(f"{label}\n{bad} блоков\n{ok} без блока", quote=True)
        marks = [f'<rect x="{index * slot:.1f}" y="0" width="{slot:.1f}" height="{height}" fill="transparent"/>']
        y = base
        if ok:
            h = max(ok * unit, 2)
            y -= h
            marks.append(f'<rect class="mark" x="{x:.1f}" y="{y:.1f}" width="{bar:.1f}" height="{h:.1f}" rx="{4 if not bad else 0}" fill="var(--cleared)"/>')
        if bad:
            h = max(bad * unit, 2)
            y -= h + (2 if ok else 0)
            marks.append(f'<rect class="mark" x="{x:.1f}" y="{y:.1f}" width="{bar:.1f}" height="{h:.1f}" rx="4" fill="var(--blocked)"/>')
        parts.append(f'<g class="day" tabindex="0" data-tip="{tip}" aria-label="{tip}">{"".join(marks)}</g>')
        if index % 7 == 2:
            parts.append(f'<text x="{x + bar / 2:.1f}" y="{height - 4}" text-anchor="middle">{label}</text>')
        if ok or bad:
            rows.append(f'<tr><td>{label}</td><td class="n">{bad}</td><td class="n">{ok}</td></tr>')
    legend = '<div class="legend"><span><i style="background:var(--blocked)"></i>Блок</span><span><i style="background:var(--cleared)"></i>Без блока</span></div>'
    svg = f'<svg viewBox="0 0 {width} {height}" role="img" aria-label="Проверки по дням за {DAYS} дней">{"".join(parts)}</svg>'
    table = f'<details><summary>Таблица</summary><div class="wrap"><table><tr><th>День</th><th class="n">Блоков</th><th class="n">Без блока</th></tr>{"".join(reversed(rows))}</table></div></details>'
    return legend + svg + table


def render_blocks(events):
    blocks = [e for e in events if e["outcome"] == "blocked"][-RECENT:]
    if not blocks:
        return '<p class="empty">Блоков пока нет.</p>'
    rows = [
        f'<tr><td class="when">{datetime.fromtimestamp(e["at"]).strftime("%d.%m %H:%M")}</td><td>{html.escape(str(e.get("quote", "")))}</td></tr>'
        for e in reversed(blocks)
    ]
    return f'<div class="wrap"><table>{"".join(rows)}</table></div>'


def render_errors(events):
    errors = [e for e in events if e["outcome"] == "error"][-5:]
    if not errors:
        return ""
    rows = [
        f'<tr><td class="when">{datetime.fromtimestamp(e["at"]).strftime("%d.%m %H:%M")}</td><td>{html.escape(str(e.get("error", "")))}</td></tr>'
        for e in reversed(errors)
    ]
    return f'<h2>Последние ошибки</h2><div class="wrap"><table>{"".join(rows)}</table></div>'


def render(events, today):
    summary = summarize(events)
    if events:
        first = datetime.fromtimestamp(min(e["at"] for e in events)).strftime("%d.%m.%Y")
        period = f"С {first}, график за {DAYS} дней."
    else:
        period = "Данных пока нет."
    replacements = {
        "{period}": html.escape(period),
        "{kpis}": render_kpis(summary),
        "{chart}": render_chart(events, today),
        "{blocks}": render_blocks(events),
        "{errors}": render_errors(events),
    }
    page = PAGE.read_text()
    for key, value in replacements.items():
        page = page.replace(key, value, 1)
    return page


def main():
    home = Path.home() / ".claude"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", default=home / ".delegation-guard.log")
    parser.add_argument("--out", default=home / ".delegation-guard.html")
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()
    Path(args.out).write_text(render(load(args.log), datetime.now().date()))
    print(args.out)
    if not args.no_open:
        subprocess.run(["open", str(args.out)], check=False)


if __name__ == "__main__":
    sys.exit(main())
