#!/bin/bash
# GLM-OCR-Desktop macOS Setup Installer (English)
# Supported: macOS 11 or later (Apple Silicon / Intel)

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
        read -rp "Proceed to the next step? (Y=Continue / N=Abort): " _ac_choice
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
    echo -e "${YELLOW}   Setup aborted${NC}"
    echo -e "${YELLOW}===========================================================${NC}"
    echo ""
    echo "Setup has been aborted."
    echo "Any steps already completed remain effective."
    echo "Run this script again to resume from where you left off."
    echo "(Completed steps will be skipped automatically.)"
    echo ""
    read -rp "Press Enter to exit"
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
        echo "[Done] Permanently added to PATH: $new_path"
        echo "       Profile: $shell_profile"
    else
        echo "[OK] Already registered in PATH: $new_path"
    fi
    export PATH="$new_path:$PATH"
}

# ============================================================
# Welcome screen
# ============================================================
clear
echo ""
echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}   GLM-OCR-Desktop Setup Installer (English)${NC}"
echo -e "${GREEN}   Sets up the GLM-OCR-Desktop runtime environment step by step.${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""
echo "[Installation Steps]"
echo ""
echo "  Step 1  Install Python 3.11 (python.org)"
echo "  Step 2  Create virtual environment (.venv_bundle)"
echo "  Step 3  Install Python packages (torch, transformers, glmocr, ...)"
echo "  Step 4  Download AI models (GLM-OCR ~2.5 GB, PP-DocLayoutV3 ~127 MB)"
echo "  Step 5  Launch test"
echo ""
echo "You will be asked to continue or abort after each step."
echo "Press N at any time to abort."
echo ""
echo "Project folder: $PROJECT_DIR"
echo "Environment: $(uname -s) $(uname -r) (${ARCH})"
echo ""
read -rp "Press Enter to start the installation"

# ============================================================
# Step 1: Python 3.11
# ============================================================
write_header "Step 1 / 5  :  Install Python 3.11 (python.org)"

if python3.11 --version &>/dev/null; then
    echo "[OK] Python 3.11 is already installed. Skipping."
    python3.11 --version
else
    echo "Python 3.11 not found. Downloading and installing..."
    echo ""
    echo "Note: Your system password will be required."
    echo "      Homebrew Python does NOT include tkinter — python.org version is required."
    echo ""

    PY_PKG="/tmp/python-3.11.13-macos11.pkg"
    PY_URL="https://www.python.org/ftp/python/3.11.13/python-3.11.13-macos11.pkg"

    echo "Downloading Python 3.11.13..."
    if curl -L --progress-bar -o "$PY_PKG" "$PY_URL"; then
        echo "Download complete. Starting installation..."
        echo "(Your system password will be prompted.)"
        echo ""
        if sudo installer -pkg "$PY_PKG" -target /; then
            echo ""
            echo "[Done] Python 3.11 installation complete."
            add_to_path_persistent "$PY311_BIN"
            python3.11 --version 2>/dev/null || true
        else
            echo ""
            echo -e "${RED}[Error] Python installation failed.${NC}"
            echo "Please install manually:"
            echo "  https://www.python.org/downloads/release/python-31113/"
            echo "  File: python-3.11.13-macos11.pkg"
            echo ""
        fi
    else
        echo ""
        echo -e "${RED}[Error] Failed to download the Python installer.${NC}"
        echo "Please download manually:"
        echo "  https://www.python.org/downloads/release/python-31113/"
        echo "  File: python-3.11.13-macos11.pkg"
        echo ""
    fi
fi

ask_continue

# ============================================================
# Step 2: Create virtual environment
# ============================================================
write_header "Step 2 / 5  :  Create virtual environment (.venv_bundle)"

cd "$PROJECT_DIR"

if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/python" ]; then
    echo "[OK] Virtual environment already exists. Skipping."
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
        echo -e "${RED}[Error] python3.11 not found. Please check Step 1.${NC}"
    else
        echo "Creating virtual environment with $PY_CMD..."
        if "$PY_CMD" -m venv "$VENV_DIR"; then
            echo "[Done] Virtual environment created: $VENV_DIR"
            "$VENV_DIR/bin/python" --version
        else
            echo -e "${RED}[Error] Failed to create virtual environment.${NC}"
        fi
    fi
fi

ask_continue

# ============================================================
# Step 3: Install Python packages
# ============================================================
write_header "Step 3 / 5  :  Install Python packages"

VENV_PIP="$VENV_DIR/bin/pip"

