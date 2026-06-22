#Requires -Version 5.1
# GLM-OCR-Desktop Windows セットアップインストーラ（日本語）

$Host.UI.RawUI.WindowTitle = "GLM-OCR-Desktop セットアップインストーラ"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$VenvDir = Join-Path $ProjectDir ".venv_bundle"
$VenvPip = Join-Path $VenvDir "Scripts\pip.exe"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$HfCli = Join-Path $VenvDir "Scripts\hf.exe"

# ============================================================
# ユーティリティ関数
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
        $choice = (Read-Host "次のステップに進みますか？（Y=続行 / N=中止）").Trim().ToUpper()
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
    Write-Host "   セットアップを中止しました" -ForegroundColor Yellow
    Write-Host "===========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "セットアップを中止しました。"
    Write-Host "完了済みのステップはそのまま有効です。"
    Write-Host "再度このスクリプトを実行すると、続きから再開できます。"
    Write-Host "（完了済みのステップは自動的にスキップされます）"
    Write-Host ""
    Read-Host "Enterキーを押して終了"
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
            Write-Host "[完了] PATH に永続追加: $NewPath"
        } catch {
            Write-Host "[警告] PATH を永続保存できませんでした。手動で追加してください:" -ForegroundColor Yellow
            Write-Host "       フォルダ: $NewPath"
        }
    }
}

# ============================================================
# ウェルカム画面
# ============================================================
Clear-Host
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "   GLM-OCR-Desktop セットアップインストーラ（日本語）" -ForegroundColor Green
Write-Host "   GLM-OCR-Desktop の実行環境をステップごとにセットアップします。" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[インストール手順]"
Write-Host ""
Write-Host "  Step 1  Python 3.11 のインストール（python.org 版）"
Write-Host "  Step 2  仮想環境の作成（.venv_bundle）"
Write-Host "  Step 3  Python パッケージのインストール（torch, transformers, glmocr, ...）"
Write-Host "  Step 4  AI モデルのダウンロード（GLM-OCR 約2.5 GB、PP-DocLayoutV3 約127 MB）"
Write-Host "  Step 5  起動テスト"
Write-Host ""
Write-Host "各ステップの後に続行または中止を確認します。"
Write-Host "いつでも N を押して中止できます。"
Write-Host ""
Write-Host "プロジェクトフォルダ: $ProjectDir"
Write-Host ""
Read-Host "Enterキーを押してインストールを開始"

# ============================================================
# Step 1: Python 3.11
# ============================================================
Write-Header "Step 1 / 5  :  Python 3.11 のインストール（python.org 版）"

$pyOk = $false
try {
    $pyVer = & py -3.11 --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Python 3.11 はすでにインストール済みです。スキップします。"
        Write-Host $pyVer
        $pyOk = $true
    }
} catch {}

