import re
import json
import base64
import subprocess
from typing import Dict, Any, List, Optional
from bs4 import BeautifulSoup
import httpx
from urllib.parse import urljoin, urlparse

from .base import BaseSiteHandler
from .generic import GenericHandler

def unpack_tonytonychopper(html: str) -> Optional[str]:
    """Unpacks multi-layer Dean Edwards / Cookie.Run packed scripts from tonytonychopper players."""
    m_eval = re.search(r'(eval\(function\(p,a,c,k,e,d\).+?\n)', html)
    if not m_eval:
        m_eval = re.search(r'eval\(function\(p,a,c,k,e,d\).+?Cookie.+?\)\)', html, re.DOTALL)
    if not m_eval:
        return None

    eval_code = m_eval.group(1).strip()
    js_script = f"""
    const evalCode = {json.dumps(eval_code)};
    let b64Str = '';
    const Cookie = {{ Run: (s) => {{ b64Str = s; }} }};
    const vm = require('vm');
    const ctx = {{ eval: (c) => vm.runInContext(c, ctx), Cookie: Cookie, console: console }};
    vm.createContext(ctx);
    try {{
        vm.runInContext(evalCode, ctx);
    }} catch(e) {{}}
    if (b64Str) {{
        const decoded = Buffer.from(b64Str, 'base64').toString('utf8');
        let res = '';
        const ctx2 = {{
            console: console,
            eval: (code) => {{
                const ctx3 = {{ console: console, eval: (code3) => {{ res = code3; }} }};
                vm.createContext(ctx3);
                try {{ vm.runInContext(code, ctx3); }} catch(e) {{}}
            }}
        }};
        vm.createContext(ctx2);
        try {{ vm.runInContext(decoded, ctx2); }} catch(e) {{}}
        console.log(res);
    }}
    """
    try:
        out = subprocess.check_output(['node', '-e', js_script], text=True, timeout=5)
        m_hls = re.search(r'hls\s*=\s*["\']([^"\']+)["\']', out)
        if m_hls:
            return m_hls.group(1)
    except Exception as e:
        print(f"[FairyAnime] Node unpack exception: {e}")
    return None


