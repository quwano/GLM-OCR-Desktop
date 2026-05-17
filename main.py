import locale
import os
os.environ["HF_HUB_OFFLINE"] = "1"

import queue
import tempfile
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext, ttk

import fitz  # PyMuPDF (glmocr dependency)
from PIL import Image, ImageTk

try:
    from tkinterdnd2 import DND_FILES, TkinterDnD
    _HAS_DND = True
except ImportError:
    _HAS_DND = False

# ─── Internationalisation ────────────────────────────────────────────────────

def _detect_lang() -> str:
    for var in ("LANG", "LC_ALL", "LC_MESSAGES", "LANGUAGE"):
        v = os.environ.get(var, "").lower()
        if v.startswith("ja"):
            return "ja"
        if v.startswith("de"):
            return "de"
    try:
        lc = (locale.getlocale()[0] or "").lower()
        if "japanese" in lc or lc.startswith("ja"):
            return "ja"
        if "german" in lc or lc.startswith("de"):
            return "de"
    except Exception:
        pass
    return "en"

_LANG = _detect_lang()

_TR: dict[str, dict[str, str]] = {
    "window_title":       {"ja": "GLM-OCR-Desktop",       "de": "GLM-OCR-Desktop",                        "en": "GLM-OCR-Desktop"},
    "btn_add":            {"ja": "＋ファイル追加",         "de": "＋Datei hinzufügen",                      "en": "＋Add Files"},
    "btn_delete":         {"ja": "削除",                  "de": "Löschen",                                  "en": "Delete"},
    "btn_ocr":            {"ja": "▶ OCR実行",             "de": "▶ OCR starten",                            "en": "▶ Run OCR"},
    "btn_ocr_running":    {"ja": "処理中…",               "de": "Läuft…",                                   "en": "Running…"},
    "btn_save":           {"ja": "💾 保存",                "de": "💾 Speichern",                              "en": "💾 Save"},
    "label_format":       {"ja": "出力形式:",              "de": "Format:",                                  "en": "Format:"},
    "radio_plain":        {"ja": "プレーンテキスト",       "de": "Nur Text",                                 "en": "Plain Text"},
    "label_size":         {"ja": "サイズ:",                "de": "Größe:",                                   "en": "Size:"},
    "status_loading":     {"ja": "読み込み中: {name} …",  "de": "Lade: {name} …",                           "en": "Loading: {name} …"},
    "status_loaded":      {"ja": "{n} ページ読み込み済み", "de": "{n} Seite(n) geladen",                     "en": "{n} page(s) loaded"},
    "status_model":       {"ja": "モデル読み込み中… (初回のみ数分かかります。しばらくお待ちください)",
                           "de": "Modell wird geladen… (Erststart kann einige Minuten dauern.)",
                           "en": "Loading model… (First run may take several minutes. Please wait.)"},
    "status_progress":    {"ja": "OCR処理中… {cur}/{total} ページ", "de": "OCR läuft… {cur}/{total} Seiten",          "en": "OCR in progress… {cur}/{total} page(s)"},
    "status_done":        {"ja": "OCR完了: {done}/{total} ページ",  "de": "OCR abgeschlossen: {done}/{total} Seiten", "en": "OCR complete: {done}/{total} page(s)"},
    "status_saved":       {"ja": "保存しました: {path}",            "de": "Gespeichert: {path}",                      "en": "Saved: {path}"},
    "dlg_open_title":     {"ja": "ファイルを選択",         "de": "Datei auswählen",                          "en": "Select File"},
    "ftype_all":          {"ja": "対応ファイル",            "de": "Unterstützte Dateien",                     "en": "Supported Files"},
    "ftype_image":        {"ja": "画像ファイル",            "de": "Bilddateien",                              "en": "Image Files"},
    "ftype_pdf":          {"ja": "PDFファイル",             "de": "PDF-Dateien",                              "en": "PDF Files"},
    "dlg_load_error":     {"ja": "読み込みエラー",          "de": "Ladefehler",                               "en": "Load Error"},
    "dlg_no_files_title": {"ja": "確認",                   "de": "Hinweis",                                  "en": "Notice"},
    "dlg_no_files_msg":   {"ja": "ファイルを追加してください。", "de": "Bitte zuerst eine Datei hinzufügen.", "en": "Please add a file first."},
    "dlg_delete_title":   {"ja": "削除の確認",              "de": "Löschen bestätigen",                       "en": "Confirm Delete"},
    "dlg_delete_msg":     {"ja": "選択中の {n} ページを削除します。よろしいですか？",
                           "de": "{n} ausgewählte Seite(n) löschen. Fortfahren?",
                           "en": "Delete {n} selected page(s). Continue?"},
    "dlg_ocr_error":      {"ja": "OCRエラー",               "de": "OCR-Fehler",                               "en": "OCR Error"},
    "dlg_no_result_title":{"ja": "確認",                    "de": "Hinweis",                                  "en": "Notice"},
    "dlg_no_result_msg":  {"ja": "保存するOCR結果がありません。先にOCRを実行してください。",
                           "de": "Kein OCR-Ergebnis vorhanden. Bitte zuerst OCR ausführen.",
                           "en": "No OCR result to save. Please run OCR first."},
    "dlg_save_title":     {"ja": "保存先を選択",             "de": "Speicherort wählen",                       "en": "Save As"},
    "ftype_md":           {"ja": "Markdownファイル",         "de": "Markdown-Dateien",                         "en": "Markdown Files"},
    "ftype_txt":          {"ja": "テキストファイル",          "de": "Textdateien",                              "en": "Text Files"},
    "ocr_error_text":     {"ja": "[エラー: {msg}]",          "de": "[Fehler: {msg}]",                          "en": "[Error: {msg}]"},
    "ocr_error_prefix":   {"ja": "[エラー",                  "de": "[Fehler",                                  "en": "[Error"},
}


def T(key: str, **kw: object) -> str:
    s = _TR[key].get(_LANG) or _TR[key]["en"]
    return s.format_map(kw) if kw else s


THUMB_W = 120
THUMB_H = 160
ITEM_H = THUMB_H + 32
PANEL_W = THUMB_W + 16


# ─── Data model ───────────────────────────────────────────────────────────────

