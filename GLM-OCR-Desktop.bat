@echo off
cd /d "%~dp0"

if not exist ".venv_bundle\Scripts\python.exe" (
    echo Error: .venv_bundle not found.
    echo Please run the installer first.
    pause
    exit /b 1
)

if not exist "main.py" (
    echo Error: main.py not found.
    pause
    exit /b 1
)

.venv_bundle\Scripts\python.exe main.py