class FairyAnimeHandler(BaseSiteHandler):
    name = "FairyAnime"
    domains = [
        "fairyanime.net",
        "streaming.tonytonychopper.com",
        "anime.tonytonychopper.net",
    ]

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        if super().can_handle(url):
            return True
        if html and ("fairyanime.net" in html or "tonytonychopper" in html or "/base/" in html):
            return True
        return False

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        """Extracts metadata and episodes for FairyAnime, refining titles and watch links."""
        data = GenericHandler().extract_anime(url, html, soup)
        if not data:
            return None

        # Clean title branding
        if data.get("title"):
            title = data["title"]
            title = re.sub(r"\s*-\s*FairyAnime.*$", "", title, flags=re.IGNORECASE)
            title = re.sub(r"\s*แฟรี่อนิเมะ.*$", "", title, flags=re.IGNORECASE)
            title = re.sub(r"\s+\d+-\d+\s*(?:ซับไทย|พากย์ไทย).*$", "", title, flags=re.IGNORECASE)
            data["title"] = title.strip()

        return data

    async def resolve_stream(
        self,
        page_url: str,
        html: str,
        soup: BeautifulSoup,
        client: httpx.AsyncClient,
        settings: Optional[Dict[str, str]] = None
    ) -> Optional[str]:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": page_url,
        }

        # Case 1: URL is already an anime player iframe (e.g. https://anime.tonytonychopper.net/v2/{id})
        m_v2 = re.search(r'/v2/([a-zA-Z0-9_-]+)', page_url)
        if m_v2:
            stream_id = m_v2.group(1)
            target = f"https://anime.tonytonychopper.net/file2/{stream_id}/"
            try:
                r_test = await client.get(target, headers=headers)
                if r_test.status_code == 200 and "#EXTM3U" in r_test.text:
                    return target
            except Exception:
                pass

        # Case 2: Watch page on fairyanime.net
        ep_code = None
        m_code = re.search(r'/watch/([a-zA-Z0-9_-]+)', page_url)
        if m_code:
            ep_code = m_code.group(1).rstrip(".html")

        if not ep_code and html:
            m_base_script = re.search(r'/base/([a-zA-Z0-9_-]+)/?', html)
            if m_base_script:
                ep_code = m_base_script.group(1)
            else:
                m_report = re.search(r'reportFile\([\'"]([a-zA-Z0-9_-]+)[\'"]\)', html)
                if m_report:
                    ep_code = m_report.group(1)

        if not ep_code:
            return None

        # Fetch base script for this episode
        base_url = f"https://fairyanime.net/base/{ep_code}/"
        try:
            r_base = await client.get(base_url, headers=headers)
            base_js = r_base.text
        except Exception as e:
            print(f"[FairyAnime] Failed to fetch base script {base_url}: {e}")
            return None

        # Extract streaming host
        m_host = re.search(r'webmainapp\s*=\s*[\'"]([^\'"]+)[\'"]', base_js)
        host = m_host.group(1) if m_host else "https://streaming.tonytonychopper.com/"
        host = host.rstrip("/")

        # Extract candidate playback video IDs
        candidate_vids: List[str] = []
        
        # 1. Look inside switch_play(v)
        m_switch = re.search(r'switch_play\(v\)\s*\{[^\}]*playback/[a-z]/([a-zA-Z0-9_-]+)', base_js)
        if m_switch:
            candidate_vids.append(m_switch.group(1))

        # 2. Extract all playback paths
        all_matches = re.findall(r'playback/([a-z])/([a-zA-Z0-9_-]+)', base_js)
        for _, vid in all_matches:
            if vid != ep_code and vid not in candidate_vids:
                candidate_vids.append(vid)

        # Fallback to ep_code if nothing else found
        if not candidate_vids:
            candidate_vids.append(ep_code)

        # Try playback servers: primarily 'v' (main video embed) then 'f', 'x', 'y', 'z'
        kinds = ['v', 'f', 'x', 'y', 'z']
        for vid in candidate_vids:
            for kind in kinds:
                pb_url = f"{host}/playback/{kind}/{vid}/"
                try:
                    r_pb = await client.get(pb_url, headers={"Referer": page_url, "User-Agent": headers["User-Agent"]})
                    if r_pb.status_code != 200:
                        continue
                    
                    pb_html = r_pb.text
                    # Check for iframe to anime.tonytonychopper.net
                    iframes = re.findall(r'<iframe[^>]+src=[\'"]([^\'"]+)[\'"]', pb_html)
                    for ifr in iframes:
                        m_stream = re.search(r'/v2/([a-zA-Z0-9_-]+)', ifr)
                        if m_stream:
                            stream_id = m_stream.group(1)
                            m3u8_url = f"https://anime.tonytonychopper.net/file2/{stream_id}/"
                            # Verify M3U8
                            try:
                                r_m3u8 = await client.get(m3u8_url, headers={"Referer": ifr, "User-Agent": headers["User-Agent"]})
                                if r_m3u8.status_code == 200 and "#EXTM3U" in r_m3u8.text:
                                    return m3u8_url
                            except Exception:
                                pass

                        # Fallback for /v/
                        m_stream_v1 = re.search(r'/v/([a-zA-Z0-9_-]+)', ifr)
                        if m_stream_v1:
                            stream_id = m_stream_v1.group(1)
                            m3u8_url = f"https://anime.tonytonychopper.net/file/{stream_id}/"
                            try:
                                r_m3u8 = await client.get(m3u8_url, headers={"Referer": ifr, "User-Agent": headers["User-Agent"]})
                                if r_m3u8.status_code == 200 and "#EXTM3U" in r_m3u8.text:
                                    return m3u8_url
                            except Exception:
                                pass

                        # Try unpacking the iframe HTML if direct pattern failed
                        try:
                            r_ifr = await client.get(ifr, headers={"Referer": pb_url, "User-Agent": headers["User-Agent"]})
                            unpacked = unpack_tonytonychopper(r_ifr.text)
                            if unpacked:
                                return unpacked
                        except Exception:
                            pass

                except Exception as e:
                    continue

        return None

