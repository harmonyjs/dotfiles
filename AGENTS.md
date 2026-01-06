# Agent Instructions for harmonyjs/dotfiles

You are maintaining a dotfiles repository that uses GNU Stow for symlink management on macOS. The setup uses Catppuccin Latte theme across all configurations.

## Repository Context
- Configuration files are stored in repository root and symlinked to home directory via `stow -v -t ~ --no-folding .`
- Required stow flags: `-t ~` (target home directory), `--no-folding` (preserve runtime directories), `-v` (verbose)
- `.stow-local-ignore` controls which files should NOT be symlinked
- Machine-specific settings use `*.local` pattern (`.zshrc.local`, `*.local.json`) - never symlinked
- Always verify changes with `just check` (or `./scripts/check`)
- Maintain macOS compatibility with Homebrew-installed dependencies

## Scenario 1: Adding New Dotfile

If a user asks you to add a new dotfile, you must ensure:

1. **Validate Environment**: Confirm you're in the dotfiles directory by checking for presence of existing dotfiles
2. **File Naming**: Create the new file with proper dot prefix naming convention in repository root
3. **Machine-Specific Check**: Determine if this should be a machine-specific file (use `.local` suffix if needed)
4. **Stow Configuration**: Check if the new file should be excluded from symlinking by consulting `.stow-local-ignore` patterns
5. **Conflict Prevention**: Test that stow can create the symlink without conflicts before applying changes
6. **Symlink Creation**: Use `stow -v -t ~ --no-folding .` to create the symlink with required flags
7. **Symlink Validation**: Confirm the symlink was created with relative path (not absolute) and points to dotfiles directory
8. **System Integrity**: Run the verification script to ensure the addition didn't break existing functionality
9. **Documentation Update**: Add the new file to the README.md "What's Included" section with brief description

## Scenario 2: Updating Existing Configuration

When a user requests changes to any configuration file, you must:

1. **Backup Creation**: Always create a timestamped backup of the current configuration before making changes
2. **Configuration Type**: Identify whether you're modifying tmux (.tmux.conf), alacritty (.alacritty.toml), or shell (.zshrc, .zsh_aliases) configuration
3. **Machine-Specific Preservation**: Never modify `.zshrc.local` or `*.local.json` files - these are machine-specific and not version controlled
4. **Theme Preservation**: Maintain the Catppuccin Latte theme consistency while making requested changes
5. **Syntax Validation**: Test that the modified configuration has valid syntax for the specific tool
6. **Live Reload**: Apply configuration changes to any currently running sessions of the affected application
7. **Comprehensive Testing**: Run the full verification suite to confirm all functionality remains intact
8. **Documentation Sync**: Update relevant documentation if changes affect user-visible behavior or keybindings

## Scenario 3: Debugging Configuration Issues

When troubleshooting problems with the dotfiles setup, you should:

1. **Diagnostic Assessment**: Run the verification script first and identify which specific checks are failing
2. **Symlink Integrity**: Verify all symlinks are pointing correctly to files in the dotfiles directory
3. **Path Type Validation**: Check if symlinks use relative paths (correct) vs absolute paths (incorrect) - check script warns about this
4. **Broken Link Detection**: Identify any broken symlinks in the home directory that need attention
5. **Stow Status Check**: Examine stow's simulation output for conflicts, warnings, or other issues
6. **Symlink Recovery**: If symlinks are corrupted or missing, use `stow -D -v -t ~ --no-folding . && stow -v -t ~ --no-folding .` to recreate
7. **Absolute Path Fix**: If absolute symlinks found, remove and recreate with correct stow flags to generate relative paths
8. **Configuration Restoration**: If configurations are broken, restore from the most recent timestamped backup
9. **Final Validation**: Always conclude debugging by running the verification script to confirm resolution

## Critical Requirements
- **Theme Consistency**: Never modify color schemes away from Catppuccin Latte
- **macOS Compatibility**: All changes must work on macOS with Homebrew dependencies
- **Verification Mandatory**: Every change must pass `just check`
- **Backup Safety**: Always create backups before modifying existing configurations
- **Stow Flags**: Always use `-v -t ~ --no-folding` flags with stow commands
- **Symlink Paths**: Ensure symlinks use relative paths, never absolute paths
- **Machine-Specific Files**: Preserve `*.local` pattern files (.zshrc.local, *.local.json) - never modify or version control them
- **Stow Ignore Respect**: Never modify `.stow-local-ignore` without understanding symlink implications
- **Private Submodule Priority**: When modifying stow configuration, maintain priority order: public first, then private (`.private/` is stowed separately)
- **Optional Submodules**: `.private/` submodule is optional - scripts must handle its absence gracefully

