#Requires -Version 5.1
# GLM-OCR-Desktop Windows Setup-Installer (Deutsch)

$Host.UI.RawUI.WindowTitle = "GLM-OCR-Desktop Setup-Installer"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$VenvDir = Join-Path $ProjectDir ".venv_bundle"
$VenvPip = Join-Path $VenvDir "Scripts\pip.exe"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$HfCli = Join-Path $VenvDir "Scripts\hf.exe"

# ============================================================
# Hilfsfunktionen
# ============================================================

function Write-Header {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "-----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "-----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Ask-Continue {
    Write-Host ""
    do {
        $choice = (Read-Host "Mit dem nächsten Schritt fortfahren? (Y=Weiter / N=Abbrechen)").Trim().ToUpper()
    } while ($choice -ne 'Y' -and $choice -ne 'N')
    if ($choice -eq 'N') {
        Show-Abort
        exit 1
    }
    Write-Host ""
}

function Show-Abort {
    Clear-Host
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Yellow
    Write-Host "   Setup abgebrochen" -ForegroundColor Yellow
    Write-Host "===========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Das Setup wurde abgebrochen."
    Write-Host "Bereits abgeschlossene Schritte bleiben wirksam."
    Write-Host "Führen Sie dieses Skript erneut aus, um dort fortzufahren, wo Sie aufgehört haben."
    Write-Host "(Abgeschlossene Schritte werden automatisch übersprungen.)"
    Write-Host ""
    Read-Host "Drücken Sie Enter zum Beenden"
}

function Add-ToUserPath {
    param([string]$NewPath)
    if ($env:PATH -notlike "*$NewPath*") {
        $env:PATH = "$NewPath;$env:PATH"
    }
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$NewPath*") {
        try {
            [Environment]::SetEnvironmentVariable("PATH", "$NewPath;$userPath", "User")
            Write-Host "[Fertig] Dauerhaft zum PATH hinzugefügt: $NewPath"
        } catch {
            Write-Host "[Warnung] PATH konnte nicht dauerhaft gespeichert werden. Bitte manuell hinzufügen:" -ForegroundColor Yellow
            Write-Host "          Ordner: $NewPath"
        }
    }
}

# ============================================================
# Begrüßungsbildschirm
# ============================================================
Clear-Host
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "   GLM-OCR-Desktop Setup-Installer (Deutsch)" -ForegroundColor Green
Write-Host "   Richtet die GLM-OCR-Desktop-Laufzeitumgebung Schritt für Schritt ein." -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[Installationsschritte]"
Write-Host ""
Write-Host "  Schritt 1  Python 3.11 installieren (python.org)"
Write-Host "  Schritt 2  Virtuelle Umgebung erstellen (.venv_bundle)"
Write-Host "  Schritt 3  Python-Pakete installieren (torch, transformers, glmocr, ...)"
Write-Host "  Schritt 4  KI-Modelle herunterladen (GLM-OCR ~2,5 GB, PP-DocLayoutV3 ~127 MB)"
Write-Host "  Schritt 5  Starttest"
Write-Host ""
Write-Host "Nach jedem Schritt werden Sie gefragt, ob Sie fortfahren oder abbrechen möchten."
Write-Host "Drücken Sie jederzeit N, um abzubrechen."
Write-Host ""
Write-Host "Projektordner: $ProjectDir"
Write-Host ""
Read-Host "Drücken Sie Enter, um die Installation zu starten"

# ============================================================
# Schritt 1: Python 3.11
# ============================================================
Write-Header "Schritt 1 / 5  :  Python 3.11 installieren (python.org)"

$pyOk = $false
try {
    $pyVer = & py -3.11 --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Python 3.11 ist bereits installiert. Wird übersprungen."
        Write-Host $pyVer
        $pyOk = $true
    }
} catch {}

