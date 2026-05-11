#!/bin/bash
# GLM-OCR-Desktop macOS セットアップインストーラ（日本語）
# 動作環境: macOS 11 以降（Apple Silicon / Intel）

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ARCH=$(uname -m)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_DIR="$PROJECT_DIR/.venv_bundle"
PY311_BIN="/Library/Frameworks/Python.framework/Versions/3.11/bin"

write_header() {
    clear
    echo ""
    echo -e "${CYAN}-----------------------------------------------------------${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}-----------------------------------------------------------${NC}"
    echo ""
}

ask_continue() {
    echo ""
    local _ac_choice
    while true; do
        read -rp "次のステップに進みますか？（Y=続行 / N=中止）: " _ac_choice
        _ac_choice=$(echo "$_ac_choice" | tr '[:lower:]' '[:upper:]')
        [[ "$_ac_choice" == "Y" || "$_ac_choice" == "N" ]] && break
    done
    if [[ "$_ac_choice" == "N" ]]; then
        show_abort
        exit 1
    fi
}

show_abort() {
    clear
    echo ""
    echo -e "${YELLOW}===========================================================${NC}"
    echo -e "${YELLOW}   セットアップを中止しました${NC}"
    echo -e "${YELLOW}===========================================================${NC}"
    echo ""
    echo "セットアップを中止しました。"
    echo "完了済みのステップはそのまま有効です。"
    echo "再度このスクリプトを実行すると、続きから再開できます。"
    echo "（完了済みのステップは自動的にスキップされます）"
    echo ""
    read -rp "Enterキーを押して終了"
}

add_to_path_persistent() {
    local new_path="$1"
    local shell_profile
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zshrc"
    else
        shell_profile="$HOME/.bash_profile"
    fi
    if ! grep -qF "$new_path" "$shell_profile" 2>/dev/null; then
        echo "" >> "$shell_profile"
        echo "export PATH=\"$new_path:\$PATH\"" >> "$shell_profile"
        echo "[完了] PATH に永続追加: $new_path"
        echo "       プロファイル: $shell_profile"
    else
        echo "[OK] すでに PATH に登録済みです: $new_path"
    fi
    export PATH="$new_path:$PATH"
}

# ============================================================
# ウェルカム画面
# ============================================================
clear
echo ""
echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}   GLM-OCR-Desktop セットアップインストーラ（日本語）${NC}"
echo -e "${GREEN}   GLM-OCR-Desktop の実行環境をステップごとにセットアップします。${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""
echo "[インストール手順]"
echo ""
echo "  Step 1  Python 3.11 のインストール（python.org 版）"
echo "  Step 2  仮想環境の作成（.venv_bundle）"
echo "  Step 3  Python パッケージのインストール（torch, transformers, glmocr, ...）"
echo "  Step 4  AI モデルのダウンロード（GLM-OCR 約2.5 GB、PP-DocLayoutV3 約127 MB）"
echo "  Step 5  起動テスト"
echo ""
echo "各ステップの後に続行または中止を確認します。"
echo "いつでも N を押して中止できます。"
echo ""
echo "プロジェクトフォルダ: $PROJECT_DIR"
echo "環境: $(uname -s) $(uname -r) (${ARCH})"
echo ""
read -rp "Enterキーを押してインストールを開始"

# ============================================================
# Step 1: Python 3.11
# ============================================================
write_header "Step 1 / 5  :  Python 3.11 のインストール（python.org 版）"

if python3.11 --version &>/dev/null; then
    echo "[OK] Python 3.11 はすでにインストール済みです。スキップします。"
    python3.11 --version
