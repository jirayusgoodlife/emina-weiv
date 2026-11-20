import re
import json
from typing import Dict, Any, List, Optional
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler

def unpack_packer(js_code: str) -> str:
    """Unpacks Dean Edwards p,a,c,k,e,d JavaScript code."""
    pattern = r'\}\s*\(\s*([\'\"].*?[\'\"])\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\'\"].*?[\'\"])\.split\([\'\"]\|[\'\"]\)'
    match = re.search(pattern, js_code, re.DOTALL)
    if not match:
        return ''
    
    payload = match.group(1)[1:-1]
    radix = int(match.group(2))
    count = int(match.group(3))
    symtab = match.group(4)[1:-1].split('|')

    digits = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

    def base_n(num, b):
        if num == 0:
            return '0'
        res = []
        while num > 0:
            res.append(digits[num % b])
            num = num // b
        return ''.join(reversed(res))

    d = {}
    for c in range(count):
        key = base_n(c, radix)
        val = symtab[c] if c < len(symtab) and symtab[c] else key
        d[key] = val

    def replace_word(m):
        w = m.group(0)
        return d.get(w, w)

    return re.sub(r'\b\w+\b', replace_word, payload)


class NJavTvHandler(BaseSiteHandler):
    """
    Handler for nJAV (njavtv.com) and MissAV mirrors.
    Extracts video metadata and resolves HLS streams (surrit.com playlist.m3u8).
    """
    name = "nJAV TV / MissAV"
    domains = [
        "njavtv.com",
        "njav.tv",
        "missav.ai",
        "missav.ws",
        "missav.live",
        "kizzew.com",
        "missav01.com",
        "missav123.com",
        "missav789.com",
        "123av.org",
        "thisav2.com",
        "missav888.com",
        "myav.com",
    ]

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        if super().can_handle(url):
            return True
        if html and ("njavtv.com" in html or "nJAV" in html or "surrit.com" in html or "missav" in html):
            return True
        return False

    def _extract_stream_from_html(self, html: str) -> Optional[str]:
        if not html:
            return None

        # 1. Unpack Dean Edwards packed scripts
        for m in re.finditer(r'eval\(function\(p,a,c,k,e,d\).+?\.split\([\'\"]\|[\'\"]\)\s*,\s*0\s*,\s*\{\}\s*\)', html, re.DOTALL):
            unpacked = unpack_packer(m.group(0))
            unpacked = unpacked.replace('\\/', '/').replace("\\'", "'").replace('\\"', '"')

            # Master playlist preferred
            m_playlist = re.search(r'https?://[^\s\'"<>\\]+?/playlist\.m3u8', unpacked)
            if m_playlist:
                return m_playlist.group(0)

            # Any m3u8
            m_m3u8 = re.search(r'https?://[^\s\'"<>\\]+?\.m3u8', unpacked)
            if m_m3u8:
                return m_m3u8.group(0)

        # 2. Check for direct m3u8 in HTML
        m_direct = re.search(r'https?://[^\s\'"<>\\]+?/playlist\.m3u8', html)
        if m_direct:
            return m_direct.group(0)

        m_m3u8_direct = re.search(r'https?://[^\s\'"<>\\]+?\.m3u8', html)
        if m_m3u8_direct:
            return m_m3u8_direct.group(0)

        return None

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        # 1. Title
        title = ""
        h1 = soup.find("h1")
        if h1:
            title = h1.get_text(strip=True)
        if not title:
            og_t = soup.find("meta", property="og:title")
            title = og_t["content"] if og_t and og_t.get("content") else (soup.title.string if soup.title else "")

        code = ""
        release_date = ""
        year = ""
        genres = []
        maker = ""
        director = ""

        # Metadata table
        meta_box = soup.find("div", class_="space-y-2")
        if meta_box:
            for row in meta_box.find_all("div", class_="text-secondary"):
                row_text = row.get_text(" ", strip=True)
                if "Code:" in row_text:
                    code_el = row.find("span", class_="font-medium")
                    if code_el:
                        code = code_el.get_text(strip=True)
                elif "Release date:" in row_text:
                    time_el = row.find("time")
                    if time_el:
                        release_date = time_el.get_text(strip=True)
                        year_m = re.search(r"\b(19\d\d|20\d\d)\b", release_date)
                        if year_m:
                            year = year_m.group(1)
                elif "Genre:" in row_text:
                    for a in row.find_all("a"):
                        g = a.get_text(strip=True)
                        if g and g not in genres:
                            genres.append(g)
                elif "Maker:" in row_text:
                    a = row.find("a")
                    if a:
                        maker = a.get_text(strip=True)
                elif "Director:" in row_text:
                    a = row.find("a")
                    if a:
                        director = a.get_text(strip=True)

        if not year:
            year_m = re.search(r"\b(19\d\d|20\d\d)\b", release_date or html)
            if year_m:
                year = year_m.group(1)

        # Slug
        parsed = urlparse(url)
        slug = parsed.path.strip("/").split("/")[-1]
        if not slug:
            slug = re.sub(r"[^a-zA-Z0-9]+", "-", (code or title).lower()).strip("-")

        # Cover image
        cover_url = ""
        og_img = soup.find("meta", property="og:image")
        if og_img and og_img.get("content"):
            cover_url = og_img["content"]
        if not cover_url:
            v_player = soup.find("video", class_="player")
            if v_player and v_player.get("data-poster"):
                cover_url = v_player["data-poster"]

        # Synopsis
        synopsis = ""
        syn_el = soup.find("div", class_=re.compile(r"break-all"))
        if syn_el:
            synopsis = syn_el.get_text(strip=True)
        if not synopsis:
            og_desc = soup.find("meta", property="og:description")
            if og_desc and og_desc.get("content"):
                synopsis = og_desc["content"]

        # Stream resolution right away if present in page
        stream_url = self._extract_stream_from_html(html) or ""

        ep_title = code or "Full Video"
        episodes = [{
            "episode_number": 1.0,
            "title": ep_title,
            "page_url": url,
            "stream_url": stream_url,
            "thumbnail_url": cover_url,
            "audio_type": "unknown",
            "id": f"{slug}-ep-1"
        }]

        return {
            "slug": slug,
            "title": title or code or "nJAV Video",
            "cover_url": cover_url,
            "backdrop_url": cover_url,
            "synopsis": synopsis,
            "genres": genres,
            "rating": "8.5",
            "status": "จบแล้ว (1 ตอน)",
            "year": year,
            "source_url": url,
            "is_movie": True,
            "episodes": episodes,
        }

    async def resolve_stream(
        self,
        page_url: str,
        html: str,
        soup: BeautifulSoup,
        client: httpx.AsyncClient,
        settings: Optional[Dict[str, Any]] = None,
    ) -> Optional[str]:
        # 1. Try resolving from existing html
        if html:
            stream = self._extract_stream_from_html(html)
            if stream:
                return stream

        # 2. Fetch page HTML if empty or missing stream
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
            "Referer": "https://njavtv.com/",
        }
        try:
            r = await client.get(page_url, headers=headers)
            if r.status_code == 200:
                return self._extract_stream_from_html(r.text)
        except Exception as e:
            print(f"[NJavTvHandler] Error fetching stream for {page_url}: {e}")

        return None
