# Persistent Agent Guidelines & Instructions

## Versioning Standards (`Major.Minor.Patch`)
Adventure Journal follows semantic versioning across all code, metadata, and distribution archives:
- **Major Releases (`X.0.0`)**: Large multi-module ecosystem launches, major structural redesigns, or architectural overhauls.
- **New Features & Large Tasks (`0.X.0`)**: Every feature or non-trivial capability addition increments the minor version (tenths place).
- **Bug Fixes & Hotfixes (`0.0.X`)**: Every bug fix, layout fix, logic correction, or item data fix ALWAYS increments the patch version (third number).

## Mandatory Version Bump Checklist
Whenever completing a bug fix or feature, the agent MUST increment the version in all of the following locations:
1. **Addon TOC**: `Adventure_Journal/Adventure_Journal.toc` (`## Version: X.Y.Z`)
2. **Core Constants**: `Adventure_Journal/Core/Constants.lua` (`Constants.VERSION = "X.Y.Z"`)
3. **Public Landing Page**: `adventure-journal/index.html` (header badge, download button href, download meta tag)
4. **Release Archive**: Re-package `Adventure_Journal-vX.Y.Z.zip` in `adventure-journal`, removing older zip archives.
5. **Two-Tree Sync**: Keep `World of Warcraft Addons` and `adventure-journal` 100% synchronized.