else
    echo "Python 3.11 が見つかりません。ダウンロードしてインストールします..."
    echo ""
    echo "注意: インストール中にシステムパスワードが必要です。"
    echo "      Homebrew 版 Python には tkinter が含まれません — python.org 版が必要です。"
    echo ""

    PY_PKG="/tmp/python-3.11.13-macos11.pkg"
    PY_URL="https://www.python.org/ftp/python/3.11.13/python-3.11.13-macos11.pkg"

    echo "Python 3.11.13 をダウンロード中..."
    if curl -L --progress-bar -o "$PY_PKG" "$PY_URL"; then
        echo "ダウンロード完了。インストールを開始します..."
        echo "（システムパスワードの入力を求められます）"
        echo ""
        if sudo installer -pkg "$PY_PKG" -target /; then
            echo ""
            echo "[完了] Python 3.11 のインストールが完了しました。"
            add_to_path_persistent "$PY311_BIN"
            python3.11 --version 2>/dev/null || true
        else
            echo ""
            echo -e "${RED}[エラー] Python のインストールに失敗しました。${NC}"
            echo "手動でインストールしてください:"
            echo "  https://www.python.org/downloads/release/python-31113/"
            echo "  ファイル: python-3.11.13-macos11.pkg"
            echo ""
        fi
    else
        echo ""
        echo -e "${RED}[エラー] Python インストーラのダウンロードに失敗しました。${NC}"
        echo "手動でダウンロードしてください:"
        echo "  https://www.python.org/downloads/release/python-31113/"
        echo "  ファイル: python-3.11.13-macos11.pkg"
        echo ""
    fi
fi

ask_continue

# ============================================================
# Step 2: 仮想環境の作成
# ============================================================
write_header "Step 2 / 5  :  仮想環境の作成（.venv_bundle）"

cd "$PROJECT_DIR"

if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/python" ]; then
    echo "[OK] 仮想環境はすでに存在します。スキップします。"
    echo "     $VENV_DIR"
    "$VENV_DIR/bin/python" --version
else
    PY_CMD=""
    if python3.11 --version &>/dev/null; then
        PY_CMD="python3.11"
    elif "$PY311_BIN/python3.11" --version &>/dev/null 2>&1; then
        PY_CMD="$PY311_BIN/python3.11"
    fi

    if [ -z "$PY_CMD" ]; then
        echo -e "${RED}[エラー] python3.11 が見つかりません。Step 1 を確認してください。${NC}"
    else
        echo "$PY_CMD で仮想環境を作成中..."
        if "$PY_CMD" -m venv "$VENV_DIR"; then
            echo "[完了] 仮想環境を作成しました: $VENV_DIR"
            "$VENV_DIR/bin/python" --version
        else
            echo -e "${RED}[エラー] 仮想環境の作成に失敗しました。${NC}"
        fi
    fi
fi

ask_continue

# ============================================================
# Step 3: Python パッケージのインストール
# ============================================================
write_header "Step 3 / 5  :  Python パッケージのインストール"

VENV_PIP="$VENV_DIR/bin/pip"

if [ ! -f "$VENV_PIP" ]; then
    echo -e "${RED}[エラー] 仮想環境が見つかりません。Step 2 を確認してください。${NC}"
else
    echo "インストールするパッケージ:"
    echo "  torch, torchvision, transformers, accelerate,"
    echo "  glmocr, PyMuPDF, Pillow, tkinterdnd2,"
    echo "  opencv-python-headless, huggingface-hub"
    echo ""
    echo "注意: torch は大きいため（約2 GB）、このステップに10〜20分かかる場合があります。"
    echo ""

    echo "[1/4] pip をアップグレード中..."
    "$VENV_PIP" install --upgrade pip

    echo ""
    echo "[2/4] torch / torchvision をインストール中..."
    if "$VENV_PIP" install torch torchvision \
        --index-url https://download.pytorch.org/whl/cpu; then
        echo "[完了] torch / torchvision をインストールしました。"
    else
        echo -e "${RED}[エラー] torch / torchvision のインストールに失敗しました。${NC}"
    fi

    echo ""
    echo "[3/4] transformers / accelerate をインストール中..."
    if "$VENV_PIP" install "transformers>=4.50" accelerate; then
        echo "[完了] transformers / accelerate をインストールしました。"
    else
        echo -e "${RED}[エラー] transformers / accelerate のインストールに失敗しました。${NC}"
    fi

    echo ""
    echo "[4/4] glmocr, PyMuPDF, Pillow, tkinterdnd2, opencv-python-headless, huggingface-hub をインストール中..."
    if "$VENV_PIP" install glmocr PyMuPDF Pillow tkinterdnd2 \
        opencv-python-headless huggingface-hub; then
        echo "[完了] すべてのパッケージをインストールしました。"
    else
        echo -e "${RED}[エラー] パッケージのインストールに失敗しました。${NC}"
    fi
