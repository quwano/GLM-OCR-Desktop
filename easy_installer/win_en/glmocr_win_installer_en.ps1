#Requires -Version 5.1
# GLM-OCR-Desktop Windows Setup Installer (English)

$Host.UI.RawUI.WindowTitle = "GLM-OCR-Desktop Setup Installer"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$VenvDir = Join-Path $ProjectDir ".venv_bundle"
$VenvPip = Join-Path $VenvDir "Scripts\pip.exe"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$HfCli = Join-Path $VenvDir "Scripts\hf.exe"

# ============================================================
# Utility functions
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
        $choice = (Read-Host "Proceed to the next step? (Y=Continue / N=Abort)").Trim().ToUpper()
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
    Write-Host "   Setup aborted" -ForegroundColor Yellow
    Write-Host "===========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Setup has been aborted."
    Write-Host "Any steps already completed remain effective."
    Write-Host "Run this script again to resume from where you left off."
    Write-Host "(Completed steps will be skipped automatically.)"
    Write-Host ""
    Read-Host "Press Enter to exit"
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
            Write-Host "[Done] Permanently added to PATH: $NewPath"
        } catch {
            Write-Host "[Warning] Could not save PATH permanently. Please add manually:" -ForegroundColor Yellow
            Write-Host "          Folder: $NewPath"
        }
    }
}

# ============================================================
# Welcome screen
# ============================================================
Clear-Host
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "   GLM-OCR-Desktop Setup Installer (English)" -ForegroundColor Green
Write-Host "   Sets up the GLM-OCR-Desktop runtime environment step by step." -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[Installation Steps]"
Write-Host ""
Write-Host "  Step 1  Install Python 3.11 (python.org)"
Write-Host "  Step 2  Create virtual environment (.venv_bundle)"
Write-Host "  Step 3  Install Python packages (torch, transformers, glmocr, ...)"
Write-Host "  Step 4  Download AI models (GLM-OCR ~2.5 GB, PP-DocLayoutV3 ~127 MB)"
Write-Host "  Step 5  Launch test"
Write-Host ""
Write-Host "You will be asked to continue or abort after each step."
Write-Host "Press N at any time to abort."
Write-Host ""
Write-Host "Project folder: $ProjectDir"
Write-Host ""
Read-Host "Press Enter to start the installation"

# ============================================================
# Step 1: Python 3.11
# ============================================================
Write-Header "Step 1 / 5  :  Install Python 3.11 (python.org)"

$pyOk = $false
try {
    $pyVer = & py -3.11 --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Python 3.11 is already installed. Skipping."
        Write-Host $pyVer
        $pyOk = $true
    }
} catch {}

