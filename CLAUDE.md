# GLM-OCR-Desktop

## 概要

GLM-OCR-Desktop（`zai-org/GLM-OCR`、約1.5Bパラメータ）を使ったOCR GUIツール。
テキスト埋め込みPDFは PyMuPDF で直接抽出、画像PDFおよびPNG/JPGはVLMでOCR処理する。

## 実行環境

| 項目 | 内容 |
|------|------|
| Python | `/Library/Frameworks/Python.framework/Versions/3.11` (python.org 3.11) |
| venv | `.venv_bundle/`（統合環境：tkinter・torch・transformers・glmocr） |
| 旧venv | `.venv/`（Python 3.13、torch有、tkinter無）、`.venv311/`（Python 3.11、tkinter有、torch無）→ 不要 |
| 起動コマンド | `.venv_bundle/bin/python main.py` |

## ファイル構成

```
GLM-OCR/
├── main.py          # GUIアプリ本体（唯一の編集対象）
├── ocr_server.py    # 旧サブプロセス方式の残骸（使用していない）
├── .venv_bundle/    # 統合venv
└── samples/         # テスト用サンプルファイル
```

## アーキテクチャ

### 処理フロー

```
ファイル追加（load_file）
  ├─ PNG/JPG    → PIL.Image として保持（embedded_text = ""）
  └─ PDF ページ → PIL.Image + fitz でテキスト抽出
       ├─ テキストあり → embedded_text に保存（plain text 用）
       └─ テキストなし → フィールドは空

OCR実行（OCRWorker スレッド）— 常に layout モデル + GLM-OCR をロード
  ├─ テキストPDF（embedded_text あり）→ _layout_fitz_ocr()
  │    layout で領域検出 + fitz でテキスト抽出（誤字なし）
  │    表領域のみ GLM-OCR
  └─ 画像PDF / PNG（embedded_text なし）→ _layout_ocr()
       layout で領域検出 + 領域ごと GLM-OCR
```

### 使用モデル

| モデル | 用途 | キャッシュサイズ |
|--------|------|---------------|
| `zai-org/GLM-OCR` | 画像からのテキスト認識（VLM） | 約2.5GB |
| `PaddlePaddle/PP-DocLayoutV3_safetensors` | レイアウト領域検出（25クラス） | 約127MB |

- 両モデルとも `OCRWorker` クラス変数にシングルトン保持（セッション中1回のみロード）
- `HF_HUB_OFFLINE=1` 設定済み（main.py 冒頭）→ キャッシュから読み込み
- opencv-python-headless が必要（layout モデルの依存）

### layout モデルのラベル体系

`PPDocLayoutDetector`（`glmocr.layout`）が検出する主なラベル：

| native_label | markdown変換 |
|-------------|-------------|
| `doc_title` | `# ` |
| `paragraph_title` | `## ` |
| `table` | GLM-OCR で処理 |
| `text`, `content`, `abstract` | 本文（プレフィックスなし） |
| `header`, `footer`, `number`, `seal` | スキップ（task_type: skip/abandon） |

### テキストPDFのMarkdown生成（_layout_fitz_ocr）

1. `PPDocLayoutDetector.process([full_image])` で領域とラベルを取得
2. `bbox_2d`（0-1000スケール）→ PDF座標に変換: `bbox / 1000 * page_width`
3. `fitz.page.get_text("text", clip=rect)` でテキストを正確に抽出
4. `"".join(text.splitlines())` でレイアウト起因の改行を除去（日本語はスペース不要）
5. layout ラベルに応じて `#` / `##` プレフィックスを付与
6. 表のみ GLM-OCR（fitz はテーブル構造を持たない）
7. 領域が検出されなかった場合は `_pdf_page_to_markdown()` にフォールバック

### Markdownフォールバック（_pdf_page_to_markdown）

layout で領域が検出されなかった場合のみ使用。フォントサイズ・太字フラグ・文字色の
複合スコアで見出しレベルを判定。`。` で終わるブロックは見出し対象外。