if (-not $pyOk) {
    Write-Host "Python 3.11 nicht gefunden. Wird heruntergeladen und installiert..."
    Write-Host ""
    $pyInstaller = "$env:TEMP\python-3.11.9-amd64.exe"

    Write-Host "Python 3.11.9 wird heruntergeladen..."
    $downloadOk = $true
    try {
        Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' `
            -OutFile $pyInstaller -ErrorAction Stop
    } catch {
        $downloadOk = $false
        Write-Host ""
        Write-Host "[Fehler] Download des Python-Installers fehlgeschlagen." -ForegroundColor Red
        Write-Host "Bitte manuell herunterladen:"
        Write-Host "  https://www.python.org/downloads/release/python-3119/"
        Write-Host "  Datei: python-3.11.9-amd64.exe"
        Write-Host ""
    }

    if ($downloadOk -and (Test-Path $pyInstaller)) {
        Write-Host "Download abgeschlossen. Installation wird gestartet (bitte warten)..."
        $result = Start-Process -FilePath $pyInstaller `
            -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0" -Wait -PassThru
        if ($result.ExitCode -ne 0) {
            Write-Host ""
            Write-Host "[Fehler] Python-Installation fehlgeschlagen (Exit-Code: $($result.ExitCode))." -ForegroundColor Red
            Write-Host "Bitte manuell installieren:"
            Write-Host "  https://www.python.org/downloads/release/python-3119/"
            Write-Host ""
        } else {
            $pyPath = "$env:LOCALAPPDATA\Programs\Python\Python311"
            $pyScripts = "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts"
            $env:PATH = "$pyPath;$pyScripts;$env:PATH"
            Write-Host ""
            Write-Host "[Fertig] Python 3.11 wurde erfolgreich installiert."
            try { & py -3.11 --version 2>&1 | Write-Host } catch {}
        }
    }
}

Ask-Continue

# ============================================================
# Schritt 2: Virtuelle Umgebung erstellen
# ============================================================
Write-Header "Schritt 2 / 5  :  Virtuelle Umgebung erstellen (.venv_bundle)"

if ((Test-Path $VenvDir) -and (Test-Path $VenvPython)) {
    Write-Host "[OK] Virtuelle Umgebung bereits vorhanden. Wird übersprungen."
    Write-Host "     $VenvDir"
    & $VenvPython --version
} else {
    $pyExe = $null
    try {
        & py -3.11 --version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $pyExe = "py"; $pyArgs = @("-3.11") }
    } catch {}

    if ($null -eq $pyExe) {
        Write-Host "[Fehler] py -3.11 nicht gefunden. Bitte Schritt 1 prüfen." -ForegroundColor Red
    } else {
        Write-Host "Virtuelle Umgebung wird erstellt mit py -3.11..."
        Set-Location $ProjectDir
        & $pyExe @($pyArgs + @("-m", "venv", $VenvDir))
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[Fertig] Virtuelle Umgebung erstellt: $VenvDir"
            & $VenvPython --version
        } else {
            Write-Host "[Fehler] Erstellung der virtuellen Umgebung fehlgeschlagen." -ForegroundColor Red
        }
    }
}

Ask-Continue

# ============================================================
# Schritt 3: Python-Pakete installieren
# ============================================================
Write-Header "Schritt 3 / 5  :  Python-Pakete installieren"

if (-not (Test-Path $VenvPip)) {
    Write-Host "[Fehler] Virtuelle Umgebung nicht gefunden. Bitte Schritt 2 prüfen." -ForegroundColor Red
} else {
    Write-Host "Zu installierende Pakete:"
    Write-Host "  torch, torchvision, transformers, accelerate,"
    Write-Host "  glmocr, PyMuPDF, Pillow, tkinterdnd2,"
    Write-Host "  opencv-python-headless, huggingface-hub"
    Write-Host ""
    Write-Host "Hinweis: torch ist groß (~2 GB). Dieser Schritt kann 10-20 Minuten dauern."
    Write-Host ""

    Write-Host "[1/4] pip wird aktualisiert..."
    & $VenvPip install --upgrade pip

    Write-Host ""
    Write-Host "[2/4] torch / torchvision wird installiert..."
    & $VenvPip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Fertig] torch / torchvision installiert."
    } else {
        Write-Host "[Fehler] Installation von torch / torchvision fehlgeschlagen." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "[3/4] transformers / accelerate wird installiert..."
    & $VenvPip install "transformers>=4.50" accelerate
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Fertig] transformers / accelerate installiert."
    } else {
        Write-Host "[Fehler] Installation von transformers / accelerate fehlgeschlagen." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "[4/4] glmocr, PyMuPDF, Pillow, tkinterdnd2, opencv-python-headless, huggingface-hub wird installiert..."
    & $VenvPip install glmocr PyMuPDF Pillow tkinterdnd2 opencv-python-headless huggingface-hub
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Fertig] Alle Pakete installiert."
    } else {
        Write-Host "[Fehler] Paketinstallation fehlgeschlagen." -ForegroundColor Red
    }
}

Ask-Continue

# ============================================================
# Schritt 4: KI-Modelle herunterladen
# ============================================================
Write-Header "Schritt 4 / 5  :  KI-Modelle herunterladen"

if (-not (Test-Path $HfCli)) {
    Write-Host "[Fehler] hf-Befehl nicht gefunden. Bitte Schritt 3 prüfen." -ForegroundColor Red
} else {
    Write-Host "Herunterzuladende Modelle:"
    Write-Host "  zai-org/GLM-OCR                          (~2,5 GB)"
    Write-Host "  PaddlePaddle/PP-DocLayoutV3_safetensors  (~127 MB)"
    Write-Host ""
    Write-Host "Cache-Speicherort: $env:USERPROFILE\.cache\huggingface\hub\"
    Write-Host "Hinweis: Bereits heruntergeladene Dateien werden automatisch übersprungen."
    Write-Host ""

    Write-Host "[1/2] GLM-OCR wird heruntergeladen (~2,5 GB - dies kann eine Weile dauern)..."
    & $HfCli download zai-org/GLM-OCR
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Fertig] GLM-OCR heruntergeladen."
    } else {
        Write-Host "[Fehler] Download von GLM-OCR fehlgeschlagen." -ForegroundColor Red
        Write-Host "Bitte Internetverbindung prüfen und erneut versuchen."
    }

    Write-Host ""
    Write-Host "[2/2] PP-DocLayoutV3 wird heruntergeladen (~127 MB)..."
    & $HfCli download PaddlePaddle/PP-DocLayoutV3_safetensors
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Fertig] PP-DocLayoutV3 heruntergeladen."
    } else {
        Write-Host "[Fehler] Download von PP-DocLayoutV3 fehlgeschlagen." -ForegroundColor Red
        Write-Host "Bitte Internetverbindung prüfen und erneut versuchen."
    }
}

Ask-Continue

# ============================================================
# Schritt 5: Starttest
# ============================================================
Write-Header "Schritt 5 / 5  :  Starttest"

if (-not (Test-Path $VenvPython)) {
    Write-Host "[Fehler] Virtuelle Umgebung nicht gefunden. Bitte Schritt 2 prüfen." -ForegroundColor Red
} elseif (-not (Test-Path (Join-Path $ProjectDir "main.py"))) {
    Write-Host "[Fehler] main.py nicht gefunden in: $ProjectDir" -ForegroundColor Red
    Write-Host "Bitte sicherstellen, dass Sie den Installer aus dem GLM-OCR-Desktop-Projektordner ausführen."
} else {
    Write-Host "Import-Test wird ausgeführt..."
    Write-Host ""
    & $VenvPython -c @"
import torch, transformers, fitz, PIL, tkinterdnd2, glmocr
print('Alle Pakete wurden erfolgreich geladen.')
print('  torch:', torch.__version__)
print('  transformers:', transformers.__version__)
"@
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[Fertig] Alle Pakete wurden überprüft."
    } else {
        Write-Host ""
        Write-Host "[Fehler] Import-Test fehlgeschlagen." -ForegroundColor Red
        Write-Host "Bitte die Fehlermeldungen oben prüfen und Schritt 3 wiederholen."
    }
}

Ask-Continue

# ============================================================
# Abschlussbildschirm
# ============================================================
Clear-Host
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "   Setup abgeschlossen!" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Alle Installationsschritte wurden abgeschlossen."
Write-Host ""
Write-Host "[GLM-OCR-Desktop starten]"
Write-Host "  Doppelklicken Sie auf GLM-OCR-Desktop.bat, um zu starten."
Write-Host ""
Write-Host "  (Manueller Start über die Eingabeaufforderung)"
Write-Host "  1. Eingabeaufforderung oder PowerShell öffnen"
Write-Host "  2. cd `"$ProjectDir`""
Write-Host "  3. .venv_bundle\Scripts\python.exe main.py"
Write-Host ""
Read-Host "Drücken Sie Enter zum Beenden"
