# GLM-OCR-Desktop

**English** | **[日本語](./README_ja.md)** | **[Deutsch](./README_de.md)**

![version](https://img.shields.io/github/v/release/quwano/GLM-OCR-Desktop?label=version&color=brightgreen)
![license](https://img.shields.io/badge/license-AGPL--3.0-green)
![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-blue)

## About This Project

GLM-OCR-Desktop is a desktop GUI tool that reads PDF, PNG, and JPG files and outputs OCR results as **Markdown** or **plain text**.

- **Text-embedded PDFs** are extracted directly without using the AI model — fast and accurate
- **Image PDFs and PNG/JPG** are processed with layout analysis + GLM-OCR (VLM)
- **UI language is auto-detected**: Japanese / English / Deutsch

### Processing Flow

```
Input
  ├─ PDF (text embedded)  →  Layout analysis + direct text extraction  →  Markdown / Plain Text
  ├─ PDF (image only)     →  Layout analysis + GLM-OCR (VLM)           →  Markdown / Plain Text
  └─ PNG / JPG            →  Layout analysis + GLM-OCR (VLM)           →  Markdown / Plain Text
```

## Screenshot

![GUI Screenshot](docs/images/screenshot.png)

## Quick Installation

Installer scripts for macOS and Windows are available in the `easy_installer/` folder.
Double-click the script for your OS and preferred language:

| OS | Language | File |
|----|----------|------|
| macOS | English | `easy_installer/mac_en/glmocr_mac_installer_en.command` |
| macOS | 日本語 | `easy_installer/mac_ja/glmocr_mac_installer_ja.command` |
| macOS | Deutsch | `easy_installer/mac_de/glmocr_mac_installer_de.command` |
| Windows | English | `easy_installer/win_en/glmocr_win_installer_en.bat` |
| Windows | 日本語 | `easy_installer/win_ja/glmocr_win_installer_ja.bat` |
| Windows | Deutsch | `easy_installer/win_de/glmocr_win_installer_de.bat` |

The installer sets up everything step by step: Python 3.11, virtual environment, packages, and AI model downloads.

For manual installation, see [Requirements](#requirements) below.

## Requirements

### Operating System

- macOS 11 or later (Apple Silicon / Intel)
- Windows 10 or later

### Python

Python 3.11 from [python.org](https://www.python.org/downloads/release/python-31113/) is required.
The python.org version includes tkinter, which is not available in Homebrew Python on macOS.

## Disk Space

The following free disk space is required:

| Item | Size |
|------|------|
| GLM-OCR model | ~2.5 GB |
| PP-DocLayoutV3 model | ~127 MB |
| Python virtual environment (torch, etc.) | ~1 GB |
| **Total** | **~4 GB** |

## Launch

After installation:

- **macOS**: Double-click `GLM-OCR-Desktop.command`
  *(First time: right-click → Open to bypass Gatekeeper)*
- **Windows**: Double-click `GLM-OCR-Desktop.bat`
- **CLI**: `.venv_bundle/bin/python main.py`

## Usage

1. Click **＋ Add Files** or drag and drop PDF / PNG / JPG files
2. Click **▶ Run OCR**
3. Select output format (**Markdown** or **Plain Text**) and click **💾 Save**

Multiple pages can be selected and processed at once.

## Supported Formats

| Input | Output |
|-------|--------|
| PDF (text embedded) | Markdown / Plain Text |
| PDF (image only) | Markdown / Plain Text |
| PNG / JPG | Markdown / Plain Text |

## Markdown Output

When Markdown is selected, the document structure is preserved:

- Document titles → `#` heading
- Section headings → `##` heading
- Tables → Markdown table format

Plain Text mode outputs unformatted text without any Markdown notation.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `↑` / `↓` | Switch thumbnail (pan preview vertically when zoomed) |
| `←` / `→` | Pan preview horizontally (when zoomed) |
| Scroll wheel (on thumbnail) | Switch thumbnail |
| Scroll wheel (on preview) | Pan preview vertically (when zoomed) |
| `BackSpace` / `Delete` | Delete selected page(s) (with confirmation) |
| `Cmd+A` / `Ctrl+A` | Select all pages |
| `Shift+Click` | Range select |
| `Cmd+Click` / `Ctrl+Click` | Toggle individual selection |
| Close button (×) / `Cmd+Q` | Quit the application |

## Author

Kazuyuki Kuwano

## License

AGPL-3.0 — see [LICENSE.md](./LICENSE.md) for details.
