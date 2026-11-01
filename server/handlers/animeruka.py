import re
import json
import html as html_lib
from typing import Dict, Any, List, Optional
from bs4 import BeautifulSoup
import httpx
from urllib.parse import urljoin, urlparse

from .base import BaseSiteHandler
from .generic import GenericHandler

class AnimeRukaHandler(BaseSiteHandler):
    name = "AnimeRuka"
    domains = [
        "animeruka.com",
        "animemami.xyz",
        "maimeorder.com",
    ]

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        if super().can_handle(url):
            return True
        if html and ("animeruka.com" in html or "animemami.xyz" in html):
            return True
        return False

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        """Extracts metadata and episodes for AnimeRuka, cleaning titles and tags."""
        data = GenericHandler().extract_anime(url, html, soup)
        if not data:
            return None

        # Clean title branding
        if data.get("title"):
            title = data["title"]
            title = re.sub(r"\s*-\s*AnimeRuka.*$", "", title, flags=re.IGNORECASE)
            title = re.sub(r"\s*อนิเมะรุกะ.*$", "", title, flags=re.IGNORECASE)
            title = re.sub(r"\s*(?:ซับไทย|พากย์ไทย)?\s*จบแล้ว.*$", "", title, flags=re.IGNORECASE)
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

        # Case 1: URL is already an animemami player embed
        if "animemami.xyz/v/" in page_url:
            return await self._extract_from_animemami(page_url, client, headers)

        # Case 2: Episode page on animeruka.com
        if not html:
            try:
                r_page = await client.get(page_url, headers=headers)
                html = r_page.text
                soup = BeautifulSoup(html, "html.parser")
            except Exception as e:
                print(f"[AnimeRuka] Error fetching {page_url}: {e}")
                return None

        parsed_page = urlparse(page_url)
        base_origin = f"{parsed_page.scheme}://{parsed_page.netloc}"

        opt = soup.find(class_="dooplay_player_option") or soup.find(attrs={"data-post": True})
        if not (opt and opt.get("data-post")):
            # Fallback regex search for data-post
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

        # Check player_api from dtAjax script if present
        m_api = re.search(r'[\'"]player_api[\'"]\s*:\s*[\'"]([^\'"]+)[\'"]', html)
        player_api = m_api.group(1) if m_api else ""

        api_candidates = []
        if player_api:
            if "/v2/" in player_api:
                api_candidates.append(f"{player_api.rstrip('/')}/{post_id}/{dtype}/{nume}")
            else:
                api_candidates.append(f"{player_api.rstrip('/')}/post/{post_id}?type={dtype}&source={nume}")

        api_candidates.append(f"{base_origin}/wp-json/dooplayer/v2/{post_id}/{dtype}/{nume}")
        api_candidates.append(f"{base_origin}/wp-json/dooplayer/v1/post/{post_id}?type={dtype}&source={nume}")

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
            return None

        return await self._extract_from_animemami(embed_url, client, {"Referer": page_url, "User-Agent": headers["User-Agent"]})

    async def _extract_from_animemami(self, embed_url: str, client: httpx.AsyncClient, headers: Dict[str, str]) -> Optional[str]:
        try:
            r_embed = await client.get(embed_url, headers=headers)
            embed_html = r_embed.text

            # 1. Check data-page JSON in Inertia / Vue (animemami.xyz)
            m_page = re.search(r'data-page=[\'"]({.+?}|[^\'"]+)[\'"]', embed_html)
            if m_page:
                raw_json = html_lib.unescape(m_page.group(1))
                try:
                    pdata = json.loads(raw_json)
                    vurl = pdata.get("props", {}).get("video", {}).get("url")
                    if vurl:
                        return vurl.replace(r"\/", "/")
                except Exception:
                    pass

            # 2. Check JSON "url": "https://..."
            unescaped_html = html_lib.unescape(embed_html)
            m_url = re.search(r'[\'"]url[\'"]\s*:\s*[\'"](https?:[^\'"]+)[\'"]', unescaped_html)
            if m_url:
                cand = m_url.group(1).replace(r"\/", "/")
                if any(ext in cand for ext in [".txt", ".m3u8", ".mp4", "/hls/"]):
                    return cand

            # 3. Direct m3u8, mp4 or hls txt match
            m_stream = re.search(r'https?://[^\s"\'<>]+(?:\.m3u8|\.mp4|\/hls\/[^\s"\'<>]+\.txt)[^\s"\'<>]*', unescaped_html)
            if m_stream:
                return m_stream.group(0).replace(r"\/", "/")

            # 4. Check nested iframes
            soup_embed = BeautifulSoup(embed_html, "html.parser")
            for ifr in soup_embed.find_all("iframe"):
                isrc = ifr.get("src")
                if isrc:
                    full_sub = urljoin(embed_url, isrc)
                    sub_res = await self._extract_from_animemami(full_sub, client, {"Referer": embed_url, "User-Agent": headers.get("User-Agent", "")})
                    if sub_res:
                        return sub_res
        except Exception as e:
            print(f"[AnimeRuka] Error extracting from embed {embed_url}: {e}")

        return None