if [ ! -f "$VENV_PIP" ]; then
    echo -e "${RED}[Error] Virtual environment not found. Please check Step 2.${NC}"
else
    echo "Packages to install:"
    echo "  torch, torchvision, transformers, accelerate,"
    echo "  glmocr, PyMuPDF, Pillow, tkinterdnd2,"
    echo "  opencv-python-headless, huggingface-hub"
    echo ""
    echo "Note: torch is large (~2 GB). This step may take 10-20 minutes."
    echo ""

    echo "[1/4] Upgrading pip..."
    "$VENV_PIP" install --upgrade pip

    echo ""
    echo "[2/4] Installing torch / torchvision..."
    if "$VENV_PIP" install torch torchvision \
        --index-url https://download.pytorch.org/whl/cpu; then
        echo "[Done] torch / torchvision installed."
    else
        echo -e "${RED}[Error] torch / torchvision installation failed.${NC}"
    fi

    echo ""
    echo "[3/4] Installing transformers / accelerate..."
    if "$VENV_PIP" install "transformers>=4.50" accelerate; then
        echo "[Done] transformers / accelerate installed."
    else
        echo -e "${RED}[Error] transformers / accelerate installation failed.${NC}"
    fi

    echo ""
    echo "[4/4] Installing glmocr, PyMuPDF, Pillow, tkinterdnd2, opencv-python-headless, huggingface-hub..."
    if "$VENV_PIP" install glmocr PyMuPDF Pillow tkinterdnd2 \
        opencv-python-headless huggingface-hub; then
        echo "[Done] All packages installed."
    else
        echo -e "${RED}[Error] Package installation failed.${NC}"
    fi
fi

ask_continue

# ============================================================
# Step 4: Download AI models
# ============================================================
write_header "Step 4 / 5  :  Download AI models"

HF_CLI="$VENV_DIR/bin/huggingface-cli"

if [ ! -f "$HF_CLI" ]; then
    echo -e "${RED}[Error] huggingface-cli not found. Please check Step 3.${NC}"
else
    echo "Models to download:"
    echo "  zai-org/GLM-OCR                          (~2.5 GB)"
    echo "  PaddlePaddle/PP-DocLayoutV3_safetensors  (~127 MB)"
    echo ""
    echo "Cache location: ~/.cache/huggingface/hub/"
    echo "Note: Already downloaded files will be skipped automatically."
    echo ""

    echo "[1/2] Downloading GLM-OCR (~2.5 GB — this may take a while)..."
    if "$HF_CLI" download zai-org/GLM-OCR; then
        echo "[Done] GLM-OCR downloaded."
    else
        echo -e "${RED}[Error] Failed to download GLM-OCR.${NC}"
        echo "Please check your internet connection and try again."
    fi

    echo ""
    echo "[2/2] Downloading PP-DocLayoutV3 (~127 MB)..."
    if "$HF_CLI" download PaddlePaddle/PP-DocLayoutV3_safetensors; then
        echo "[Done] PP-DocLayoutV3 downloaded."
    else
        echo -e "${RED}[Error] Failed to download PP-DocLayoutV3.${NC}"
        echo "Please check your internet connection and try again."
    fi
fi

ask_continue

# ============================================================
# Step 5: Launch test
# ============================================================
write_header "Step 5 / 5  :  Launch test"

VENV_PYTHON="$VENV_DIR/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    echo -e "${RED}[Error] Virtual environment not found. Please check Step 2.${NC}"
elif [ ! -f "$PROJECT_DIR/main.py" ]; then
    echo -e "${RED}[Error] main.py not found in: $PROJECT_DIR${NC}"
    echo "Please make sure you are running this installer from the GLM-OCR-Desktop project folder."
else
    echo "Running import test..."
    echo ""
    if "$VENV_PYTHON" -c "
import torch, transformers, fitz, PIL, tkinterdnd2, glmocr
print('All packages loaded successfully.')
print('  torch:', torch.__version__)
print('  transformers:', transformers.__version__)
"; then
        echo ""
        echo "[Done] All packages verified."
    else
        echo ""
        echo -e "${RED}[Error] Import test failed.${NC}"
        echo "Please check the error messages above and re-run Step 3."
    fi
fi

ask_continue

# ============================================================
# Completion screen
# ============================================================
clear
echo ""
echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}   Setup complete!${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""
echo "All installation steps have been completed."
echo ""
echo "[How to launch GLM-OCR-Desktop]"
echo "  1. Open Terminal"
echo "  2. cd \"$PROJECT_DIR\""
echo "  3. .venv_bundle/bin/python main.py"
echo ""
read -rp "Press Enter to exit"