@dataclass
class PageItem:
    source_path: Path
    page_no: int
    full_image: Image.Image
    thumbnail: ImageTk.PhotoImage | None = field(default=None, repr=False)
    ocr_markdown: str = ""
    ocr_text: str = ""
    embedded_text: str = ""      # fitz直接抽出テキスト（空 = 画像OCR対象）
    embedded_markdown: str = ""  # fitz直接抽出マークダウン

    @property
    def label(self) -> str:
        name = self.source_path.name
        if self.source_path.suffix.lower() == ".pdf":
            return f"{name} p.{self.page_no + 1}"
        return name

    @property
    def has_result(self) -> bool:
        return bool(self.ocr_markdown or self.ocr_text)


def _pdf_page_to_markdown(page: fitz.Page) -> str:
    """フォントサイズ・太字・文字色の複合スコアで見出しレベルを判定してMarkdownを生成する。"""
    from collections import Counter

    data = page.get_text("dict")
    blocks = [b for b in data.get("blocks", []) if b.get("type") == 0]

    all_spans = [
        span
        for b in blocks
        for line in b.get("lines", [])
        for span in line.get("spans", [])
        if span.get("text", "").strip()
    ]
    if not all_spans:
        return page.get_text().strip()

    body_size  = Counter(round(s["size"], 1) for s in all_spans).most_common(1)[0][0]
    body_color = Counter(s.get("color", 0) for s in all_spans).most_common(1)[0][0]

    # 全ブロックのテキスト長の平均（短い独立ブロック検出用）
    block_lens = [
        len("".join(s.get("text", "") for ln in b.get("lines", [])
                    for s in ln.get("spans", [])).strip())
        for b in blocks
    ]
    avg_block_len = (sum(block_lens) / len(block_lens)) if block_lens else 0

    def heading_score(spans: list, text: str, n_lines: int) -> int:
        if not spans:
            return 0
        # 句点（。）で終わるブロックは文章の継続部分 → 見出し対象外
        stripped = text.strip()
        if stripped and stripped[-1] in "。.":
            return 0
        max_size = max(s.get("size", 0) for s in spans)
        is_bold  = any(
            (s.get("flags", 0) & 16)
            or any(w in s.get("font", "") for w in ("Bold", "Heavy", "Black", "bold"))
            for s in spans
        )
        diff_color = any(s.get("color", 0) != body_color for s in spans)
        ratio = max_size / body_size if body_size > 0 else 1.0
        score = 0
        if ratio >= 1.5:   score += 3
        elif ratio >= 1.3: score += 2
        elif ratio >= 1.1: score += 1
        if is_bold:        score += 1
        if diff_color:     score += 1
        # 短い独立1行ブロック（グレー見出し等）への補正
        if n_lines == 1 and avg_block_len > 0 and len(text) < avg_block_len * 0.6:
            score += 1
        return score

    md_lines: list[str] = []
    for block in blocks:
        block_texts: list[str] = []
        block_spans: list[dict] = []
        for line in block.get("lines", []):
            t = "".join(s.get("text", "") for s in line.get("spans", []))
            if t.strip():
                block_texts.append(t.strip())
                block_spans.extend(line.get("spans", []))
        if not block_texts:
            continue
        text  = "\n".join(block_texts)
        score = heading_score(block_spans, text, len(block_texts))
        if score >= 4:
            md_lines.append(f"# {text}")
        elif score >= 3:
            md_lines.append(f"## {text}")
        elif score >= 2:
            md_lines.append(f"### {text}")
        else:
            md_lines.append(text)
        md_lines.append("")
    return "\n".join(md_lines).strip()


def _to_markdown(text: str) -> str:
    """VLM出力のプレーンテキストに見出しマークアップを付加する簡易後処理。"""
    lines = text.splitlines()
    body_lines = [l for l in lines if l.strip()]
    if not body_lines:
        return text
    avg_len = sum(len(l) for l in body_lines) / len(body_lines)
    result: list[str] = []
    first_content = True
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            result.append("")
            continue
        is_short        = len(stripped) < avg_len * 0.5
        ends_with_punct = stripped[-1] in "。、.,!?！？…"
        if first_content and is_short and not ends_with_punct:
            result.append(f"# {stripped}")
        elif is_short and not ends_with_punct and i < len(lines) * 0.3:
            result.append(f"## {stripped}")
        else:
            result.append(stripped)
        first_content = False
    return "\n".join(result)


def load_file(path: Path) -> list[PageItem]:
    items: list[PageItem] = []
    suffix = path.suffix.lower()
    if suffix in (".jpg", ".jpeg", ".png"):
        img = Image.open(path).convert("RGB")
        items.append(PageItem(source_path=path, page_no=0, full_image=img))
    elif suffix == ".pdf":
        doc = fitz.open(str(path))
        for i in range(len(doc)):
            page = doc[i]
            pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
            img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
            # テキスト埋め込みを確認（あれば直接抽出してVLMをスキップ）
            plain = page.get_text().strip()
            md = _pdf_page_to_markdown(page) if plain else ""
            items.append(PageItem(
                source_path=path, page_no=i, full_image=img,
                embedded_text=plain, embedded_markdown=md,
            ))
        doc.close()
    return items


