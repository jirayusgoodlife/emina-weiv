import re
import json
from typing import Dict, Any, List, Optional
from urllib.parse import urljoin, urlparse, parse_qs
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler

class HalimHandler(BaseSiteHandler):
    """
    Handler for HalimThemes / 123-HD series and movies (e.g., 123-hdc.com, 123-hd.com).
    Resolves Halim AJAX player and 24playerhd HLS streams.
    """
    name = "Halim / 123-HD"
    domains = [
        "123-hdc.com",
        "123-hd.com",
        "123-hda.com",
        "123-hd.net"
    ]

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        if super().can_handle(url):
            return True
        if html and ("halim_cfg" in html or "halim-player-wrapper" in html or "halim-ajax" in html):
            return True
        return False

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        # 1. Title Extraction
        title = ""
        # Check halim_cfg
        cfg_m = re.search(r'var\s+halim_cfg\s*=\s*({[^;]+});', html)
        if cfg_m:
            try:
                cfg_data = json.loads(cfg_m.group(1))
                title = cfg_data.get("post_title", "")
            except Exception:
                m_t = re.search(r'[\"\']post_title[\"\']\s*:\s*[\"\']([^\"\']+)[\"\']', cfg_m.group(1))
                if m_t:
                    title = m_t.group(1)

        if not title:
            h1 = soup.find("h1", class_="entry-title") or soup.find("h1")
            title = h1.get_text(strip=True) if h1 else ""

        if not title:
            og_t = soup.find("meta", property="og:title")
            title = og_t["content"] if og_t and og_t.get("content") else (soup.title.string if soup.title else "")

        # Clean title
        clean_title = re.sub(r"\s*[-|–]\s*(?:ดูหนัง|ดูซีรี่ย์|123-HD|123-HDC).*$", "", title, flags=re.I).strip()
        clean_title = re.sub(r"\s*\(\d{4}\)", "", clean_title).strip()
        clean_title = re.sub(r"\s*(?:และ\s*)?(?:ซับไทย|พากย์ไทย|จบแล้ว)\s*$", "", clean_title, flags=re.I).strip()
        clean_title = re.sub(r"\s*EP\s*\d+.*$", "", clean_title, flags=re.I).strip()
        clean_title = re.sub(r"\s*ตอนที่\s*\d+.*$", "", clean_title, flags=re.I).strip()
        if not clean_title:
            clean_title = title or "Series / Movie"

        # 2. Cover Extraction
        cover_url = ""
        thumb_img = soup.select_one(".movie-thumb img, .movie-poster img, .entry-thumbnail img, .post-thumbnail img")
        if thumb_img:
            src = thumb_img.get("src") or thumb_img.get("data-src") or ""
            if src:
                cover_url = urljoin(url, src)

        if not cover_url:
            og_img = soup.find("meta", property="og:image")
            if og_img and og_img.get("content"):
                cover_url = urljoin(url, og_img["content"])

        # 3. Synopsis
        synopsis = ""
        entry_content = soup.select_one(".entry-content, .film-description, .content-desc")
        if entry_content:
            p_list = [p.get_text(strip=True) for p in entry_content.find_all("p") if p.get_text(strip=True)]
            synopsis = "\n\n".join(p_list)
        if not synopsis:
            og_desc = soup.find("meta", property="og:description") or soup.find("meta", attrs={"name": "description"})
            if og_desc and og_desc.get("content"):
                synopsis = og_desc["content"].strip()

        # 4. Episodes Detection
        episodes = []
        seen = set()

        # Extract base slug from url path
        parsed_url = urlparse(url)
        path_name = parsed_url.path.strip("/").split("/")[-1]
        base_series_slug = re.sub(r"-ep-\d+$", "", path_name, flags=re.I).lower()

        # Find episode links: e.g. "VISIONQUEST EP 1", "VISIONQUEST EP 2"
        ep_dict = {}
        for a in soup.find_all("a", href=True):
            href = a["href"].strip()
            if not href or href == "#" or "/tag/" in href or "/az-list/" in href:
                continue
            text = a.get_text(strip=True)
            combined = f"{text} {href}"

            ep_m = re.search(r"(?:ep(?:isode)?|ตอน(?:ที่)?)[-_.\s]*(\d+(?:\.\d+)?)", combined, re.I)
            if ep_m:
                full_url = urljoin(url, href)
                parsed_href = urlparse(full_url)
                href_slug = parsed_href.path.strip("/").split("/")[-1].lower()

                if base_series_slug in href_slug or "ep-" in href_slug or ep_m:
                    ep_num = float(ep_m.group(1))
                    is_dub = bool(re.search(r"พากย์ไทย|พากย์|dub", combined, re.I))
                    is_sub = bool(re.search(r"ซับไทย|ซับ|sub", combined, re.I))
                    audio_tag = "dub" if is_dub and not is_sub else ("sub" if is_sub else "unknown")

                    is_nav_text = any(bad in text for bad in ["ถัดไป", "ก่อนหน้า", "ตอนแรก", "ตอนจบ", ">", "<"])
                    better_title = text if (not is_nav_text and len(text) > 3) else f"ตอนที่ {int(ep_num) if ep_num.is_integer() else ep_num}"

                    if ep_num not in ep_dict or (is_nav_text and ep_dict[ep_num]["title"] != better_title):
                        ep_dict[ep_num] = {
                            "episode_number": ep_num,
                            "title": better_title,
                            "page_url": full_url,
                            "stream_url": "",
                            "audio_type": audio_tag
                        }
                    elif not is_nav_text and any(b in ep_dict[ep_num]["title"] for b in ["ถัดไป", "ก่อนหน้า", ">", "<"]):
                        ep_dict[ep_num]["title"] = better_title
                        ep_dict[ep_num]["page_url"] = full_url

        episodes = list(ep_dict.values())

        # If only 1 or no episode links found, but page is movie / single episode
        if not episodes:
            episodes.append({
                "episode_number": 1.0,
                "title": clean_title,
                "page_url": url,
                "stream_url": "",
                "audio_type": "unknown"
            })

        episodes.sort(key=lambda x: x["episode_number"])

        slug_raw = re.sub(r"[^a-zA-Z0-9]+", "-", clean_title.lower()).strip("-")
        slug = f"{slug_raw}-{abs(hash(url)) % 100000}" if slug_raw else f"halim-{abs(hash(url)) % 100000}"

        return {
            "slug": slug,
            "title": clean_title,
            "cover_url": cover_url,
            "backdrop_url": cover_url,
            "synopsis": synopsis or "ไม่มีเรื่องย่อ",
            "genres": ["Action", "Series", "Movie"],
            "rating": "8.5",
            "status": f"{len(episodes)} ตอน" if len(episodes) > 1 else "ตอนเดียวจบ",
            "year": "2026",
            "source_url": url,
            "is_movie": len(episodes) <= 1,
            "episodes": episodes
        }

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
                r = await client.get(page_url, headers={"Referer": page_url})
                html = r.text
                soup = BeautifulSoup(html, "html.parser")
            except Exception as e:
                print(f"[HalimHandler] error fetching page {page_url}: {e}")
                return None

        # 1. Extract nonce from ajax_player or ajax_var
        nonce_m = re.search(r'var\s+ajax_player\s*=\s*{[^}]+[\"\']nonce[\"\']\s*:\s*[\"\']([^\"\']+)[\"\']', html)
        if not nonce_m:
            nonce_m = re.search(r'[\"\']nonce[\"\']\s*:\s*[\"\']([^\"\']+)[\"\']', html)
        nonce = nonce_m.group(1) if nonce_m else ""

        # 2. Extract post_id, episode, server
        post_m = re.search(r'[\"\']post_id[\"\']\s*:\s*(\d+)', html) or re.search(r'data-post-id=[\"\'](\d+)[\"\']', html)
        post_id = int(post_m.group(1)) if post_m else 0

        ep_m = re.search(r'[\"\']episode[\"\']\s*:\s*(\d+)', html) or re.search(r'data-episode=[\"\'](\d+)[\"\']', html)
        episode = int(ep_m.group(1)) if ep_m else 0

        srv_m = re.search(r'[\"\']server[\"\']\s*:\s*(\d+)', html) or re.search(r'data-server=[\"\'](\d+)[\"\']', html)
        server = int(srv_m.group(1)) if srv_m else 1

        if not post_id:
            return None

        parsed = urlparse(page_url)
        origin = f"{parsed.scheme}://{parsed.netloc}"
        api_url = f"{origin}/api/get.php"

        payload = {
            "action": "halim_ajax_player",
            "nonce": nonce,
            "episode": str(episode),
            "server": str(server),
            "postid": str(post_id)
        }

        try:
            r_api = await client.post(
                api_url,
                data=payload,
                headers={
                    "Referer": page_url,
                    "X-Requested-With": "XMLHttpRequest",
                    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"
                }
            )
            if r_api.status_code == 200:
                player_html = r_api.text

                # Check 24playerhd.com
                id_m = re.search(r'24playerhd\.com/[^\"\'<>]*[?&]id=([a-zA-Z0-9]+)', player_html)
                if id_m:
                    pid = id_m.group(1)
                    return f"https://main.24playerhd.com/newplaylist/{pid}/{pid}.m3u8"

                # Check if iframe embeds another player
                ifr_m = re.search(r'src=[\"\']([^\"\']+)[\"\']', player_html)
                if ifr_m:
                    sub_player_url = urljoin(page_url, ifr_m.group(1))
                    try:
                        r_sub = await client.get(sub_player_url, headers={"Referer": page_url})
                        sub_html = r_sub.text
                        m_sub = re.search(r'https?://[^\s\"\'<>]+\.(?:m3u8|mp4)[^\s\"\'<>]*', sub_html)
                        if m_sub:
                            return m_sub.group(0)
                    except Exception:
                        pass

                # Direct m3u8 or mp4 in response
                m3u8 = re.search(r'https?://[^\s\"\'<>]+\.(?:m3u8|mp4)[^\s\"\'<>]*', player_html)
                if m3u8:
                    return m3u8.group(0)

        except Exception as e:
            print(f"[HalimHandler] error calling {api_url}: {e}")

        # Also check direct 24playerhd inside the main page html if iframe is present
        id_direct = re.search(r'24playerhd\.com/[^\"\'<>]*[?&]id=([a-zA-Z0-9]+)', html)
        if id_direct:
            pid = id_direct.group(1)
            return f"https://main.24playerhd.com/newplaylist/{pid}/{pid}.m3u8"

        return None
