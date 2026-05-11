#!/bin/bash
# GLM-OCR-Desktop macOS Setup-Installer (Deutsch)
# Unterstützt: macOS 11 oder neuer (Apple Silicon / Intel)

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
        read -rp "Mit dem nächsten Schritt fortfahren? (Y=Weiter / N=Abbrechen): " _ac_choice
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
    echo -e "${YELLOW}   Setup abgebrochen${NC}"
    echo -e "${YELLOW}===========================================================${NC}"
    echo ""
    echo "Das Setup wurde abgebrochen."
    echo "Bereits abgeschlossene Schritte bleiben wirksam."
    echo "Führen Sie dieses Skript erneut aus, um dort fortzufahren, wo Sie aufgehört haben."
    echo "(Abgeschlossene Schritte werden automatisch übersprungen.)"
    echo ""
    read -rp "Drücken Sie Enter zum Beenden"
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
        echo "[Fertig] Dauerhaft zum PATH hinzugefügt: $new_path"
        echo "         Profil: $shell_profile"
    else
        echo "[OK] Bereits im PATH eingetragen: $new_path"
    fi
    export PATH="$new_path:$PATH"
}

# ============================================================
# Begrüßungsbildschirm
# ============================================================
clear
echo ""
echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}   GLM-OCR-Desktop Setup-Installer (Deutsch)${NC}"
echo -e "${GREEN}   Richtet die GLM-OCR-Desktop-Laufzeitumgebung Schritt für Schritt ein.${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""
echo "[Installationsschritte]"
echo ""
echo "  Schritt 1  Python 3.11 installieren (python.org)"
echo "  Schritt 2  Virtuelle Umgebung erstellen (.venv_bundle)"
echo "  Schritt 3  Python-Pakete installieren (torch, transformers, glmocr, ...)"
echo "  Schritt 4  KI-Modelle herunterladen (GLM-OCR ~2,5 GB, PP-DocLayoutV3 ~127 MB)"
echo "  Schritt 5  Starttest"
echo ""
echo "Nach jedem Schritt werden Sie gefragt, ob Sie fortfahren oder abbrechen möchten."
echo "Drücken Sie jederzeit N, um abzubrechen."
echo ""
echo "Projektordner: $PROJECT_DIR"
echo "Umgebung: $(uname -s) $(uname -r) (${ARCH})"
echo ""
read -rp "Drücken Sie Enter, um die Installation zu starten"

# ============================================================
# Schritt 1: Python 3.11
# ============================================================
write_header "Schritt 1 / 5  :  Python 3.11 installieren (python.org)"

if python3.11 --version &>/dev/null; then
    echo "[OK] Python 3.11 ist bereits installiert. Wird übersprungen."
    python3.11 --version
else
    echo "Python 3.11 nicht gefunden. Wird heruntergeladen und installiert..."
    echo ""
    echo "Hinweis: Während der Installation wird Ihr Systempasswort benötigt."
    echo "         Homebrew-Python enthält KEIN tkinter — die python.org-Version ist erforderlich."
    echo ""

    PY_PKG="/tmp/python-3.11.13-macos11.pkg"
    PY_URL="https://www.python.org/ftp/python/3.11.13/python-3.11.13-macos11.pkg"

    echo "Python 3.11.13 wird heruntergeladen..."
    if curl -L --progress-bar -o "$PY_PKG" "$PY_URL"; then
        echo "Download abgeschlossen. Installation wird gestartet..."
        echo "(Ihr Systempasswort wird abgefragt.)"
        echo ""
        if sudo installer -pkg "$PY_PKG" -target /; then
            echo ""
            echo "[Fertig] Python 3.11 wurde erfolgreich installiert."
            add_to_path_persistent "$PY311_BIN"
            python3.11 --version 2>/dev/null || true
        else
            echo ""
            echo -e "${RED}[Fehler] Python-Installation fehlgeschlagen.${NC}"
            echo "Bitte manuell installieren:"
            echo "  https://www.python.org/downloads/release/python-31113/"
            echo "  Datei: python-3.11.13-macos11.pkg"
            echo ""
        fi
    else
        echo ""
        echo -e "${RED}[Fehler] Download des Python-Installers fehlgeschlagen.${NC}"
        echo "Bitte manuell herunterladen:"
        echo "  https://www.python.org/downloads/release/python-31113/"
        echo "  Datei: python-3.11.13-macos11.pkg"
        echo ""
    fi
fi

ask_continue

# ============================================================
# Schritt 2: Virtuelle Umgebung erstellen
# ============================================================
write_header "Schritt 2 / 5  :  Virtuelle Umgebung erstellen (.venv_bundle)"

cd "$PROJECT_DIR"

if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/python" ]; then
    echo "[OK] Virtuelle Umgebung bereits vorhanden. Wird übersprungen."
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
        echo -e "${RED}[Fehler] python3.11 nicht gefunden. Bitte Schritt 1 prüfen.${NC}"
    else
        echo "Virtuelle Umgebung wird erstellt mit $PY_CMD..."
        if "$PY_CMD" -m venv "$VENV_DIR"; then
            echo "[Fertig] Virtuelle Umgebung erstellt: $VENV_DIR"
            "$VENV_DIR/bin/python" --version
        else
            echo -e "${RED}[Fehler] Erstellung der virtuellen Umgebung fehlgeschlagen.${NC}"
        fi
    fi
fi

ask_continue

# ============================================================
# Schritt 3: Python-Pakete installieren
# ============================================================
write_header "Schritt 3 / 5  :  Python-Pakete installieren"

