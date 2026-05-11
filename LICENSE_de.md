# Lizenz- und Rechtsinformationen

**[English](./LICENSE.md)** | **[日本語](./LICENSE_ja.md)** | **Deutsch**

## Projektlizenz

GLM-OCR-Desktop wird unter der GNU Affero General Public License v3.0 (AGPL-3.0) veröffentlicht.

Copyright (C) 2026 Kazuyuki Kuwano

Dieses Programm ist freie Software: Sie können es unter den Bedingungen der
GNU Affero General Public License, wie von der Free Software Foundation
veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß Version 3
der Lizenz oder (nach Ihrer Wahl) jeder späteren Version.

Dieses Programm wird in der Hoffnung verteilt, dass es nützlich ist,
aber OHNE JEDE GEWÄHRLEISTUNG – sogar ohne die implizite Gewährleistung
der MARKTREIFE oder der EIGNUNG FÜR EINEN BESTIMMTEN ZWECK.
Weitere Einzelheiten finden Sie in der GNU Affero General Public License.

Sie sollten eine Kopie der GNU Affero General Public License zusammen mit
diesem Programm erhalten haben. Falls nicht, besuchen Sie <https://www.gnu.org/licenses/>.

## KI-Modelle

### zai-org/GLM-OCR

GLM-OCR wird für die optische Zeichenerkennung (OCR) aus Bildern verwendet.

- Repository: https://huggingface.co/zai-org/GLM-OCR
- Lizenz: MIT License

### PaddlePaddle/PP-DocLayoutV3

PP-DocLayoutV3 wird für die Dokumentlayoutanalyse (Bereichserkennung) verwendet.

- Repository: https://huggingface.co/PaddlePaddle/PP-DocLayoutV3_safetensors
- Lizenz: Apache License 2.0

## Python-Bibliotheken

| Bibliothek | Lizenz | Verwendungszweck |
|-----------|--------|-----------------|
| [PyTorch (torch)](https://pytorch.org/) | BSD-3-Clause | Modellinferenz |
| [torchvision](https://github.com/pytorch/vision) | BSD-3-Clause | PyTorch-Abhängigkeit |
| [Transformers](https://github.com/huggingface/transformers) | Apache 2.0 | Modell laden |
| [accelerate](https://github.com/huggingface/accelerate) | Apache 2.0 | Unterstützung beim Modell laden |
| [glmocr](https://pypi.org/project/glmocr/) | Apache 2.0 | Layout-Erkennungspipeline |
| [PyMuPDF (fitz)](https://pymupdf.readthedocs.io/) | AGPL-3.0 | PDF-Rendering und Textextraktion |
| [Pillow](https://python-pillow.org/) | HPND | Bildverarbeitung |
| [tkinterdnd2](https://pypi.org/project/tkinterdnd2/) | MIT | Drag-and-Drop-Dateiunterstützung |
| [opencv-python-headless](https://github.com/opencv/opencv-python) | Apache 2.0 | Abhängigkeit des Layout-Modells |
| [huggingface-hub](https://github.com/huggingface/huggingface_hub) | Apache 2.0 | Modell-Download |