if (-not $pyOk) {
    Write-Host "Python 3.11 not found. Downloading and installing..."
    Write-Host ""
    $pyInstaller = "$env:TEMP\python-3.11.9-amd64.exe"

    Write-Host "Downloading Python 3.11.9..."
    $downloadOk = $true
    try {
        Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' `
            -OutFile $pyInstaller -ErrorAction Stop
    } catch {
        $downloadOk = $false
        Write-Host ""
        Write-Host "[Error] Failed to download the Python installer." -ForegroundColor Red
        Write-Host "Please download manually:"
        Write-Host "  https://www.python.org/downloads/release/python-3119/"
        Write-Host "  File: python-3.11.9-amd64.exe"
        Write-Host ""
    }

    if ($downloadOk -and (Test-Path $pyInstaller)) {
        Write-Host "Download complete. Starting installation (please wait)..."
        $result = Start-Process -FilePath $pyInstaller `
            -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0" -Wait -PassThru
        if ($result.ExitCode -ne 0) {
            Write-Host ""
            Write-Host "[Error] Python installation failed (exit code: $($result.ExitCode))." -ForegroundColor Red
            Write-Host "Please install manually:"
            Write-Host "  https://www.python.org/downloads/release/python-3119/"
            Write-Host ""
        } else {
            $pyPath = "$env:LOCALAPPDATA\Programs\Python\Python311"
            $pyScripts = "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts"
            $env:PATH = "$pyPath;$pyScripts;$env:PATH"
            Write-Host ""
            Write-Host "[Done] Python 3.11 installation complete."
            try { & py -3.11 --version 2>&1 | Write-Host } catch {}
        }
    }
}

Ask-Continue

# ============================================================
# Step 2: Create virtual environment
# ============================================================
Write-Header "Step 2 / 5  :  Create virtual environment (.venv_bundle)"

if ((Test-Path $VenvDir) -and (Test-Path $VenvPython)) {
    Write-Host "[OK] Virtual environment already exists. Skipping."
    Write-Host "     $VenvDir"
    & $VenvPython --version
} else {
    $pyExe = $null
    try {
        & py -3.11 --version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $pyExe = "py"; $pyArgs = @("-3.11") }
    } catch {}

    if ($null -eq $pyExe) {
        Write-Host "[Error] py -3.11 not found. Please check Step 1." -ForegroundColor Red
    } else {
        Write-Host "Creating virtual environment with py -3.11..."
        Set-Location $ProjectDir
        & $pyExe @($pyArgs + @("-m", "venv", $VenvDir))
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[Done] Virtual environment created: $VenvDir"
            & $VenvPython --version
        } else {
            Write-Host "[Error] Failed to create virtual environment." -ForegroundColor Red
        }
    }
}

Ask-Continue

# ============================================================
# Step 3: Install Python packages
# ============================================================
Write-Header "Step 3 / 5  :  Install Python packages"

if (-not (Test-Path $VenvPip)) {
    Write-Host "[Error] Virtual environment not found. Please check Step 2." -ForegroundColor Red
} else {
    Write-Host "Packages to install:"
    Write-Host "  torch, torchvision, transformers, accelerate,"
    Write-Host "  glmocr, PyMuPDF, Pillow, tkinterdnd2,"
    Write-Host "  opencv-python-headless, huggingface-hub"
    Write-Host ""
    Write-Host "Note: torch is large (~2 GB). This step may take 10-20 minutes."
    Write-Host ""

    Write-Host "[1/4] Upgrading pip..."
    & $VenvPip install --upgrade pip

    Write-Host ""
    Write-Host "[2/4] Installing torch / torchvision..."
    & $VenvPip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Done] torch / torchvision installed."
    } else {
        Write-Host "[Error] torch / torchvision installation failed." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "[3/4] Installing transformers / accelerate..."
    & $VenvPip install "transformers>=4.50" accelerate
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Done] transformers / accelerate installed."
    } else {
        Write-Host "[Error] transformers / accelerate installation failed." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "[4/4] Installing glmocr, PyMuPDF, Pillow, tkinterdnd2, opencv-python-headless, huggingface-hub..."
    & $VenvPip install glmocr PyMuPDF Pillow tkinterdnd2 opencv-python-headless huggingface-hub
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Done] All packages installed."
    } else {
        Write-Host "[Error] Package installation failed." -ForegroundColor Red
    }
}

Ask-Continue

# ============================================================
# Step 4: Download AI models
# ============================================================
Write-Header "Step 4 / 5  :  Download AI models"

if (-not (Test-Path $HfCli)) {
    Write-Host "[Error] hf command not found. Please check Step 3." -ForegroundColor Red
} else {
    Write-Host "Models to download:"
    Write-Host "  zai-org/GLM-OCR                          (~2.5 GB)"
    Write-Host "  PaddlePaddle/PP-DocLayoutV3_safetensors  (~127 MB)"
    Write-Host ""
    Write-Host "Cache location: $env:USERPROFILE\.cache\huggingface\hub\"
    Write-Host "Note: Already downloaded files will be skipped automatically."
    Write-Host ""

    Write-Host "[1/2] Downloading GLM-OCR (~2.5 GB - this may take a while)..."
    & $HfCli download zai-org/GLM-OCR
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Done] GLM-OCR downloaded."
    } else {
        Write-Host "[Error] Failed to download GLM-OCR." -ForegroundColor Red
        Write-Host "Please check your internet connection and try again."
    }

    Write-Host ""
    Write-Host "[2/2] Downloading PP-DocLayoutV3 (~127 MB)..."
    & $HfCli download PaddlePaddle/PP-DocLayoutV3_safetensors
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Done] PP-DocLayoutV3 downloaded."
    } else {
        Write-Host "[Error] Failed to download PP-DocLayoutV3." -ForegroundColor Red
        Write-Host "Please check your internet connection and try again."
    }
}

Ask-Continue

# ============================================================
# Step 5: Launch test
# ============================================================
Write-Header "Step 5 / 5  :  Launch test"

if (-not (Test-Path $VenvPython)) {
    Write-Host "[Error] Virtual environment not found. Please check Step 2." -ForegroundColor Red
} elseif (-not (Test-Path (Join-Path $ProjectDir "main.py"))) {
    Write-Host "[Error] main.py not found in: $ProjectDir" -ForegroundColor Red
    Write-Host "Please make sure you are running this installer from the GLM-OCR-Desktop project folder."
} else {
    Write-Host "Running import test..."
    Write-Host ""
    & $VenvPython -c @"
import torch, transformers, fitz, PIL, tkinterdnd2, glmocr
print('All packages loaded successfully.')
print('  torch:', torch.__version__)
print('  transformers:', transformers.__version__)
"@
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[Done] All packages verified."
    } else {
        Write-Host ""
        Write-Host "[Error] Import test failed." -ForegroundColor Red
        Write-Host "Please check the error messages above and re-run Step 3."
    }
}

Ask-Continue

# ============================================================
# Completion screen
# ============================================================
Clear-Host
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "   Setup complete!" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "All installation steps have been completed."
Write-Host ""
Write-Host "[How to launch GLM-OCR-Desktop]"
Write-Host "  Double-click GLM-OCR-Desktop.bat to launch."
Write-Host ""
Write-Host "  (To launch manually from Command Prompt)"
Write-Host "  1. Open Command Prompt or PowerShell"
Write-Host "  2. cd `"$ProjectDir`""
Write-Host "  3. .venv_bundle\Scripts\python.exe main.py"
Write-Host ""
Read-Host "Press Enter to exit"
