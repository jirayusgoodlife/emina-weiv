import socket
import json
import asyncio
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, Response, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import httpx
import os

from db import init_db, get_all_anime, get_anime_by_slug, save_anime, delete_anime, get_settings, save_settings
from extractor import extract_anime, resolve_direct_stream

# Initialize SQLite database
init_db()

app = FastAPI(title="Anime Studio & Sync Server", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_local_ips() -> List[str]:
    ips = ["127.0.0.1"]
    # 1. Socket probe
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        lan_ip = s.getsockname()[0]
        s.close()
        if lan_ip not in ips and not lan_ip.startswith("172."):
            ips.append(lan_ip)
    except Exception:
        pass

    # 2. Add local LAN interfaces (192.168.x.x, 10.x.x.x)
    try:
        import subprocess
        out = subprocess.check_output(["ip", "-4", "addr", "show"], text=True)
        for line in out.splitlines():
            line = line.strip()
            if line.startswith("inet ") and not "scope host" in line:
                ip = line.split()[1].split("/")[0]
                if not ip.startswith("172.") and ip not in ips:
                    ips.append(ip)
    except Exception:
        pass

    return ips

class ExtractRequest(BaseModel):
    url: str
    use_ai: bool = True

class StreamResolveRequest(BaseModel):
    page_url: str

class SettingsRequest(BaseModel):
    llm_provider: str
    lmstudio_url: Optional[str] = "http://localhost:1234/v1"
    lmstudio_model: Optional[str] = "local-model"
    ollama_url: Optional[str] = "http://localhost:11434"
    ollama_model: Optional[str] = "llama3.2"

@app.get("/api/info")
def get_info(request: Request):
    port = request.url.port or 8800
    ips = get_local_ips()
    sync_urls = [f"http://{ip}:{port}/api/sync" for ip in ips]
    return {
        "status": "online",
        "port": port,
        "local_ips": ips,
        "sync_urls": sync_urls,
        "recommended_sync_url": sync_urls[-1] if len(sync_urls) > 1 else sync_urls[0]
    }

@app.get("/api/supported_sites")
def get_supported_sites():
    from handlers import list_supported_sites
    return {
        "status": "ok",
        "sites": list_supported_sites(),
        "generic_fallback": True
    }

@app.get("/api/settings")
def api_get_settings():
    return get_settings()

@app.post("/api/settings")
def api_save_settings(req: SettingsRequest):
    save_settings(req.dict())
    return {"status": "ok", "settings": get_settings()}

@app.get("/api/models")
async def api_get_models(provider: Optional[str] = None, url: Optional[str] = None):
    settings = get_settings()
    provider = provider or settings.get("llm_provider", "lmstudio")
    try:
        if provider == "ollama":
            base_url = (url or settings.get("ollama_url", "http://localhost:11434")).rstrip("/")
            async with httpx.AsyncClient(timeout=4.0) as client:
                resp = await client.get(f"{base_url}/api/tags")
                resp.raise_for_status()
                models = [m["name"] for m in resp.json().get("models", [])]
                active_model = models[0] if models else None
                return {"status": "ok", "provider": "ollama", "models": models, "active_model": active_model}
        else:
            base_url = (url or settings.get("lmstudio_url", "http://localhost:1234/v1")).rstrip("/")
            async with httpx.AsyncClient(timeout=4.0) as client:
                resp = await client.get(f"{base_url}/models")
                resp.raise_for_status()
                models = [m["id"] for m in resp.json().get("data", [])]
                active_model = models[0] if models else None
                return {"status": "ok", "provider": "lmstudio", "models": models, "active_model": active_model}
    except Exception as e:
        return {"status": "error", "message": str(e), "models": [], "active_model": None}

@app.post("/api/test_llm")
async def api_test_llm():
    settings = get_settings()
    provider = settings.get("llm_provider", "lmstudio")
    try:
        if provider == "ollama":
            url = settings.get("ollama_url", "http://localhost:11434").rstrip("/")
            async with httpx.AsyncClient(timeout=5.0) as client:
                resp = await client.get(f"{url}/api/tags")
                resp.raise_for_status()
                models = [m["name"] for m in resp.json().get("models", [])]
                return {"status": "connected", "provider": "ollama", "models": models, "active_model": models[0] if models else None}
        else: # lmstudio or openai-compatible
            url = settings.get("lmstudio_url", "http://localhost:1234/v1").rstrip("/")
            async with httpx.AsyncClient(timeout=5.0) as client:
                resp = await client.get(f"{url}/models")
                resp.raise_for_status()
                models = [m["id"] for m in resp.json().get("data", [])]
                return {"status": "connected", "provider": "lmstudio", "models": models, "active_model": models[0] if models else None}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/extract")
async def api_extract(req: ExtractRequest):
    if not req.url or not req.url.startswith("http"):
        raise HTTPException(status_code=400, detail="Invalid URL")
    settings = get_settings()
    try:
        data = await extract_anime(req.url, settings, use_ai=req.use_ai)
        if data.get("split_collections"):
            for col in data["split_collections"]:
                col.pop("split_collections", None)
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/extract_stream")
async def api_extract_stream(req: ExtractRequest):
    if not req.url or not req.url.startswith("http"):
        raise HTTPException(status_code=400, detail="Invalid URL")
    settings = get_settings()

    async def event_generator():
        queue = asyncio.Queue()

        async def on_event(ev: Dict[str, Any]):
            await queue.put(ev)

        async def worker():
            try:
                data = await extract_anime(req.url, settings, use_ai=req.use_ai, on_event=on_event)
                if data.get("split_collections"):
                    for col in data["split_collections"]:
                        col.pop("split_collections", None)
                await queue.put({"type": "done", "result": data})
            except Exception as e:
                await queue.put({"type": "error", "message": str(e)})
            finally:
                await queue.put(None)

        task = asyncio.create_task(worker())

        while True:
            item = await queue.get()
            if item is None:
                break
            yield f"data: {json.dumps(item, ensure_ascii=False)}\n\n"

        await task

    return StreamingResponse(event_generator(), media_type="text/event-stream")

@app.post("/api/resolve_stream")
async def api_resolve_stream(req: StreamResolveRequest):
    settings = get_settings()
    stream_url = await resolve_direct_stream(req.page_url, settings=settings)
    return {"stream_url": stream_url or ""}

@app.get("/api/anime")
def api_get_anime_list():
    return get_all_anime()

@app.get("/api/anime/{slug}")
def api_get_anime(slug: str):
    item = get_anime_by_slug(slug)
    if not item:
        raise HTTPException(status_code=404, detail="Anime not found")
    return item

@app.post("/api/anime")
def api_save_anime(data: Dict[str, Any]):
    if not data.get("slug") or not data.get("title"):
        raise HTTPException(status_code=400, detail="Title and slug are required")
    
    # If this item contains multiple split audio collections (e.g. Sub and Dub)
    if data.get("split_collections"):
        saved_list = []
        for col in data["split_collections"]:
            col_clean = dict(col)
            col_clean.pop("split_collections", None)
            saved_list.append(save_anime(col_clean))
        first_clean = dict(saved_list[0])
        first_clean.pop("split_collections", None)
        return {"status": "ok", "anime": first_clean, "all_saved": saved_list}

    data_clean = dict(data)
    data_clean.pop("split_collections", None)
    saved = save_anime(data_clean)
    return {"status": "ok", "anime": saved}

@app.delete("/api/anime/{slug}")
def api_delete_anime(slug: str):
    success = delete_anime(slug)
    return {"status": "ok", "deleted": success}

@app.get("/api/sync")
def api_sync():
    """Returns catalog payload tailored for Flutter Isar sync."""
    animes = get_all_anime()
    return {
        "version": "1.0",
        "timestamp": os.times()[4],
        "count": len(animes),
        "data": animes
    }

def get_stream_proxy_headers(target_url: str) -> Dict[str, str]:
    target_lower = target_url.lower()
    if "stream-aph" in target_lower or "qqhls" in target_lower or "qqstream" in target_lower:
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://qqstream.stream-aph.xyz/",
            "Origin": "https://qqstream.stream-aph.xyz",
            "Accept": "*/*",
        }
    if "animenani" in target_lower:
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://nya.animenani.com/",
            "Origin": "https://nya.animenani.com",
            "Accept": "*/*",
        }
    if "maimeorder" in target_lower or "animemami" in target_lower:
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://animemami.xyz/",
            "Origin": "https://animemami.xyz",
            "Accept": "*/*",
        }
    if "fairyanime" in target_lower or "tonytonychopper" in target_lower:
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://anime.tonytonychopper.net/",
            "Accept": "*/*",
        }
    return {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Referer": "https://main.24playerhd.com/",
        "Origin": "https://main.24playerhd.com",
        "Accept": "*/*",
    }

