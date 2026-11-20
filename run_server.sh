#!/bin/bash
# Script to run Anime Studio Web App & Sync Server
set -e
cd "$(dirname "$0")/server"

if [ ! -f ".venv/bin/python" ]; then
    echo "Virtual environment not found or incomplete. Setting up .venv..."
    rm -rf .venv
    if command -v uv >/dev/null 2>&1; then
        echo "Using uv to create venv and install dependencies..."
        uv venv
        uv pip install fastapi uvicorn httpx beautifulsoup4 pydantic python-multipart
    elif command -v python3 >/dev/null 2>&1; then
        echo "uv not found. Falling back to python3 -m venv..."
        python3 -m venv .venv
        .venv/bin/pip install --upgrade pip 2>/dev/null || true
        .venv/bin/pip install fastapi uvicorn httpx beautifulsoup4 pydantic python-multipart
    else
        echo "Error: Neither uv nor python3 was found. Please install python3 and python3-venv."
        exit 1
    fi
fi

echo "Starting Anime Studio Server on http://0.0.0.0:8800..."
# Free port 8800 if occupied by previous session
fuser -k 8800/tcp 2>/dev/null || true
sleep 0.5
exec .venv/bin/python run.py