def make_thumb(img: Image.Image) -> ImageTk.PhotoImage:
    bg = Image.new("RGB", (THUMB_W, THUMB_H), (220, 220, 220))
    copy = img.copy()
    copy.thumbnail((THUMB_W, THUMB_H), Image.LANCZOS)
    bg.paste(copy, ((THUMB_W - copy.width) // 2, (THUMB_H - copy.height) // 2))
    return ImageTk.PhotoImage(bg)


# ─── OCR Worker ───────────────────────────────────────────────────────────────

class OCRWorker(threading.Thread):
    """In-process OCR using transformers + glmocr layout model."""

    _processor = None
    _model = None
    _layout_detector = None
    _model_lock = threading.Lock()

    MODEL_PATH = "zai-org/GLM-OCR"

    # native_label → markdown prefix
    _LABEL_PREFIX: dict[str, str] = {
        "doc_title":       "# ",
        "paragraph_title": "## ",
    }
    # task_type がこれの領域はスキップ（ヘッダー・フッター・ページ番号等）
    _TASK_SKIP = {"skip", "abandon"}

    def __init__(self, items: list[PageItem], result_q: queue.Queue) -> None:
        super().__init__(daemon=True)
        self.items = items
        self.q = result_q

    def run(self) -> None:
        # テキストPDFも layout+GLM-OCR を使うため、常にモデルをロード
        try:
            self._ensure_model()
        except Exception as e:
            self.q.put(("fatal", None, str(e)))
            self.q.put(("done", None, None))
            return
        try:
            for i, item in enumerate(self.items):
                self.q.put(("progress", i, len(self.items)))
                self._process_page(i, item)
        finally:
            self.q.put(("done", None, None))

    def _ensure_model(self) -> None:
        if OCRWorker._model is not None:
            return
        self.q.put(("model_loading", None, None))
        with OCRWorker._model_lock:
            if OCRWorker._model is not None:
                return
            from transformers import AutoProcessor, AutoModelForImageTextToText
            from glmocr.layout import PPDocLayoutDetector
            from glmocr.config import load_config as _load_cfg
            import glmocr as _glm_pkg

            import torch as _torch
            if _torch.backends.mps.is_available():
                _device = "mps"
            elif _torch.cuda.is_available():
                _device = "cuda"
            else:
                _device = "cpu"
            OCRWorker._processor = AutoProcessor.from_pretrained(self.MODEL_PATH)
            OCRWorker._model = AutoModelForImageTextToText.from_pretrained(
                self.MODEL_PATH,
                dtype=_torch.bfloat16,
                low_cpu_mem_usage=True,
                device_map={"": _device},
            )
            OCRWorker._model.eval()

            # layout モデル初期化（初回はPP-DocLayoutV3を自動ダウンロード）
            _cfg_path = Path(_glm_pkg.__file__).parent / "config.yaml"
            _cfg = _load_cfg(_cfg_path)
            OCRWorker._layout_detector = PPDocLayoutDetector(_cfg.pipeline.layout)
            OCRWorker._layout_detector.start()

    def _process_page(self, i: int, item: PageItem) -> None:
        try:
            if item.embedded_text and item.source_path.suffix.lower() == ".pdf":
                # テキストPDF: layout で構造検出 + fitz でテキスト抽出（誤字なし）
                md, plain = self._layout_fitz_ocr(item)
            else:
                # 画像PDF / PNG: layout + GLM-OCR
                md, txt = self._layout_ocr(item.full_image)
                plain = item.embedded_text if item.embedded_text else txt
            self.q.put(("result", i, md, plain))
        except Exception as e:
            self.q.put(("error", i, str(e)))

    def _layout_fitz_ocr(self, item: PageItem) -> tuple[str, str]:
        """テキストPDF用: layout で構造検出 → fitz でテキスト抽出（誤字なし）。
        表のみ GLM-OCR を使用（fitz はテーブル構造を保持しない）。"""
        import fitz as _fitz

        regions_per_page, _ = OCRWorker._layout_detector.process([item.full_image])
        regions = regions_per_page[0] if regions_per_page else []

        iw, ih = item.full_image.size
        doc  = _fitz.open(str(item.source_path))
        page = doc[item.page_no]
        pw, ph = page.rect.width, page.rect.height  # PDF座標系のサイズ

        md_parts: list[str] = []
        txt_parts: list[str] = []

        for region in regions:
            task_type = region.get("task_type", "text")
            if task_type in self._TASK_SKIP:
                continue
            label = region.get("label", "text")
            bbox  = region.get("bbox_2d")

            if bbox and len(bbox) == 4:
                # bbox_2d（0-1000スケール）→ PDF座標
                clip = _fitz.Rect(
                    bbox[0] / 1000 * pw, bbox[1] / 1000 * ph,
                    bbox[2] / 1000 * pw, bbox[3] / 1000 * ph,
                )
                if task_type == "table":
                    # 表は GLM-OCR（fitz はテーブル構造を持たない）
                    x1 = max(0, int(bbox[0] * iw / 1000))
                    y1 = max(0, int(bbox[1] * ih / 1000))
                    x2 = min(iw, int(bbox[2] * iw / 1000))
                    y2 = min(ih, int(bbox[3] * ih / 1000))
                    crop = item.full_image.crop((x1, y1, x2, y2))
                    text = self._ocr_image(crop, prompt="Table Recognition:")
                    if text.startswith("<table") and "</table>" in text:
                        text = self._html_table_to_gfm(text)
                elif task_type == "formula":
                    text = page.get_text("text", clip=clip).strip()
                else:
                    text = page.get_text("text", clip=clip).strip()
            else:
                text = item.embedded_text

            if not text:
                continue

            # 改行を除去して段落を復元（layoutが1段落を1領域として検出するため）
            # table は GLM-OCR が返す Markdown 構造（改行）を保持する
            if task_type != "table":
                text = "".join(text.splitlines())

            prefix = self._LABEL_PREFIX.get(label, "")
            if task_type == "formula":
                md_parts.append(f"$$\n{text}\n$$")
            else:
                md_parts.append(f"{prefix}{text}")
            txt_parts.append(text)

        doc.close()

        if not md_parts:
            return item.embedded_markdown or item.embedded_text, item.embedded_text
        return "\n\n".join(md_parts), "\n".join(txt_parts)

    def _layout_ocr(self, image: Image.Image) -> tuple[str, str]:
        """layout モデルで領域検出 → 領域ごとGLM-OCR → (markdown, plain_text)"""
        regions_per_page, _ = OCRWorker._layout_detector.process([image])
        regions = regions_per_page[0] if regions_per_page else []

        iw, ih = image.size
        md_parts: list[str] = []
        txt_parts: list[str] = []

        for region in regions:
            task_type = region.get("task_type", "text")
            if task_type in self._TASK_SKIP:
                continue
            label = region.get("label", "text")
            bbox = region.get("bbox_2d")
            if bbox and len(bbox) == 4:
                x1 = max(0, int(bbox[0] * iw / 1000))
                y1 = max(0, int(bbox[1] * ih / 1000))
                x2 = min(iw, int(bbox[2] * iw / 1000))
                y2 = min(ih, int(bbox[3] * ih / 1000))
                if x2 <= x1 or y2 <= y1:
                    continue
                crop = image.crop((x1, y1, x2, y2))
            else:
                crop = image

            _prompt = "Table Recognition:" if task_type == "table" else "Text Recognition:"
            ocr_text = self._ocr_image(crop, prompt=_prompt)
            if not ocr_text:
                continue

            if task_type == "table" and ocr_text.startswith("<table") and "</table>" in ocr_text:
                ocr_text = self._html_table_to_gfm(ocr_text)

            prefix = self._LABEL_PREFIX.get(label, "")
            if task_type == "formula":
                md_parts.append(f"$$\n{ocr_text}\n$$")
            else:
                md_parts.append(f"{prefix}{ocr_text}")
            txt_parts.append(ocr_text)

        md = "\n\n".join(md_parts)
        txt = "\n".join(txt_parts)
        # layout が何も検出しなかった場合はページ全体をフォールバックOCR
        if not md.strip():
            txt = self._ocr_image(image)
            md = _to_markdown(txt)
        return md, txt

    def _ocr_image(self, image: Image.Image, prompt: str = "Text Recognition:") -> str:
        """PIL Image を一時ファイル経由でGLM-OCRに渡してテキストを返す。"""
        import torch
        tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
        image.save(tmp.name, "PNG")
        tmp.close()
        try:
            messages = [{"role": "user", "content": [
                {"type": "image", "url": tmp.name},
                {"type": "text",  "text": prompt},
            ]}]
            inputs = OCRWorker._processor.apply_chat_template(
                messages, tokenize=True, add_generation_prompt=True,
                return_dict=True, return_tensors="pt",
            ).to(OCRWorker._model.device)
            inputs.pop("token_type_ids", None)
            with torch.no_grad():
                ids = OCRWorker._model.generate(**inputs, max_new_tokens=1024)
            result = OCRWorker._processor.decode(
                ids[0][inputs["input_ids"].shape[1]:],
                skip_special_tokens=True,
            ).strip()
            if torch.backends.mps.is_available():
                torch.mps.empty_cache()
            elif torch.cuda.is_available():
                torch.cuda.empty_cache()
            return result
        finally:
            Path(tmp.name).unlink(missing_ok=True)

    @staticmethod
    def _html_table_to_gfm(html: str) -> str:
        """<table>...</table> HTML を GFM パイプテーブルに変換する。"""
        from html.parser import HTMLParser

        class _TableParser(HTMLParser):
            def __init__(self):
                super().__init__()
                self.rows: list[list[str]] = []
                self._cur_row: list[str] = []
                self._cur_cell: list[str] = []
                self._in_cell = False
                self._has_header = False

            def handle_starttag(self, tag, attrs):
                if tag == "tr":
                    self._cur_row = []
                elif tag in ("td", "th"):
                    self._cur_cell = []
                    self._in_cell = True
                    if tag == "th":
                        self._has_header = True

            def handle_endtag(self, tag):
                if tag in ("td", "th"):
                    self._cur_row.append("".join(self._cur_cell).strip())
                    self._in_cell = False
                elif tag == "tr":
                    if self._cur_row:
                        self.rows.append(self._cur_row)

            def handle_data(self, data):
                if self._in_cell:
                    self._cur_cell.append(data)

        parser = _TableParser()
        parser.feed(html)

        if not parser.rows:
            return html

        lines: list[str] = []
        for i, row in enumerate(parser.rows):
            lines.append("| " + " | ".join(row) + " |")
            if i == 0 and parser._has_header:
                lines.append("| " + " | ".join("---" for _ in row) + " |")
        return "\n".join(lines)


# ─── ThumbnailPanel ───────────────────────────────────────────────────────────

class ThumbnailPanel(tk.Frame):
    def __init__(self, master: tk.Widget, on_select: Callable[[int], None], **kw):
        super().__init__(master, **kw)
        self.on_select = on_select
        self.items: list[PageItem] = []
        self._sel_set: set[int] = set()   # 選択中のインデックス集合
        self._anchor: int | None = None   # Shift範囲選択の起点
        self._focused: int | None = None  # プレビュー表示対象（最後にクリックしたもの）
        self._drag_from: int | None = None

        self.canvas = tk.Canvas(self, bg="#e0e0e0", width=PANEL_W, highlightthickness=0)
        vsb = ttk.Scrollbar(self, orient="vertical", command=self.canvas.yview)
        self.canvas.configure(yscrollcommand=vsb.set)
        vsb.pack(side="right", fill="y")
        self.canvas.pack(side="left", fill="both", expand=True)

        self.canvas.bind("<ButtonPress-1>", self._on_press)
        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)
        self.canvas.bind("<Enter>", lambda e: self.canvas.focus_set())
        for ev in ("<MouseWheel>", "<Button-4>", "<Button-5>"):
            self.canvas.bind(ev, self._on_wheel)

    def refresh(self) -> None:
        self._draw()

    def _draw(self) -> None:
        c = self.canvas
        c.delete("all")
        n = len(self.items)
        c.configure(scrollregion=(0, 0, PANEL_W, max(n * ITEM_H, 1)))
        cx = PANEL_W // 2
        for i, item in enumerate(self.items):
            y0 = i * ITEM_H
            focused  = i == self._focused
            selected = i in self._sel_set
            if focused:
                fill = "#2a70b9"   # 濃い青: フォーカス（プレビュー対象）
            elif selected:
                fill = "#4a90d9"   # 青: 選択済み
            else:
                fill = "#fafafa"
            c.create_rectangle(2, y0 + 2, PANEL_W - 2, y0 + ITEM_H - 2,
                                fill=fill, outline="#c0c0c0", tags=f"t{i}")
            if item.thumbnail is None:
                item.thumbnail = make_thumb(item.full_image)
            c.create_image(cx, y0 + 8 + THUMB_H // 2, image=item.thumbnail, tags=f"t{i}")
            if item.has_result:
                c.create_text(PANEL_W - 10, y0 + 8, text="✓",
                               font=("Helvetica", 10, "bold"), fill="#27ae60")
            lbl = item.label
            if len(lbl) > 22:
                lbl = lbl[:10] + "…" + lbl[-10:]
            c.create_text(cx, y0 + 8 + THUMB_H + 12, text=lbl,
                          font=("Helvetica", 9),
                          fill="white" if (focused or selected) else "#444",
                          width=PANEL_W - 8)

    def _cy(self, wy: int) -> int:
        return int(self.canvas.canvasy(wy))

    def _y_to_idx(self, cy: int) -> int:
        return max(0, min(len(self.items) - 1, cy // ITEM_H))

    def _on_press(self, e: tk.Event) -> None:
        cy = self._cy(e.y)
        idx = self._y_to_idx(cy)
        if idx >= len(self.items):
            return

        shift = bool(e.state & 0x1)   # Shift キー
        cmd   = bool(e.state & 0x8)   # Command キー (macOS Mod1)

        if shift and self._anchor is not None:
            # Shift+クリック: アンカーから今のインデックスまで範囲選択
            lo, hi = min(self._anchor, idx), max(self._anchor, idx)
            self._sel_set = set(range(lo, hi + 1))
            self._focused = idx
            self._drag_from = None
        elif cmd:
            # Cmd+クリック: 個別トグル
            if idx in self._sel_set:
                self._sel_set.discard(idx)
            else:
                self._sel_set.add(idx)
                self._anchor = idx
            self._focused = idx
            self._drag_from = None
        else:
            # 通常クリック: 単一選択・ドラッグ開始
            self._sel_set = {idx}
            self._anchor = idx
            self._focused = idx
            self._drag_from = idx

        self._draw()
        self.on_select(idx)

    def _on_drag(self, e: tk.Event) -> None:
        if self._drag_from is None or not self.items:
            return
        tgt = self._y_to_idx(self._cy(e.y))
        if tgt != self._drag_from:
            self.items[self._drag_from], self.items[tgt] = \
                self.items[tgt], self.items[self._drag_from]
            self._sel_set = {tgt}
            self._anchor = tgt
            self._focused = tgt
            self._drag_from = tgt
            self._draw()

    def _on_release(self, e: tk.Event) -> None:
        if self._drag_from is not None and self._focused is not None:
            self.on_select(self._focused)
        self._drag_from = None

    def _on_wheel(self, e: tk.Event) -> None:
        if e.num == 4 or e.delta > 0:
            self._navigate(-1)
        elif e.num == 5 or e.delta < 0:
            self._navigate(1)

    def _navigate(self, delta: int) -> None:
        if not self.items:
            return
        current = self._focused if self._focused is not None else -1
        new_idx = max(0, min(current + delta, len(self.items) - 1))
        if new_idx == self._focused:
            return
        self._sel_set = {new_idx}
        self._anchor  = new_idx
        self._focused = new_idx
        self._draw()
        self._scroll_to(new_idx)
        self.on_select(new_idx)

    def _scroll_to(self, idx: int) -> None:
        if not self.items:
            return
        total_h  = len(self.items) * ITEM_H
        canvas_h = self.canvas.winfo_height()
        if total_h <= canvas_h:
            return
        item_top = idx * ITEM_H
        item_bot = item_top + ITEM_H
        view_top = self.canvas.yview()[0] * total_h
        view_bot = view_top + canvas_h
        if item_top < view_top:
            self.canvas.yview_moveto(item_top / total_h)
        elif item_bot > view_bot:
            self.canvas.yview_moveto((item_bot - canvas_h) / total_h)

    @property
    def selected_idx(self) -> int | None:
        return self._focused

    def select_all(self) -> None:
        if not self.items:
            return
        self._sel_set = set(range(len(self.items)))
        if self._focused is None:
            self._focused = 0
            self._anchor = 0
            self.on_select(0)
        self._draw()

    def move_up(self) -> None:
        if self._focused is not None and self._focused > 0:
            i = self._focused
            self.items[i], self.items[i - 1] = self.items[i - 1], self.items[i]
            self._sel_set = {i - 1}
            self._anchor = i - 1
            self._focused = i - 1
            self._draw()
            self.on_select(self._focused)

    def move_down(self) -> None:
        if self._focused is not None and self._focused < len(self.items) - 1:
            i = self._focused
            self.items[i], self.items[i + 1] = self.items[i + 1], self.items[i]
            self._sel_set = {i + 1}
            self._anchor = i + 1
            self._focused = i + 1
            self._draw()
            self.on_select(self._focused)

    def remove_selected(self) -> None:
        if not self._sel_set or not self.items:
            return
        old_focused = self._focused if self._focused is not None else 0
        for idx in sorted(self._sel_set, reverse=True):
            if 0 <= idx < len(self.items):
                del self.items[idx]
        self._sel_set.clear()
        self._anchor = None
        self._focused = None
        if self.items:
            new_idx = min(old_focused, len(self.items) - 1)
            self._sel_set = {new_idx}
            self._anchor = new_idx
            self._focused = new_idx
        self._draw()
        if self._focused is not None:
            self.on_select(self._focused)


# ─── PreviewPanel ─────────────────────────────────────────────────────────────

class PreviewPanel(tk.Frame):
    def __init__(self, master: tk.Widget, **kw):
        super().__init__(master, **kw)
        self._img: Image.Image | None = None
        self._photo: ImageTk.PhotoImage | None = None
        self._zoom: float = 1.0   # 1.0 = ウィンドウにフィット
        self._pan_x: int = 0      # 0 = 中央（正 = 右へ寄せる）
        self._pan_y: int = 0      # 0 = 中央（正 = 下へ寄せる）
        self._drag_anchor: tuple[int, int] | None = None      # ドラッグ開始座標
        self._drag_pan: tuple[int, int] | None = None         # ドラッグ開始時のパン

        # ズームコントロールバー
        ctrl = tk.Frame(self, bg="#3a3a3a", height=26)
        ctrl.pack(fill="x")
        ctrl.pack_propagate(False)
        for text, cmd in [("－", self._zoom_out), ("＋", self._zoom_in), ("⊡", self._reset_zoom)]:
            tk.Button(ctrl, text=text, command=cmd,
                      bg="#585858", fg="black", relief="flat",
                      padx=8, pady=0, font=("Helvetica", 11),
                      cursor="hand2").pack(side="left", padx=1, pady=2)
        self._zoom_lbl = tk.Label(ctrl, text="fit", bg="#3a3a3a", fg="#cccccc",
                                   font=("Helvetica", 9), width=6)
        self._zoom_lbl.pack(side="left", padx=6)

        self._canvas = tk.Canvas(self, bg="#888", highlightthickness=0)
        self._canvas.pack(fill="both", expand=True)
        self._canvas.bind("<Configure>",      lambda _: self._render())
        self._canvas.bind("<ButtonPress-1>",  self._drag_start)
        self._canvas.bind("<B1-Motion>",      self._drag_move)
        self._canvas.bind("<ButtonRelease-1>",self._drag_end)
        for ev in ("<MouseWheel>", "<Button-4>", "<Button-5>"):
            self._canvas.bind(ev, self._on_wheel)

    @property
    def zoom(self) -> float:
        return self._zoom

    def show(self, img: Image.Image) -> None:
        self._img = img
        self._pan_x = 0
        self._pan_y = 0
        self._render()

    def clear(self) -> None:
        self._img = None
        self._photo = None
        self._canvas.delete("all")

    def pan_x(self, delta: int) -> None:
        if self._zoom > 1.0:
            self._pan_x += delta
            self._render()

    def pan_y(self, delta: int) -> None:
        if self._zoom > 1.0:
            self._pan_y += delta
            self._render()

    def _zoom_in(self) -> None:
        self._zoom = min(round(self._zoom * 1.4, 2), 8.0)
        self._render()

    def _zoom_out(self) -> None:
        self._zoom = max(round(self._zoom / 1.4, 2), 1.0)
        if self._zoom <= 1.0:
            self._zoom = 1.0
            self._pan_x = self._pan_y = 0
        self._render()

    def _reset_zoom(self) -> None:
        self._zoom = 1.0
        self._pan_x = self._pan_y = 0
        self._render()

    def _drag_start(self, e: tk.Event) -> None:
        if self._zoom > 1.0:
            self._drag_anchor = (e.x, e.y)
            self._drag_pan    = (self._pan_x, self._pan_y)
            self._canvas.configure(cursor="fleur")

    def _drag_move(self, e: tk.Event) -> None:
        if self._zoom > 1.0 and self._drag_anchor:
            dx = e.x - self._drag_anchor[0]
            dy = e.y - self._drag_anchor[1]
            self._pan_x = self._drag_pan[0] - dx  # type: ignore[index]
            self._pan_y = self._drag_pan[1] - dy  # type: ignore[index]
            self._render()

    def _drag_end(self, e: tk.Event) -> None:
        self._drag_anchor = None
        self._canvas.configure(cursor="")

    def _on_wheel(self, e: tk.Event) -> None:
        if self._zoom <= 1.0:
            return
        if e.num == 4 or e.delta > 0:
            self._pan_y -= 40
        elif e.num == 5 or e.delta < 0:
            self._pan_y += 40
        self._render()

    def _render(self) -> None:
        if self._img is None:
            return
        cw = self._canvas.winfo_width()
        ch = self._canvas.winfo_height()
        if cw < 10 or ch < 10:
            return
        iw, ih = self._img.size
        fit_scale = min(cw / iw, ch / ih)
        scale = fit_scale * self._zoom
        nw = max(1, int(iw * scale))
        nh = max(1, int(ih * scale))
        # パン範囲を中央起点の対称レンジに制限
        max_px = max(0, (nw - cw) // 2)
        max_py = max(0, (nh - ch) // 2)
        self._pan_x = max(-max_px, min(self._pan_x, max_px))
        self._pan_y = max(-max_py, min(self._pan_y, max_py))
        resized = self._img.resize((nw, nh), Image.LANCZOS)
        self._photo = ImageTk.PhotoImage(resized)
        self._canvas.delete("all")
        # 常に中央を起点とした anchor="center" で描画
        self._canvas.create_image(
            cw // 2 - self._pan_x, ch // 2 - self._pan_y,
            anchor="center", image=self._photo
        )
        self._zoom_lbl.configure(
            text="fit" if self._zoom <= 1.0 else f"{int(self._zoom * 100)}%"
        )


# ─── App ──────────────────────────────────────────────────────────────────────

if _HAS_DND:
    _BaseClass = TkinterDnD.Tk  # type: ignore[misc]
else:
    _BaseClass = tk.Tk


class App(_BaseClass):  # type: ignore[misc]
    def __init__(self) -> None:
        super().__init__()
        self.title(T("window_title"))
        self.geometry("1200x750")
        self.minsize(800, 600)
        self._q: queue.Queue = queue.Queue()
        self._ocr_running = False
        self._timer_start: float = 0.0
        self._timer_running: bool = False
        self._build_ui()
        self.protocol("WM_DELETE_WINDOW", self._on_close)
        self.bind("<Command-a>", lambda e: self.thumb.select_all())
        self.bind("<Command-A>", lambda e: self.thumb.select_all())
        self.bind("<BackSpace>", self._delete_with_confirm)
        self.bind("<Delete>",    self._delete_with_confirm)
        self.bind("<Up>",    self._on_arrow_up)
        self.bind("<Down>",  self._on_arrow_down)
        self.bind("<Left>",  self._on_arrow_left)
        self.bind("<Right>", self._on_arrow_right)
        if _HAS_DND:
            self.drop_target_register(DND_FILES)
            self.dnd_bind("<<Drop>>", self._on_file_drop)

    def _build_ui(self) -> None:
        self._build_toolbar()
        self._build_main()

    def _build_toolbar(self) -> None:
        bar = tk.Frame(self, bg="#2c3e50", height=44)
        bar.pack(fill="x")
        bar.pack_propagate(False)

        # OCR button on the right
        self._ocr_btn = tk.Button(
            bar, text=T("btn_ocr"), command=self._run_ocr,
            bg="#27ae60", fg="black", relief="flat", padx=10, pady=5,
            cursor="hand2", activebackground="#2ecc71", activeforeground="black",
            state="disabled", disabledforeground="#666666")
        self._ocr_btn.pack(side="right", padx=8, pady=5)

        # タイマー（OCRボタンの左）
        self._timer_var = tk.StringVar(value="")
        tk.Label(bar, textvariable=self._timer_var,
                 bg="#2c3e50", fg="#ecf0f1",
                 font=("Menlo", 12), width=8).pack(side="right", padx=(0, 4), pady=5)

        def left_btn(text: str, cmd: Callable) -> tk.Button:
            b = tk.Button(bar, text=text, command=cmd,
                          bg="#c0c5cc", fg="black", relief="flat",
                          padx=8, pady=5, cursor="hand2",
                          activebackground="#a8adb5", activeforeground="black")
            b.pack(side="left", padx=2, pady=5)
            return b

        left_btn(T("btn_add"), self._add_files)
        left_btn(T("btn_delete"), self._delete_with_confirm)
        left_btn("↑", self._move_up)
        left_btn("↓", self._move_down)

        # 進捗表示（ツールバー中央）
        self._status = tk.StringVar(value="")
        tk.Label(bar, textvariable=self._status,
                 bg="#2c3e50", fg="#ecf0f1",
                 font=("Menlo", 12), anchor="center").pack(
            side="left", expand=True, fill="x", padx=4)

    def _build_main(self) -> None:
        paned_h = ttk.PanedWindow(self, orient="horizontal")
        paned_h.pack(fill="both", expand=True)

        self.thumb = ThumbnailPanel(paned_h, on_select=self._on_page_select)
        paned_h.add(self.thumb, weight=0)

        paned_v = ttk.PanedWindow(paned_h, orient="vertical")
        paned_h.add(paned_v, weight=1)

        self.preview = PreviewPanel(paned_v)
        paned_v.add(self.preview, weight=2)

        result_frame = tk.Frame(paned_v, bg="#f5f5f5")
        paned_v.add(result_frame, weight=1)
        self._build_result_area(result_frame)

    def _build_result_area(self, parent: tk.Frame) -> None:
        ctrl = tk.Frame(parent, bg="#ebebeb")
        ctrl.pack(fill="x", padx=6, pady=4)

        tk.Label(ctrl, text=T("label_format"), bg="#ebebeb",
                 font=("Helvetica", 10)).pack(side="left")
        self._fmt = tk.StringVar(value="markdown")
        tk.Radiobutton(ctrl, text=T("radio_plain"), variable=self._fmt,
                       value="text", bg="#ebebeb",
                       command=self._refresh_result).pack(side="left", padx=4)
        tk.Radiobutton(ctrl, text="Markdown (CommonMark)", variable=self._fmt,
                       value="markdown", bg="#ebebeb",
                       command=self._refresh_result).pack(side="left", padx=4)

        tk.Button(ctrl, text=T("btn_save"), command=self._save,
                  bg="#2980b9", fg="black", relief="flat",
                  padx=8, pady=3, cursor="hand2").pack(side="right", padx=6)

        # フォントサイズ Spinbox（保存ボタンの左）
        tk.Label(ctrl, text="pt", bg="#ebebeb",
                 font=("Helvetica", 10)).pack(side="right")
        self._font_size = tk.IntVar(value=11)
        size_spin = ttk.Spinbox(ctrl, from_=6, to=72, increment=1,
                                textvariable=self._font_size,
                                width=4, command=self._update_font_size)
        size_spin.pack(side="right", padx=(0, 2))
        size_spin.bind("<Return>", lambda e: self._update_font_size())
        size_spin.bind("<FocusOut>", lambda e: self._update_font_size())
        tk.Label(ctrl, text=T("label_size"), bg="#ebebeb",
                 font=("Helvetica", 10)).pack(side="right", padx=(8, 0))

        self.result_text = scrolledtext.ScrolledText(
            parent, wrap="word", font=("Menlo", 11), bg="white")
        self.result_text.pack(fill="both", expand=True, padx=6, pady=(0, 6))

    # ── File handling ─────────────────────────────────────────────────────────

    def _add_files(self) -> None:
        paths = filedialog.askopenfilenames(
            title=T("dlg_open_title"),
            filetypes=[(T("ftype_all"),   "*.jpg *.jpeg *.png *.pdf"),
                       (T("ftype_image"), "*.jpg *.jpeg *.png"),
                       (T("ftype_pdf"),   "*.pdf")])
        for p in paths:
            self._load_path(p)

    def _on_file_drop(self, event: tk.Event) -> None:
        for p in self.tk.splitlist(event.data):
            self._load_path(p)

    def _update_ocr_btn(self) -> None:
        state = "normal" if (self.thumb.items and not self._ocr_running) else "disabled"
        self._ocr_btn.configure(state=state)

    def _load_path(self, path_str: str) -> None:
        path = Path(path_str.strip("{}"))
        if not path.exists():
            return
        if path.suffix.lower() not in (".jpg", ".jpeg", ".png", ".pdf"):
            return
        self._status.set(T("status_loading", name=path.name))
        self.update_idletasks()
        try:
            new_items = load_file(path)
            self.thumb.items.extend(new_items)
            self.thumb.refresh()
            n = len(self.thumb.items)
            self._status.set(T("status_loaded", n=n))
        except Exception as e:
            messagebox.showerror(T("dlg_load_error"), f"{path.name}\n{e}")
        finally:
            self._update_ocr_btn()

    # ── Page selection ────────────────────────────────────────────────────────

    def _on_page_select(self, idx: int) -> None:
        items = self.thumb.items
        if 0 <= idx < len(items):
            self.preview.show(items[idx].full_image)
            self._show_page_result(items[idx])

    def _show_page_result(self, item: PageItem) -> None:
        text = item.ocr_markdown if self._fmt.get() == "markdown" else item.ocr_text
        self.result_text.delete("1.0", "end")
        self.result_text.insert("1.0", text)

    def _update_font_size(self) -> None:
        try:
            size = max(6, min(72, int(self._font_size.get())))
        except (ValueError, tk.TclError):
            size = 11
        self._font_size.set(size)
        self.result_text.configure(font=("Menlo", size))

    def _refresh_result(self) -> None:
        idx = self.thumb.selected_idx
        if idx is not None:
            items = self.thumb.items
            if 0 <= idx < len(items):
                self._show_page_result(items[idx])

    # ── Toolbar actions ───────────────────────────────────────────────────────

    def _delete_with_confirm(self, event: tk.Event | None = None) -> None:
        sel = self.thumb._sel_set
        focused_idx = self.thumb._focused

        # 削除対象が何もない
        if not sel and focused_idx is None:
            return

        # キーバインド経由かつ明示的な選択がない場合のみ result_text 入力中をブロック
        if event is not None and not sel and self.focus_get() is self.result_text:
            return

        # _sel_set が空でも _focused があれば対象として扱う
        if not sel:
            self.thumb._sel_set = {focused_idx}

        n = len(self.thumb._sel_set)
        msg = T("dlg_delete_msg", n=n)
        if messagebox.askokcancel(T("dlg_delete_title"), msg):
            self._remove()
            self.after(0, self._restore_after_delete)

    def _restore_after_delete(self) -> None:
        focused = self.thumb._focused
        if focused is not None and not self.thumb._sel_set:
            self.thumb._sel_set = {focused}
            self.thumb._draw()
        self.focus_force()  # ルートウィンドウに強制フォーカス（result_text から離す）

    def _remove(self) -> None:
        self.thumb.remove_selected()
        if not self.thumb.items:
            self.preview.clear()
            self.result_text.delete("1.0", "end")
        self._update_ocr_btn()

    def _move_up(self) -> None:
        self.thumb.move_up()

    def _move_down(self) -> None:
        self.thumb.move_down()

    # ── OCR ───────────────────────────────────────────────────────────────────

    def _start_timer(self) -> None:
        self._timer_start = time.monotonic()
        self._timer_running = True
        self._update_timer()

    def _stop_timer(self) -> None:
        self._timer_running = False

    def _update_timer(self) -> None:
        if not self._timer_running:
            return
        elapsed = int(time.monotonic() - self._timer_start)
        h, remainder = divmod(elapsed, 3600)
        m, s = divmod(remainder, 60)
        self._timer_var.set(f"{h:02d}:{m:02d}:{s:02d}")
        self.after(1000, self._update_timer)

    def _run_ocr(self) -> None:
        if self._ocr_running:
            return
        items = self.thumb.items
        if not items:
            messagebox.showinfo(T("dlg_no_files_title"), T("dlg_no_files_msg"))
            return
        for item in items:
            item.ocr_markdown = ""
            item.ocr_text = ""
        self.result_text.delete("1.0", "end")
        self._ocr_running = True
        self._ocr_btn.configure(state="disabled", text=T("btn_ocr_running"))
        self._start_timer()
        OCRWorker(list(items), result_q=self._q).start()
        self.after(100, self._poll_queue)

    def _poll_queue(self) -> None:
        try:
            while True:
                msg = self._q.get_nowait()
                kind = msg[0]
                if kind == "model_loading":
                    self._status.set(T("status_model"))
                elif kind == "progress":
                    _, idx, total = msg
                    self._status.set(T("status_progress", cur=idx + 1, total=total))
                elif kind == "result":
                    _, idx, md, txt = msg
                    items = self.thumb.items
                    if 0 <= idx < len(items):
                        items[idx].ocr_markdown = md
                        items[idx].ocr_text = txt
                        self.thumb.refresh()
                        if self.thumb.selected_idx == idx:
                            self._show_page_result(items[idx])
                elif kind == "error":
                    _, idx, err = msg
                    items = self.thumb.items
                    if 0 <= idx < len(items):
                        items[idx].ocr_markdown = T("ocr_error_text", msg=err)
                        items[idx].ocr_text = T("ocr_error_text", msg=err)
                elif kind == "done":
                    self._ocr_done()
                    return
                elif kind == "fatal":
                    messagebox.showerror(T("dlg_ocr_error"), msg[2])
                    self._ocr_done()
                    return
        except queue.Empty:
            pass
        self.after(100, self._poll_queue)

    def _ocr_done(self) -> None:
        self._stop_timer()
        self._ocr_running = False
        self._ocr_btn.configure(state="normal", text=T("btn_ocr"))
        items = self.thumb.items
        done = sum(1 for it in items
                   if it.has_result and not it.ocr_markdown.startswith(T("ocr_error_prefix")))
        self._status.set(T("status_done", done=done, total=len(items)))
        # 未選択の場合は先頭ページを自動選択して結果を表示
        if self.thumb.selected_idx is None and items:
            self.thumb._sel = 0
            self.thumb.refresh()
            self._on_page_select(0)

    # ── Save ──────────────────────────────────────────────────────────────────

    def _save(self) -> None:
        items = self.thumb.items
        fmt = self._fmt.get()
        parts: list[str] = []
        for item in items:
            text = item.ocr_markdown if fmt == "markdown" else item.ocr_text
            if text:
                sep = (f"<!-- {item.label} -->"
                       if fmt == "markdown" else f"=== {item.label} ===")
                parts.append(f"{sep}\n\n{text}")
        if not parts:
            messagebox.showinfo(T("dlg_no_result_title"), T("dlg_no_result_msg"))
            return
        combined = "\n\n".join(parts)
        ext, ftypes = ((".md",  [(T("ftype_md"),  "*.md")])
                       if fmt == "markdown" else (".txt", [(T("ftype_txt"), "*.txt")]))
        path = filedialog.asksaveasfilename(
            defaultextension=ext, filetypes=ftypes, title=T("dlg_save_title"))
        if path:
            Path(path).write_text(combined, encoding="utf-8")
            self._status.set(T("status_saved", path=path))

    # ── Lifecycle ─────────────────────────────────────────────────────────────

    def _pointer_over_thumb(self) -> bool:
        """ポインタがサムネイルパネル上にあるか座標で判定する。"""
        px, py = self.winfo_pointerxy()
        tx = self.thumb.winfo_rootx()
        ty = self.thumb.winfo_rooty()
        return (tx <= px < tx + self.thumb.winfo_width() and
                ty <= py < ty + self.thumb.winfo_height())

    def _on_arrow_up(self, e: tk.Event) -> None:
        if isinstance(self.focus_get(), tk.Text):
            return
        if self._pointer_over_thumb() or self.preview.zoom <= 1.0:
            self.thumb._navigate(-1)
        else:
            self.preview.pan_y(-50)

    def _on_arrow_down(self, e: tk.Event) -> None:
        if isinstance(self.focus_get(), tk.Text):
            return
        if self._pointer_over_thumb() or self.preview.zoom <= 1.0:
            self.thumb._navigate(1)
        else:
            self.preview.pan_y(50)

    def _on_arrow_left(self, e: tk.Event) -> None:
        if isinstance(self.focus_get(), tk.Text):
            return
        self.preview.pan_x(-50)

    def _on_arrow_right(self, e: tk.Event) -> None:
        if isinstance(self.focus_get(), tk.Text):
            return
        self.preview.pan_x(50)

    def _on_close(self) -> None:
        self.destroy()


if __name__ == "__main__":
    App().mainloop()