# HLS Stream Stripping Proxy for anti-hotlinking / obfuscated video streams (animenani, 24playerhd, etc.)
@app.api_route("/api/proxy/hls/manifest", methods=["GET", "HEAD"])
async def proxy_hls_manifest(url: str, request: Request):
    headers = get_stream_proxy_headers(url)
    async with httpx.AsyncClient(timeout=15.0, verify=False) as client:
        r = await client.get(url, headers=headers)
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail="Failed to fetch manifest")
        
        raw_text = r.text
        trimmed = raw_text.strip()
        if trimmed.startswith("{") and '"p"' in trimmed:
            try:
                parsed = json.loads(trimmed)
                if isinstance(parsed, dict) and "p" in parsed:
                    import base64
                    p_str = parsed["p"].replace("\n", "").replace("\r", "").strip()
                    raw_text = base64.b64decode(p_str).decode("utf-8", errors="ignore")
            except Exception as e:
                print(f"[ProxyHls] Error decoding base64 manifest: {e}")

        # Rewrite lines in manifest
        lines = raw_text.splitlines()
        new_lines = []
        import urllib.parse
        host = request.headers.get("host") or "127.0.0.1:8800"
        scheme = request.url.scheme
        base_proxy = f"{scheme}://{host}/api/proxy/hls"

        last_tag = ""
        for line in lines:
            line_str = line.strip()
            if not line_str or line_str.startswith("#"):
                if line_str.startswith("#EXTINF"):
                    last_tag = "EXTINF"
                elif line_str.startswith("#EXT-X-STREAM-INF") or line_str.startswith("#EXT-X-MEDIA"):
                    last_tag = "STREAM-INF"
                new_lines.append(line)
            else:
                target_url = urllib.parse.urljoin(url, line_str)
                path = urllib.parse.urlparse(target_url).path.lower()
                is_seg = (
                    last_tag == "EXTINF"
                    or any(path.endswith(ext) for ext in [".webp", ".ts", ".m4s", ".mp4", ".png", ".jpg"])
                    or ".webp" in line_str
                    or ".ts" in line_str
                    or "/file/hls" in line_str
                )
                encoded = urllib.parse.quote(target_url, safe="")
                if is_seg:
                    new_lines.append(f"{base_proxy}/segment?url={encoded}")
                else:
                    new_lines.append(f"{base_proxy}/manifest?url={encoded}")

        content = "\n".join(new_lines)
        return Response(content=content, media_type="application/vnd.apple.mpegurl")

