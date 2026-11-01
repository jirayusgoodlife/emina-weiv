import re
import json
import html as html_lib
from typing import Dict, Any, List, Optional
from bs4 import BeautifulSoup
import httpx
from urllib.parse import urljoin, urlparse

from .base import BaseSiteHandler
from .generic import GenericHandler
from .animenani import decode_animenani_bootstrap

class AnimeWakuHandler(BaseSiteHandler):
    name = "AnimeWaku"
    domains = [
        "anime-waku.com",
    ]

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        if super().can_handle(url):
            return True
        if html and "anime-waku.com" in html:
            return True
        return False

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        """Extracts metadata and episodes for AnimeWaku, cleaning titles and tags."""
        data = GenericHandler().extract_anime(url, html, soup)
        if not data:
            return None

        # Clean title branding
        if data.get("title"):
            title = data["title"]
            title = re.sub(r"\s*-\s*Anime-Waku.*$", "", title, flags=re.IGNORECASE)
            title = re.sub(r"\s*-\s*อนิเมะวาคุ.*$", "", title, flags=re.IGNORECASE)
            title = re.sub(r"\s*(?:ซับไทย|พากย์ไทย)?\s*จบแล้ว.*$", "", title, flags=re.IGNORECASE)
            data["title"] = title.strip()

        # Clean episode titles
        for ep in data.get("episodes", []):
            if ep.get("title"):
                t = ep["title"]
                t = t.replace("\xa0", " ")
                t = re.sub(r"\s*จบแล้ว\s*$", "", t, flags=re.IGNORECASE).strip()
                ep["title"] = t

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

        # Case 1: URL is already an animenani embed
        if "animenani.com/embed/" in page_url:
            try:
                r_nya = await client.get(page_url, headers=headers)
                return decode_animenani_bootstrap(r_nya.text)
            except Exception:
                return None

        # Case 2: URL is an AnimeWaku player page (/player/{token}/)
        if "/player/" in page_url:
            try:
                r_player = await client.get(page_url, headers=headers)
                return await self._extract_from_player_page(page_url, r_player.text, client)
            except Exception:
                return None

        # Case 3: Episode watch page on anime-waku.com
        if not html:
            try:
                r_page = await client.get(page_url, headers=headers)
                html = r_page.text
                soup = BeautifulSoup(html, "html.parser")
            except Exception as e:
                print(f"[AnimeWaku] Error fetching {page_url}: {e}")
                return None

        parsed_page = urlparse(page_url)
        base_origin = f"{parsed_page.scheme}://{parsed_page.netloc}"

        opt = soup.find(class_="dooplay_player_option") or soup.find(attrs={"data-post": True})
        if not (opt and opt.get("data-post")):
            m_post = re.search(r'data-post=[\'"](\d+)[\'"]', html)
            if not m_post:
                return None
            post_id = m_post.group(1)
            dtype = "tv"
            nume = "1"
        else:
            post_id = opt["data-post"]
            dtype = opt.get("data-type") or ("movie" if "/movies/" in page_url or "/movie/" in page_url else "tv")
            nume = opt.get("data-nume") or "1"

        # Check all player sources (1, 2, 3) in order of preference
        sources_to_try = [nume]
        for s_idx in ["1", "2", "3"]:
            if s_idx not in sources_to_try:
                sources_to_try.append(s_idx)

        for source in sources_to_try:
            api_candidates = [
                f"{base_origin}/wp-json/dooplayer/v1/post/{post_id}?type={dtype}&source={source}",
                f"{base_origin}/wp-json/dooplayer/v2/{post_id}/{dtype}/{source}",
            ]

            embed_url = None
            for api_url in api_candidates:
                try:
                    r_api = await client.get(api_url, headers={
                        "Referer": page_url,
                        "X-Requested-With": "XMLHttpRequest",
                        "User-Agent": headers["User-Agent"]
                    })
                    if r_api.status_code == 200:
                        data = r_api.json()
                        if data.get("embed_url"):
                            embed_url = data["embed_url"]
                            break
                except Exception:
                    continue

            if not embed_url:
                continue

            stream = await self._extract_from_player_page(embed_url, None, client)
            if stream:
                return stream

        return None

    async def _extract_from_player_page(
        self,
        embed_url: str,
        player_html: Optional[str],
        client: httpx.AsyncClient
    ) -> Optional[str]:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": embed_url,
        }
        if not player_html:
            try:
                r_player = await client.get(embed_url, headers=headers)
                player_html = r_player.text
            except Exception as e:
                print(f"[AnimeWaku] Error fetching player {embed_url}: {e}")
                return None

        # 1. Check for animenani / nya.animenani embed links in player_html
        m_nya = re.search(r'https?:\\?/\\?/[^\s"\'<>]+(?:nya\.animenani\.com|animenani\.com)\\?/embed\\?/[^\s"\'<>]+', player_html)
        if not m_nya:
            m_nya = re.search(r'https?://[^\s"\'<>]+(?:nya\.animenani\.com|animenani\.com)/embed/[^\s"\'<>]+', player_html)

        if m_nya:
            nya_url = m_nya.group(0).replace(r"\/", "/")
            try:
                r_nya = await client.get(nya_url, headers=headers)
                manifest = decode_animenani_bootstrap(r_nya.text)
                if manifest:
                    return manifest
            except Exception as e:
                print(f"[AnimeWaku] Error decoding animenani bootstrap: {e}")

        # 2. Check list_server JSON if present
        m_list = re.search(r'list_server\s*:\s*(\[.*?\])\s*,', player_html, re.DOTALL)
        if m_list:
            try:
                servers = json.loads(m_list.group(1))
                for srv in servers:
                    src = srv.get("src")
                    if not src:
                        continue
                    src_clean = src.replace(r"\/", "/")
                    if "animenani.com/embed/" in src_clean:
                        try:
                            r_s = await client.get(src_clean, headers=headers)
                            m_st = decode_animenani_bootstrap(r_s.text)
                            if m_st:
                                return m_st
                        except Exception:
                            pass
                    elif any(ext in src_clean for ext in [".m3u8", ".mp4", "/hls/"]):
                        return src_clean
            except Exception:
                pass

        # 3. Check direct m3u8 or mp4
        unescaped = html_lib.unescape(player_html)
        m_direct = re.search(r'https?://[^\s"\'<>]+(?:\.m3u8|\.mp4)[^\s"\'<>]*', unescaped)
        if m_direct:
            return m_direct.group(0).replace(r"\/", "/")

        return None

