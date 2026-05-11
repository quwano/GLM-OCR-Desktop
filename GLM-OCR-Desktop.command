#!/bin/bash
cd "$(dirname "$0")"

if [ ! -f ".venv_bundle/bin/python" ]; then
    echo "Error: .venv_bundle not found."
    echo "Please run the installer first."
    read -rp "Press Enter to exit"
    exit 1
fi

if [ ! -f "main.py" ]; then
    echo "Error: main.py not found."
    read -rp "Press Enter to exit"
    exit 1
fi

.venv_bundle/bin/python main.py
