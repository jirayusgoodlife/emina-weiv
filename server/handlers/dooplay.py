import re
import json
import html as html_lib
from typing import Dict, Any, List, Optional
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler

class DooPlayHandler(BaseSiteHandler):
    """
    Handles WordPress websites powered by the popular DooPlay anime theme
    (e.g., anime-waku, animeruka, animekimi, and other DooPlay clones).
    """
    name = "DooPlay"
    domains = [
        "anime-waku.com",
        "animeruka.com",
        "animekimi.com",
        "anime-subthai.com",
        "123-hd.com"
    ]

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        if super().can_handle(url):
            return True
        # Autodetect DooPlay signatures in HTML
        if html and ("dooplay_player_option" in html or "wp-json/dooplayer" in html or "data-post=" in html):
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
                r_page = await client.get(page_url)
                html = r_page.text
                soup = BeautifulSoup(html, "html.parser")
            except Exception as e:
                print(f"[DooPlayHandler] error fetching page {page_url}: {e}")
                return None

        parsed_page = urlparse(page_url)
        base_origin = f"{parsed_page.scheme}://{parsed_page.netloc}"
        import urllib.parse
        query_params = urllib.parse.parse_qs(parsed_page.query)
        target_nume = query_params.get("source", [None])[0] or query_params.get("nume", [None])[0]

        opt = None
        if target_nume:
            opt = soup.find(class_="dooplay_player_option", attrs={"data-nume": str(target_nume)}) or soup.find(attrs={"data-post": True, "data-nume": str(target_nume)})
        if not opt:
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
            nume = opt.get("data-nume") or target_nume or "1"
        
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
                    "X-Requested-With": "XMLHttpRequest"
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

        try:
            r_player = await client.get(embed_url, headers={"Referer": page_url})
            player_html = r_player.text

            # 1. Check data-page JSON in Inertia / Vue (animemami.xyz)
            m_page = re.search(r'data-page=[\'"]({.+?}|[^\'"]+)[\'"]', player_html)
            if m_page:
                raw_json = html_lib.unescape(m_page.group(1))
                try:
                    pdata = json.loads(raw_json)
                    vurl = pdata.get("props", {}).get("video", {}).get("url")
                    if vurl:
                        return vurl.replace(r"\/", "/")
                except Exception:
                    pass

            # 2. Check for animenani / nya.animenani embed links (common in anime-waku and dooplay themes)
            m_nya = re.search(r'https?:\\?/\\?/[^\s"\'<>]+(?:nya\.animenani\.com|animenani\.com)\\?/embed\\?/[^\s"\'<>]+', player_html)
            if not m_nya:
                m_nya = re.search(r'https?://[^\s"\'<>]+(?:nya\.animenani\.com|animenani\.com)/embed/[^\s"\'<>]+', player_html)
            if m_nya:
                nya_url = m_nya.group(0).replace(r"\/", "/")
                try:
                    from .animenani import decode_animenani_bootstrap
                    r_nya = await client.get(nya_url, headers={
                        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
                        "Referer": embed_url
                    })
                    manifest = decode_animenani_bootstrap(r_nya.text)
                    if manifest:
                        return manifest
                except Exception:
                    pass

            unescaped_html = html_lib.unescape(player_html)

            # 3. Check JSON "url": "https://..."
            m_url = re.search(r'[\'"]url[\'"]\s*:\s*[\'"](https?:[^\'"]+)[\'"]', unescaped_html)
            if m_url:
                cand = m_url.group(1).replace(r"\/", "/")
                if any(ext in cand for ext in [".txt", ".m3u8", ".mp4", "/hls/"]):
                    return cand

            # 3. Direct m3u8 or mp4 or hls txt match
            m3u8 = re.search(r'https?://[^\s"\'<>]+(?:\.m3u8|\.mp4|\/hls\/[^\s"\'<>]+\.txt)[^\s"\'<>]*', unescaped_html)
            if m3u8:
                return m3u8.group(0).replace(r"\/", "/")

            # 4. Check if player_html embeds another iframe
            soup_player = BeautifulSoup(player_html, "html.parser")
            for ifr in soup_player.find_all("iframe"):
                isrc = ifr.get("src")
                if isrc:
                    isrc_full = urljoin(embed_url, isrc)
                    try:
                        r_sub = await client.get(isrc_full, headers={"Referer": embed_url})
                        sub_text = html_lib.unescape(r_sub.text)
                        m3u8_sub = re.search(r'https?://[^\s"\'<>]+(?:\.m3u8|\.mp4|\/hls\/[^\s"\'<>]+\.txt)[^\s"\'<>]*', sub_text)
                        if m3u8_sub:
                            return m3u8_sub.group(0).replace(r"\/", "/")
                    except Exception:
                        pass
        except Exception as e:
            print(f"[DooPlayHandler] error fetching embed {embed_url}: {e}")

        return None