VENV_PIP="$VENV_DIR/bin/pip"

if [ ! -f "$VENV_PIP" ]; then
    echo -e "${RED}[Fehler] Virtuelle Umgebung nicht gefunden. Bitte Schritt 2 prüfen.${NC}"
else
    echo "Zu installierende Pakete:"
    echo "  torch, torchvision, transformers, accelerate,"
    echo "  glmocr, PyMuPDF, Pillow, tkinterdnd2,"
    echo "  opencv-python-headless, huggingface-hub"
    echo ""
    echo "Hinweis: torch ist groß (~2 GB). Dieser Schritt kann 10-20 Minuten dauern."
    echo ""

    echo "[1/4] pip wird aktualisiert..."
    "$VENV_PIP" install --upgrade pip

    echo ""
    echo "[2/4] torch / torchvision wird installiert..."
    if "$VENV_PIP" install torch torchvision \
        --index-url https://download.pytorch.org/whl/cpu; then
        echo "[Fertig] torch / torchvision installiert."
    else
        echo -e "${RED}[Fehler] Installation von torch / torchvision fehlgeschlagen.${NC}"
    fi

    echo ""
    echo "[3/4] transformers / accelerate wird installiert..."
    if "$VENV_PIP" install "transformers>=4.50" accelerate; then
        echo "[Fertig] transformers / accelerate installiert."
    else
        echo -e "${RED}[Fehler] Installation von transformers / accelerate fehlgeschlagen.${NC}"
    fi

    echo ""
    echo "[4/4] glmocr, PyMuPDF, Pillow, tkinterdnd2, opencv-python-headless, huggingface-hub wird installiert..."
    if "$VENV_PIP" install glmocr PyMuPDF Pillow tkinterdnd2 \
        opencv-python-headless huggingface-hub; then
        echo "[Fertig] Alle Pakete installiert."
    else
        echo -e "${RED}[Fehler] Paketinstallation fehlgeschlagen.${NC}"
    fi
fi

ask_continue

# ============================================================
# Schritt 4: KI-Modelle herunterladen
# ============================================================
write_header "Schritt 4 / 5  :  KI-Modelle herunterladen"

HF_CLI="$VENV_DIR/bin/huggingface-cli"

if [ ! -f "$HF_CLI" ]; then
    echo -e "${RED}[Fehler] huggingface-cli nicht gefunden. Bitte Schritt 3 prüfen.${NC}"
else
    echo "Herunterzuladende Modelle:"
    echo "  zai-org/GLM-OCR                          (~2,5 GB)"
    echo "  PaddlePaddle/PP-DocLayoutV3_safetensors  (~127 MB)"
    echo ""
    echo "Cache-Speicherort: ~/.cache/huggingface/hub/"
    echo "Hinweis: Bereits heruntergeladene Dateien werden automatisch übersprungen."
    echo ""

    echo "[1/2] GLM-OCR wird heruntergeladen (~2,5 GB — dies kann eine Weile dauern)..."
    if "$HF_CLI" download zai-org/GLM-OCR; then
        echo "[Fertig] GLM-OCR heruntergeladen."
    else
        echo -e "${RED}[Fehler] Download von GLM-OCR fehlgeschlagen.${NC}"
        echo "Bitte Internetverbindung prüfen und erneut versuchen."
    fi

    echo ""
    echo "[2/2] PP-DocLayoutV3 wird heruntergeladen (~127 MB)..."
    if "$HF_CLI" download PaddlePaddle/PP-DocLayoutV3_safetensors; then
        echo "[Fertig] PP-DocLayoutV3 heruntergeladen."
    else
        echo -e "${RED}[Fehler] Download von PP-DocLayoutV3 fehlgeschlagen.${NC}"
        echo "Bitte Internetverbindung prüfen und erneut versuchen."
    fi
fi

ask_continue

# ============================================================
# Schritt 5: Starttest
# ============================================================
write_header "Schritt 5 / 5  :  Starttest"

VENV_PYTHON="$VENV_DIR/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    echo -e "${RED}[Fehler] Virtuelle Umgebung nicht gefunden. Bitte Schritt 2 prüfen.${NC}"
elif [ ! -f "$PROJECT_DIR/main.py" ]; then
    echo -e "${RED}[Fehler] main.py nicht gefunden in: $PROJECT_DIR${NC}"
    echo "Bitte sicherstellen, dass Sie den Installer aus dem GLM-OCR-Desktop-Projektordner ausführen."
else
    echo "Import-Test wird ausgeführt..."
    echo ""
    if "$VENV_PYTHON" -c "
import torch, transformers, fitz, PIL, tkinterdnd2, glmocr
print('Alle Pakete wurden erfolgreich geladen.')
print('  torch:', torch.__version__)
print('  transformers:', transformers.__version__)
"; then
        echo ""
        echo "[Fertig] Alle Pakete wurden überprüft."
    else
        echo ""
        echo -e "${RED}[Fehler] Import-Test fehlgeschlagen.${NC}"
        echo "Bitte die Fehlermeldungen oben prüfen und Schritt 3 wiederholen."
    fi
fi

ask_continue

# ============================================================
# Abschlussbildschirm
# ============================================================
clear
echo ""
echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}   Setup abgeschlossen!${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""
echo "Alle Installationsschritte wurden abgeschlossen."
echo ""
echo "[GLM-OCR-Desktop starten]"
echo "  1. Terminal öffnen"
echo "  2. cd \"$PROJECT_DIR\""
echo "  3. .venv_bundle/bin/python main.py"
echo ""
read -rp "Drücken Sie Enter zum Beenden"
