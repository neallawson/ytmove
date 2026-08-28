# ytmove

`ytmove.pl` is a fast Perl command-line utility for identifying and relocating video/audio files downloaded via `yt-dlp` or YouTube downloaders. It reads lines containing YouTube IDs (or URLs) from standard input (`<STDIN>`), scans a source directory for matching media files, moves them into a destination directory, and generates a timestamped log file.

---

## Features

- **Pre-Scanned Fast Indexing**: Indexes files in the source directory once before reading input for fast lookups across large file collections.
- **Multiple Filename Pattern Matchers**:
  1. **Bracketed ID (Preferred)**: Matches the last bracketed 11-character token in the filename stem (e.g., `Track Title [dQw4w9WgXcQ].mp4`).
  2. **Dash-Suffix ID**: Matches 11 valid ID characters at the end of the stem preceded by `-` (e.g., `Artist - Track-xyz98765432.mkv`).
  3. **URL Query Parameter Fallback**: Extracts `v=11chars` from full YouTube URLs piped to standard input (e.g., `https://youtube.com/watch?v=dQw4w9WgXcQ`).
  4. **Raw ID String Fallback**: Accepts bare 11-character ID strings directly.
- **Multi-Format Support**: Relocates all matching media files for a given YouTube ID (e.g., both `.mp4` and `.m4a` files matching the same ID).
- **Dry-Run Mode (`-n`)**: Simulates file moves without modifying files on disk.
- **Verbose Output (`-v`)**: Prints real-time log entries to `STDOUT` alongside the log file.
- **Detailed Audit Logging**: Automatically writes `ytmove_log_YYYYMMDD_HHMMSS.txt` in the source directory with per-file operation records (`MOVED`, `NOT FOUND`, `WARN`, `DRY-RUN`) and summary statistics.

---

## Requirements

- **Perl 5** (uses Perl core modules: `Getopt::Long`, `File::Basename`, `File::Spec`, `File::Copy`, `POSIX`, `Pod::Usage`, `Test::More`, `File::Temp`).

---

## Installation

Clone the repository and ensure `ytmove.pl` is executable:

```bash
chmod +x ytmove.pl
```

---

## Usage

Pipe a file or list of YouTube IDs/URLs into `ytmove.pl` specifying the `-s` (source) and `-d` (destination) directories:

```bash
ytmove.pl -s /path/to/source -d /path/to/destination < list.txt
```

### Options

| Flag | Long Option | Description |
| --- | --- | --- |
| `-s` | `--source` | **Required.** Source directory path containing files to scan and move |
| `-d` | `--destination` | **Required.** Destination directory path to move matched files into |
| `-n` | `--dry-run` | Simulate file moves without relocating files |
| `-v` | `--verbose` | Print log messages to `STDOUT` in addition to writing to the log file |
| `-h` | `--help` | Display usage and help documentation |

---

## Input File Format

The input piped to standard input (`<STDIN>`) can contain URLs, raw YouTube IDs, blank lines, or comments starting with `#`:

```text
# Tracks to move
dQw4w9WgXcQ
https://www.youtube.com/watch?v=xyz98765432

# Additional bare ID
a_b-c123456
```

---

## Log File Format

Each execution creates a timestamped log file inside the source directory (`ytmove_log_YYYYMMDD_HHMMSS.txt`):

```text
[2026-08-28 12:00:00] === Starting ytmove.pl ===
[2026-08-28 12:00:00] Source Dir      : /path/to/source
[2026-08-28 12:00:00] Destination Dir : /path/to/destination
[2026-08-28 12:00:00] Dry Run Mode    : NO
[2026-08-28 12:00:00] Indexed 3 candidate file(s) across 2 unique YouTube ID(s) in source directory.
[2026-08-28 12:00:01] MOVED: '/path/to/source/Track 1 [dQw4w9WgXcQ].mp4' -> '/path/to/destination/Track 1 [dQw4w9WgXcQ].mp4'
[2026-08-28 12:00:01] MOVED: '/path/to/source/Artist - Track 2-xyz98765432.mkv' -> '/path/to/destination/Artist - Track 2-xyz98765432.mkv'
[2026-08-28 12:00:01] NOT FOUND: No file matching YTID 'notfound123' (parsed from 'notfound123') in source folder.
[2026-08-28 12:00:01] === Summary: Lines processed: 3 | Files moved: 2 | Unmatched/Errors: 1 ===
```

---

## Running Tests

The test suite lives under `./tests/` and uses standard Perl `Test::More` TAP harness:

Run all tests:

```bash
prove -v tests/
```

Run an individual test script:

```bash
perl -I. tests/01_extract_id.t
```

### Test Suite Structure

- `tests/01_extract_id.t`: Unit tests for `extract_youtube_id()` subroutine across pattern rules and edge cases.
- `tests/02_cli_options.t`: Integration tests for CLI argument parsing and error validation.
- `tests/03_move_functional.t`: End-to-end test verifying file moves, destination contents, log line assertions, and summary stats.
- `tests/04_dry_run.t`: Integration tests for `--dry-run` (`-n`) and `--verbose` (`-v`) options.

---

## Documentation

Project documentation lives in `./docs/`:

- [`docs/ytmove_plan.txt`](docs/ytmove_plan.txt): Core architecture and design specifications.
- [`docs/ytmove_tests_implementation.txt`](docs/ytmove_tests_implementation.txt): Test suite design specifications and verification walkthrough.
