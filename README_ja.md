# GLM-OCR-Desktop

**[English](./README.md)** | **日本語** | **[Deutsch](./README_de.md)**

![version](https://img.shields.io/github/v/release/quwano/GLM-OCR-Desktop?label=version&color=brightgreen)
![license](https://img.shields.io/badge/license-AGPL--3.0-green)
![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-blue)

## このプロジェクトについて

GLM-OCR-Desktop は、PDF・PNG・JPG ファイルを読み込み、OCR 結果を **Markdown** またはプレーンテキストで出力するデスクトップ GUI ツールです。

- **テキスト埋め込み PDF** は AI モデルを使わず直接抽出 — 高速・高精度
- **画像 PDF・PNG・JPG** はレイアウト解析 + GLM-OCR（VLM）で処理
- **UI 言語は自動判定**: 日本語 / English / Deutsch

### 処理フロー

```
入力ファイル
  ├─ PDF（テキスト埋め込み） →  レイアウト解析 + 直接テキスト抽出  →  Markdown / プレーンテキスト
  ├─ PDF（画像のみ）         →  レイアウト解析 + GLM-OCR（VLM）   →  Markdown / プレーンテキスト
  └─ PNG / JPG               →  レイアウト解析 + GLM-OCR（VLM）   →  Markdown / プレーンテキスト
```

## スクリーンショット

![GUIのスクリーンショット](docs/images/screenshot.png)

## 簡易インストール

`easy_installer/` フォルダ内に、OS と言語に対応したインストーラスクリプトがあります。
お使いの OS・言語に合わせたファイルをダブルクリックしてください：

| OS | 言語 | ファイル |
|----|------|---------|
| macOS | 日本語 | `easy_installer/mac_ja/glmocr_mac_installer_ja.command` |
| macOS | English | `easy_installer/mac_en/glmocr_mac_installer_en.command` |
| macOS | Deutsch | `easy_installer/mac_de/glmocr_mac_installer_de.command` |
| Windows | 日本語 | `easy_installer/win_ja/glmocr_win_installer_ja.bat` |
| Windows | English | `easy_installer/win_en/glmocr_win_installer_en.bat` |
| Windows | Deutsch | `easy_installer/win_de/glmocr_win_installer_de.bat` |

インストーラはステップごとに確認しながら進み、Python 3.11・仮想環境・パッケージ・AI モデルのダウンロードを自動でセットアップします。

手動インストールの場合は後述の [動作環境](#動作環境) を参照してください。

## 動作環境

### OS

- macOS 11 以降（Apple Silicon / Intel）
- Windows 10 以降

### Python

[python.org](https://www.python.org/downloads/release/python-31113/) 版の Python 3.11 が必要です。
macOS の Homebrew 版 Python には tkinter が含まれないため、python.org 版を使用してください。

## 必要な空き容量

以下の空き容量が必要です：

| 項目 | 容量目安 |
|------|---------|
| GLM-OCR モデル | 約 2.5 GB |
| PP-DocLayoutV3 モデル | 約 127 MB |
| Python 仮想環境（torch 等） | 約 1 GB |
| **合計** | **約 4 GB** |

## 起動方法

インストール後：

- **macOS**: `GLM-OCR-Desktop.command` をダブルクリック
  *（初回は右クリック →「開く」で Gatekeeper をバイパス）*
- **Windows**: `GLM-OCR-Desktop.bat` をダブルクリック
- **CLI**: `.venv_bundle/bin/python main.py`

## 使い方

1. **＋ファイル追加** ボタンをクリック、または PDF / PNG / JPG ファイルをドラッグ＆ドロップ
2. **▶ OCR 実行** をクリック
3. 出力形式（**Markdown** またはプレーンテキスト）を選択し **💾 保存** をクリック

複数ページをまとめて選択・処理できます。

## 対応形式

| 入力 | 出力 |
|------|------|
| PDF（テキスト埋め込み） | Markdown / プレーンテキスト |
| PDF（画像のみ） | Markdown / プレーンテキスト |
| PNG / JPG | Markdown / プレーンテキスト |

## Markdown 出力について

Markdown を選択した場合、文書構造が保持されます：

- 文書タイトル → `#` 見出し
- 節見出し → `##` 見出し
- 表 → Markdown テーブル形式

プレーンテキストモードでは、Markdown 記法を含まない生テキストを出力します。

## キーボードショートカット

| キー | 動作 |
|------|------|
| `↑` / `↓` | サムネイル切り替え（ズーム中はプレビューを上下パン） |
| `←` / `→` | プレビューを左右パン（ズーム中のみ） |
| スクロールホイール（サムネイル上） | サムネイル切り替え |
| スクロールホイール（プレビュー上） | プレビューを上下パン（ズーム中のみ） |
| `BackSpace` / `Delete` | 選択ページを削除（確認ダイアログあり） |
| `Cmd+A` / `Ctrl+A` | 全ページ選択 |
| `Shift+クリック` | 範囲選択 |
| `Cmd+クリック` / `Ctrl+クリック` | 個別トグル選択 |
| 閉じるボタン（×）/ `Cmd+Q` | アプリを終了 |

## 作者

Kazuyuki Kuwano

## ライセンス

AGPL-3.0 — 詳細は [LICENSE_ja.md](./LICENSE_ja.md) を参照してください。