fi

ask_continue

# ============================================================
# Step 4: AI モデルのダウンロード
# ============================================================
write_header "Step 4 / 5  :  AI モデルのダウンロード"

HF_CLI="$VENV_DIR/bin/huggingface-cli"

if [ ! -f "$HF_CLI" ]; then
    echo -e "${RED}[エラー] huggingface-cli が見つかりません。Step 3 を確認してください。${NC}"
else
    echo "ダウンロードするモデル:"
    echo "  zai-org/GLM-OCR                          （約2.5 GB）"
    echo "  PaddlePaddle/PP-DocLayoutV3_safetensors  （約127 MB）"
    echo ""
    echo "キャッシュ先: ~/.cache/huggingface/hub/"
    echo "注意: ダウンロード済みのファイルは自動的にスキップされます。"
    echo ""

    echo "[1/2] GLM-OCR をダウンロード中（約2.5 GB — 時間がかかります）..."
    if "$HF_CLI" download zai-org/GLM-OCR; then
        echo "[完了] GLM-OCR をダウンロードしました。"
    else
        echo -e "${RED}[エラー] GLM-OCR のダウンロードに失敗しました。${NC}"
        echo "インターネット接続を確認して再試行してください。"
    fi

    echo ""
    echo "[2/2] PP-DocLayoutV3 をダウンロード中（約127 MB）..."
    if "$HF_CLI" download PaddlePaddle/PP-DocLayoutV3_safetensors; then
        echo "[完了] PP-DocLayoutV3 をダウンロードしました。"
    else
        echo -e "${RED}[エラー] PP-DocLayoutV3 のダウンロードに失敗しました。${NC}"
        echo "インターネット接続を確認して再試行してください。"
    fi
fi

ask_continue

# ============================================================
# Step 5: 起動テスト
# ============================================================
write_header "Step 5 / 5  :  起動テスト"

VENV_PYTHON="$VENV_DIR/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    echo -e "${RED}[エラー] 仮想環境が見つかりません。Step 2 を確認してください。${NC}"
elif [ ! -f "$PROJECT_DIR/main.py" ]; then
    echo -e "${RED}[エラー] main.py が見つかりません: $PROJECT_DIR${NC}"
    echo "このインストーラを GLM-OCR-Desktop プロジェクトフォルダから実行していることを確認してください。"
else
    echo "インポートテストを実行中..."
    echo ""
    if "$VENV_PYTHON" -c "
import torch, transformers, fitz, PIL, tkinterdnd2, glmocr
print('すべてのパッケージが正常にロードされました。')
print('  torch:', torch.__version__)
print('  transformers:', transformers.__version__)
"; then
        echo ""
        echo "[完了] すべてのパッケージを確認しました。"
    else
        echo ""
        echo -e "${RED}[エラー] インポートテストに失敗しました。${NC}"
        echo "上記のエラーメッセージを確認し、Step 3 を再実行してください。"
    fi
fi

ask_continue

# ============================================================
# 完了画面
# ============================================================
clear
echo ""
echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}   セットアップが完了しました！${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""
echo "すべてのインストール手順が完了しました。"
echo ""
echo "[GLM-OCR-Desktop の起動方法]"
echo "  1. ターミナルを開く"
echo "  2. cd \"$PROJECT_DIR\""
echo "  3. .venv_bundle/bin/python main.py"
echo ""
read -rp "Enterキーを押して終了"
