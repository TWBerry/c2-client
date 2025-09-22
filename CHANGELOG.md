# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2025-09-21

### Added
- Command wrapper management in `funcmgr.sh`:
  - `register_cmd_wrapper <func>` — register a command wrapper.
  - `unregister_cmd_wrapper` — unregister active wrapper.
  - `cmd_wrapper` — handler that routes commands through the wrapper or leaves them untouched.
- Exit hook system in `funcmgr.sh`:
  - `register_exit_func <func>` — register functions to be executed on client exit.
  - Automatic execution of registered exit functions via `trap EXIT`.
- New module: **Gameover(lay) LPE wrapper**
  - Commands `enable_gameover` and `disable_gameover` for privilege escalation wrapper management.
  - Automatic upload of helper scripts (`gameover.sh`, `gameover_wrapper.sh`).
  - Wrapper integration with `send_cmd`.
- New output helpers for consistent UI:
  - `print_std`, `print_err`, `print_warn`, `print_help`, `print_out`.

### Changed
- `README.md` extended with documentation of previously undocumented functions:
  - Wrapper functions (`register_cmd_wrapper`, `unregister_cmd_wrapper`, `cmd_wrapper`).
  - Exit hook system (`register_exit_func`, `run_exit_funcs`).
- Refined module structure and descriptions for clarity.
- `disable_gameover` now validates that `enable_gameover` was run before allowing cleanup.

### Fixed
- Improved cleanup handling for Gameover(lay) module.
- Better error handling in wrapper registration when target function is missing.


## [1.1.0] - 2025-09-20

### Added
- Command history system with persistent storage in `~/.c2_client_history`
- Basic line editing support for improved user experience
- New `history` command to display recent commands
- New `clear_history` command to clear command history
- Automatic history management (saves last 100 commands)
- Support for command history navigation
- History file management with duplicate prevention

### Changed
- Enhanced input handling with improved read functionality
- Updated command list to include new history commands
- Improved user prompt with username@hostname format
- Modified main loop to support history features
- Overall code improvement
- Some bugs fixed
- Added more comments to code

### Fixed
- Removed readline bind warnings in non-interactive environments
- Improved error handling for history file operations
- Fixed duplicate command saving in history

## [1.0.0] - 2025-09-14

### Added
- Initial modular C2 client skeleton.
- Modular system(see `README.md`).
- Emergency uploader (slow but universal fallback).
- Helpers for base64 encode/decode.
- GitHub Actions workflow (lint/test for Bash).
- Contribution guidelines (`CONTRIBUTING.md`).
- Issue and PR templates.
- License (MIT).
- Changelog file.

### Changed
- N/A

### Fixed
- N/A
