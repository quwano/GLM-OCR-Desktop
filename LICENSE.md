# License and Rights Information

**English** | **[日本語](./LICENSE_ja.md)** | **[Deutsch](./LICENSE_de.md)**

## Project License

GLM-OCR-Desktop is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

Copyright (C) 2026 Kazuyuki Kuwano

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

## AI Models

### zai-org/GLM-OCR

GLM-OCR is used for optical character recognition from images.

- Repository: https://huggingface.co/zai-org/GLM-OCR
- License: MIT License

### PaddlePaddle/PP-DocLayoutV3

PP-DocLayoutV3 is used for document layout analysis (region detection).

- Repository: https://huggingface.co/PaddlePaddle/PP-DocLayoutV3_safetensors
- License: Apache License 2.0

## Python Libraries

| Library | License | Purpose |
|---------|---------|---------|
| [PyTorch (torch)](https://pytorch.org/) | BSD-3-Clause | Model inference |
| [torchvision](https://github.com/pytorch/vision) | BSD-3-Clause | PyTorch dependency |
| [Transformers](https://github.com/huggingface/transformers) | Apache 2.0 | Model loading |
| [accelerate](https://github.com/huggingface/accelerate) | Apache 2.0 | Model loading support |
| [glmocr](https://pypi.org/project/glmocr/) | Apache 2.0 | Layout detection pipeline |
| [PyMuPDF (fitz)](https://pymupdf.readthedocs.io/) | AGPL-3.0 | PDF rendering and text extraction |
| [Pillow](https://python-pillow.org/) | HPND | Image processing |
| [tkinterdnd2](https://pypi.org/project/tkinterdnd2/) | MIT | Drag-and-drop file support |
| [opencv-python-headless](https://github.com/opencv/opencv-python) | Apache 2.0 | Layout model dependency |
| [huggingface-hub](https://github.com/huggingface/huggingface_hub) | Apache 2.0 | Model download |