## GUI 構成（main.py）

### クラス一覧

| クラス | 役割 |
|--------|------|
| `PageItem` | 1ページ分のデータ（画像・OCR結果・埋め込みテキスト） |
| `OCRWorker` | バックグラウンドスレッドでOCR実行 |
| `ThumbnailPanel` | 左パネル：サムネイル一覧・ドラッグ並び替え・多重選択 |
| `PreviewPanel` | 右上パネル：選択ページの拡大表示・ズーム・パン |
| `App` | メインウィンドウ・全体制御 |

### レイアウト

```
┌─ ツールバー（黒帯）──────────────────────────────────────────┐
│ [＋追加][削除][↑][↓]   [進捗表示（中央）]   [タイマー][▶OCR] │
├─ 左パネル ──────┬─ 右上パネル（PreviewPanel）──────────────────┤
│ ThumbnailPanel  │  ズームバー [－][＋][⊡] fit                   │
│ （Canvas）      │  画像プレビュー                               │
│                 ├─ 右下パネル（ResultPanel）──────────────────  │
│                 │  出力形式: (●MD ○テキスト) サイズ:[▲11▼]pt   │
│                 │  [💾 保存]                                    │
│                 │  OCR結果テキスト（ScrolledText）              │
└─────────────────┴──────────────────────────────────────────────┘
```

### キーボードショートカット

| キー | 動作 |
|------|------|
| `↑` / `↓` | サムネイル切り替え（ズーム中はプレビューを上下パン） |
| `←` / `→` | プレビューを左右パン（ズーム中のみ） |
| スクロールホイール（サムネイル上） | サムネイル切り替え |
| スクロールホイール（プレビュー上） | プレビューを上下パン（ズーム中のみ） |
| `BackSpace` / `Delete` | 選択サムネイルを削除（確認ダイアログあり） |
| `Cmd+A` | 全ページ選択 |
| `Shift+クリック` | 範囲選択 |
| `Cmd+クリック` | 個別トグル選択 |

### サムネイル多重選択

- `_sel_set: set[int]` — 選択インデックス集合
- `_focused: int | None` — プレビュー対象（最後にクリックした項目）
- 視覚的に `_focused` は濃い青（#2a70b9）、`_sel_set` のみは薄い青（#4a90d9）

### プレビューズーム

- `_zoom: float = 1.0`（1.0 = フィット）
- パンは `_pan_x`, `_pan_y`（0 = 中央、対称レンジ ±max）
- ドラッグで移動可能（カーソルが `fleur` に変化）

## 依存パッケージ（.venv_bundle）

| パッケージ | 用途 |
|-----------|------|
| `torch` 2.11.0 | GLM-OCRモデルの推論 |
| `transformers` 5.8.0 | AutoProcessor / AutoModelForImageTextToText |
| `torchvision` | torch依存 |
| `glmocr` 0.1.5 | PDF直接抽出パイプライン（maasは使用せず） |
| `PyMuPDF (fitz)` | PDFレンダリング・テキスト抽出 |
| `Pillow` | 画像処理・サムネイル生成 |
| `tkinterdnd2` | OSからのファイルD&D |

## 出力フォーマット

- **プレーンテキスト**: `embedded_text`（生テキスト）またはVLM出力
- **Markdown**: `embedded_markdown`（fitz + 見出し判定）またはVLM出力に `_to_markdown()` 適用
- KERT の CommonMark 拡張記法（ルビ記法等）への自動変換は未実装（手動追記が前提）

## 既知事項・注意点

- `HF_HUB_OFFLINE=1` を設定済み（main.py冒頭）→ HuggingFaceへのネットワークアクセスなし
- macOS の `<BackSpace>` = Delete キー、`<Delete>` = fn+Delete キー（両方バインド済み）
- `messagebox` ダイアログ後のphantom click対策として `after(0, _restore_after_delete)` + `focus_force()` を使用
- スクロールホイールの方向判定は `e.delta > 0` / `e.delta < 0`（`e.num == 0` の制約なし）
