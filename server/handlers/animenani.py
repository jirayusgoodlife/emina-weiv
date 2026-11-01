import re
import json
import base64
import urllib.parse
from typing import Dict, Any, List, Optional
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler

def decode_animenani_bootstrap(html: str) -> Optional[str]:
    """Decodes the obfuscated bootstrap script on animenani / nya stream players."""
    match = re.search(r"const\s+s\s*=\s*[\"\'\\]*([A-Za-z0-9+/=_\-]{30,})[\"\'\\]*", html)
    if not match:
        return None
    try:
        s = match.group(1)
        n = s[::-1].replace("-", "+").replace("_", "/")
        p = n.ljust(((len(n) + 3) // 4) * 4, "=")
        decoded = base64.b64decode(p).decode("utf-8")
        data = json.loads(urllib.parse.unquote(decoded))
        return data.get("manifestUrl") or data.get("videoUrl") or data.get("url")
    except Exception as e:
        print(f"[Animenani] Decode error: {e}")
        return None

class AnimenaniHandler(BaseSiteHandler):
    name = "Animenani"
    domains = ["animenani.com", "nya.animenani.com"]

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        if super().can_handle(url):
            return True
        if html and ("animenani" in html or "nya.animenani" in html):
            return True
        return False

    async def resolve_stream(
        self,
        page_url: str,
        html: str,
        soup: BeautifulSoup,
        client: httpx.AsyncClient,
        settings: Optional[Dict[str, str]] = None
    ) -> Optional[str]:
        if not html:
            try:
                headers = {
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
                    "Referer": "https://nya.animenani.com/",
                }
                r = await client.get(page_url, headers=headers)
                html = r.text
            except Exception:
                return None

        # 1. Direct bootstrap in HTML
        manifest = decode_animenani_bootstrap(html)
        if manifest:
            return manifest

        # 2. Check embed links inside page
        nya_match = re.search(r"https?://[^\s\"<>]+(?:nya\.animenani\.com|animenani\.com)/embed/[^\s\"<>]+", html)
        if nya_match:
            try:
                r_nya = await client.get(nya_match.group(0), headers={"Referer": page_url})
                manifest = decode_animenani_bootstrap(r_nya.text)
                if manifest:
                    return manifest
            except Exception:
                pass

        return None
