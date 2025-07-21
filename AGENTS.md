# Agent Instructions for harmonyjs/dotfiles

You are maintaining a dotfiles repository that uses GNU Stow for symlink management on macOS. The setup uses Catppuccin Latte theme across all configurations.

## Repository Context
- Configuration files are stored in repository root and symlinked to home directory via `stow .`
- `.stow-local-ignore` controls which files should NOT be symlinked
- Always verify changes with `./scripts/verify-setup.sh`
- Maintain macOS compatibility with Homebrew-installed dependencies

## Scenario 1: Adding New Dotfile

If a user asks you to add a new dotfile, you must ensure:

1. **Validate Environment**: Confirm you're in the dotfiles directory by checking for presence of existing dotfiles
2. **File Naming**: Create the new file with proper dot prefix naming convention in repository root
3. **Stow Configuration**: Check if the new file should be excluded from symlinking by consulting `.stow-local-ignore` patterns
4. **Conflict Prevention**: Test that stow can create the symlink without conflicts before applying changes
5. **Symlink Creation**: Use stow to create the symlink from repository to home directory
6. **Verification**: Confirm the symlink was created correctly and points to the dotfiles directory
7. **System Integrity**: Run the verification script to ensure the addition didn't break existing functionality
8. **Documentation Update**: Add the new file to the README.md "What's Included" section with brief description

## Scenario 2: Updating Existing Configuration

When a user requests changes to any configuration file, you must:

1. **Backup Creation**: Always create a timestamped backup of the current configuration before making changes
2. **Configuration Type**: Identify whether you're modifying tmux (.tmux.conf), alacritty (.alacritty.toml), or shell (.zsh_aliases) configuration
3. **Theme Preservation**: Maintain the Catppuccin Latte theme consistency while making requested changes
4. **Syntax Validation**: Test that the modified configuration has valid syntax for the specific tool
5. **Live Reload**: Apply configuration changes to any currently running sessions of the affected application
6. **Comprehensive Testing**: Run the full verification suite to confirm all functionality remains intact
7. **Documentation Sync**: Update relevant documentation if changes affect user-visible behavior or keybindings

## Scenario 3: Debugging Configuration Issues

When troubleshooting problems with the dotfiles setup, you should:

1. **Diagnostic Assessment**: Run the verification script first and identify which specific checks are failing
2. **Symlink Integrity**: Verify all symlinks are pointing correctly to files in the dotfiles directory
3. **Broken Link Detection**: Identify any broken symlinks in the home directory that need attention
4. **Stow Status Check**: Examine stow's simulation output for conflicts, warnings, or other issues
5. **Symlink Recovery**: If symlinks are corrupted or missing, use stow to remove and recreate them properly
6. **Configuration Restoration**: If configurations are broken, restore from the most recent timestamped backup
7. **Final Validation**: Always conclude debugging by running the verification script to confirm resolution

## Critical Requirements
- **Theme Consistency**: Never modify color schemes away from Catppuccin Latte
- **macOS Compatibility**: All changes must work on macOS with Homebrew dependencies
- **Verification Mandatory**: Every change must pass `./scripts/verify-setup.sh`
- **Backup Safety**: Always create backups before modifying existing configurations
- **Stow Respect**: Never modify `.stow-local-ignore` without understanding symlink implications

