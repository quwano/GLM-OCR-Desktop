# ライセンスおよび権利情報

**[English](./LICENSE.md)** | **日本語** | **[Deutsch](./LICENSE_de.md)**

## プロジェクトライセンス

GLM-OCR-Desktop は GNU Affero General Public License v3.0（AGPL-3.0）の下で配布されています。

Copyright (C) 2026 Kazuyuki Kuwano

本プログラムはフリーソフトウェアです。フリーソフトウェア財団が公表した GNU Affero
一般公衆利用許諾書（バージョン3、またはお好みによりそれ以降のバージョン）の
条件の下で、本プログラムを再配布または改変することができます。

本プログラムは有用であることを願って配布されていますが、商品性または特定目的への
適合性の保証を含む、いかなる保証もありません。詳細については GNU Affero 一般公衆
利用許諾書をご覧ください。

本プログラムとともに GNU Affero 一般公衆利用許諾書のコピーを受け取るはずです。
もし受け取っていない場合は <https://www.gnu.org/licenses/> をご覧ください。

## AI モデル

### zai-org/GLM-OCR

GLM-OCR は画像からのテキスト認識（OCR）に使用しています。

- リポジトリ: https://huggingface.co/zai-org/GLM-OCR
- ライセンス: MIT License

### PaddlePaddle/PP-DocLayoutV3

PP-DocLayoutV3 はドキュメントのレイアウト解析（領域検出）に使用しています。

- リポジトリ: https://huggingface.co/PaddlePaddle/PP-DocLayoutV3_safetensors
- ライセンス: Apache License 2.0

## Python ライブラリ

| ライブラリ | ライセンス | 用途 |
|-----------|----------|------|
| [PyTorch (torch)](https://pytorch.org/) | BSD-3-Clause | モデル推論 |
| [torchvision](https://github.com/pytorch/vision) | BSD-3-Clause | PyTorch 依存 |
| [Transformers](https://github.com/huggingface/transformers) | Apache 2.0 | モデルのロード |
| [accelerate](https://github.com/huggingface/accelerate) | Apache 2.0 | モデルロード補助 |
| [glmocr](https://pypi.org/project/glmocr/) | Apache 2.0 | レイアウト検出パイプライン |
| [PyMuPDF (fitz)](https://pymupdf.readthedocs.io/) | AGPL-3.0 | PDF レンダリング・テキスト抽出 |
| [Pillow](https://python-pillow.org/) | HPND | 画像処理 |
| [tkinterdnd2](https://pypi.org/project/tkinterdnd2/) | MIT | ファイルのドラッグ＆ドロップ |
| [opencv-python-headless](https://github.com/opencv/opencv-python) | Apache 2.0 | レイアウトモデルの依存 |
| [huggingface-hub](https://github.com/huggingface/huggingface_hub) | Apache 2.0 | モデルのダウンロード |