if (-not $pyOk) {
    Write-Host "Python 3.11 が見つかりません。ダウンロードしてインストールします..."
    Write-Host ""
    $pyInstaller = "$env:TEMP\python-3.11.9-amd64.exe"

    Write-Host "Python 3.11.9 をダウンロード中..."
    $downloadOk = $true
    try {
        Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' `
            -OutFile $pyInstaller -ErrorAction Stop
    } catch {
        $downloadOk = $false
        Write-Host ""
        Write-Host "[エラー] Python インストーラのダウンロードに失敗しました。" -ForegroundColor Red
        Write-Host "手動でダウンロードしてください:"
        Write-Host "  https://www.python.org/downloads/release/python-3119/"
        Write-Host "  ファイル: python-3.11.9-amd64.exe"
        Write-Host ""
    }

    if ($downloadOk -and (Test-Path $pyInstaller)) {
        Write-Host "ダウンロード完了。インストールを開始します（しばらくお待ちください）..."
        $result = Start-Process -FilePath $pyInstaller `
            -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0" -Wait -PassThru
        if ($result.ExitCode -ne 0) {
            Write-Host ""
            Write-Host "[エラー] Python のインストールに失敗しました（終了コード: $($result.ExitCode)）。" -ForegroundColor Red
            Write-Host "手動でインストールしてください:"
            Write-Host "  https://www.python.org/downloads/release/python-3119/"
            Write-Host ""
        } else {
            $pyPath = "$env:LOCALAPPDATA\Programs\Python\Python311"
            $pyScripts = "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts"
            $env:PATH = "$pyPath;$pyScripts;$env:PATH"
            Write-Host ""
            Write-Host "[完了] Python 3.11 のインストールが完了しました。"
            try { & py -3.11 --version 2>&1 | Write-Host } catch {}
        }
    }
}

Ask-Continue

# ============================================================
# Step 2: 仮想環境の作成
# ============================================================
Write-Header "Step 2 / 5  :  仮想環境の作成（.venv_bundle）"

if ((Test-Path $VenvDir) -and (Test-Path $VenvPython)) {
    Write-Host "[OK] 仮想環境はすでに存在します。スキップします。"
    Write-Host "     $VenvDir"
    & $VenvPython --version
} else {
    $pyExe = $null
    try {
        & py -3.11 --version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $pyExe = "py"; $pyArgs = @("-3.11") }
    } catch {}

    if ($null -eq $pyExe) {
        Write-Host "[エラー] py -3.11 が見つかりません。Step 1 を確認してください。" -ForegroundColor Red
    } else {
        Write-Host "py -3.11 で仮想環境を作成中..."
        Set-Location $ProjectDir
        & $pyExe @($pyArgs + @("-m", "venv", $VenvDir))
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[完了] 仮想環境を作成しました: $VenvDir"
            & $VenvPython --version
        } else {
            Write-Host "[エラー] 仮想環境の作成に失敗しました。" -ForegroundColor Red
        }
    }
}

Ask-Continue

# ============================================================
# Step 3: Python パッケージのインストール
# ============================================================
Write-Header "Step 3 / 5  :  Python パッケージのインストール"

if (-not (Test-Path $VenvPip)) {
    Write-Host "[エラー] 仮想環境が見つかりません。Step 2 を確認してください。" -ForegroundColor Red
} else {
    Write-Host "インストールするパッケージ:"
    Write-Host "  torch, torchvision, transformers, accelerate,"
    Write-Host "  glmocr, PyMuPDF, Pillow, tkinterdnd2,"
    Write-Host "  opencv-python-headless, huggingface-hub"
    Write-Host ""
    Write-Host "注意: torch は大きいため（約2 GB）、このステップに10〜20分かかる場合があります。"
    Write-Host ""

    Write-Host "[1/4] pip をアップグレード中..."
    & $VenvPip install --upgrade pip

    Write-Host ""
    Write-Host "[2/4] torch / torchvision をインストール中..."
    & $VenvPip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[完了] torch / torchvision をインストールしました。"
    } else {
        Write-Host "[エラー] torch / torchvision のインストールに失敗しました。" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "[3/4] transformers / accelerate をインストール中..."
    & $VenvPip install "transformers>=4.50" accelerate
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[完了] transformers / accelerate をインストールしました。"
    } else {
        Write-Host "[エラー] transformers / accelerate のインストールに失敗しました。" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "[4/4] glmocr, PyMuPDF, Pillow, tkinterdnd2, opencv-python-headless, huggingface-hub をインストール中..."
    & $VenvPip install glmocr PyMuPDF Pillow tkinterdnd2 opencv-python-headless huggingface-hub
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[完了] すべてのパッケージをインストールしました。"
    } else {
        Write-Host "[エラー] パッケージのインストールに失敗しました。" -ForegroundColor Red
    }
}

Ask-Continue

# ============================================================
# Step 4: AI モデルのダウンロード
# ============================================================
Write-Header "Step 4 / 5  :  AI モデルのダウンロード"

if (-not (Test-Path $HfCli)) {
    Write-Host "[エラー] hf コマンドが見つかりません。Step 3 を確認してください。" -ForegroundColor Red
} else {
    Write-Host "ダウンロードするモデル:"
    Write-Host "  zai-org/GLM-OCR                          （約2.5 GB）"
    Write-Host "  PaddlePaddle/PP-DocLayoutV3_safetensors  （約127 MB）"
    Write-Host ""
    Write-Host "キャッシュ先: $env:USERPROFILE\.cache\huggingface\hub\"
    Write-Host "注意: ダウンロード済みのファイルは自動的にスキップされます。"
    Write-Host ""

    Write-Host "[1/2] GLM-OCR をダウンロード中（約2.5 GB — 時間がかかります）..."
    & $HfCli download zai-org/GLM-OCR
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[完了] GLM-OCR をダウンロードしました。"
    } else {
        Write-Host "[エラー] GLM-OCR のダウンロードに失敗しました。" -ForegroundColor Red
        Write-Host "インターネット接続を確認して再試行してください。"
    }

    Write-Host ""
    Write-Host "[2/2] PP-DocLayoutV3 をダウンロード中（約127 MB）..."
    & $HfCli download PaddlePaddle/PP-DocLayoutV3_safetensors
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[完了] PP-DocLayoutV3 をダウンロードしました。"
    } else {
        Write-Host "[エラー] PP-DocLayoutV3 のダウンロードに失敗しました。" -ForegroundColor Red
        Write-Host "インターネット接続を確認して再試行してください。"
    }
}

Ask-Continue

# ============================================================
# Step 5: 起動テスト
# ============================================================
Write-Header "Step 5 / 5  :  起動テスト"

if (-not (Test-Path $VenvPython)) {
    Write-Host "[エラー] 仮想環境が見つかりません。Step 2 を確認してください。" -ForegroundColor Red
} elseif (-not (Test-Path (Join-Path $ProjectDir "main.py"))) {
    Write-Host "[エラー] main.py が見つかりません: $ProjectDir" -ForegroundColor Red
    Write-Host "このインストーラを GLM-OCR-Desktop プロジェクトフォルダから実行していることを確認してください。"
} else {
    Write-Host "インポートテストを実行中..."
    Write-Host ""
    & $VenvPython -c @"
import torch, transformers, fitz, PIL, tkinterdnd2, glmocr
print('すべてのパッケージが正常にロードされました。')
print('  torch:', torch.__version__)
print('  transformers:', transformers.__version__)
"@
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[完了] すべてのパッケージを確認しました。"
    } else {
        Write-Host ""
        Write-Host "[エラー] インポートテストに失敗しました。" -ForegroundColor Red
        Write-Host "上記のエラーメッセージを確認し、Step 3 を再実行してください。"
    }
}

Ask-Continue

# ============================================================
# 完了画面
# ============================================================
Clear-Host
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "   セットアップが完了しました！" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "すべてのインストール手順が完了しました。"
Write-Host ""
Write-Host "[GLM-OCR-Desktop の起動方法]"
Write-Host "  GLM-OCR-Desktop.bat をダブルクリックして起動してください。"
Write-Host ""
Write-Host "  （コマンドプロンプトから手動で起動する場合）"
Write-Host "  1. コマンドプロンプトまたは PowerShell を開く"
Write-Host "  2. cd `"$ProjectDir`""
Write-Host "  3. .venv_bundle\Scripts\python.exe main.py"
Write-Host ""
Read-Host "Enterキーを押して終了"
