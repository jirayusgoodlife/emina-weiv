#!/bin/bash
# Script to run Anime Studio Web App & Sync Server
cd "$(dirname "$0")/server"
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
    uv pip install fastapi uvicorn httpx beautifulsoup4 pydantic
fi

echo "Starting Anime Studio Server on http://0.0.0.0:8800..."
# Free port 8800 if occupied by previous session
fuser -k 8800/tcp 2>/dev/null || true
sleep 0.5
.venv/bin/python run.py
