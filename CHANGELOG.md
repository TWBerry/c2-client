# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