@app.api_route("/api/proxy/hls/segment", methods=["GET", "HEAD"])
async def proxy_hls_segment(url: str):
    headers = get_stream_proxy_headers(url)
    async with httpx.AsyncClient(timeout=25.0, verify=False) as client:
        r = await client.get(url, headers=headers)
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail="Failed to fetch segment")

        data = r.content
        # Dynamic MPEG-TS sync byte stripping for fake PNG/WebP headers (Animenani, 24playerhd, etc.)
        if len(data) > 40 and data[0] != 0x47:
            limit = min(len(data) - 376, 16000)
            for i in range(limit):
                if data[i] == 0x47 and data[i + 188] == 0x47 and data[i + 376] == 0x47:
                    data = data[i:]
                    break

        return Response(content=data, media_type="video/MP2T")

# Serve the HTML frontend
@app.get("/", response_class=HTMLResponse)
def index():
    html_path = os.path.join(os.path.dirname(__file__), "templates", "index.html")
    if os.path.exists(html_path):
        with open(html_path, "r", encoding="utf-8") as f:
            return Response(
                content=f.read(),
                media_type="text/html",
                headers={"Cache-Control": "no-cache, no-store, must-revalidate", "Pragma": "no-cache"}
            )
    return "<h1>Anime Studio Server Running</h1>"
