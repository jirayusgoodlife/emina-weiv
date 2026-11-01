import re
import json
from typing import Dict, Any, List, Optional
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler

class AlphaHenHandler(BaseSiteHandler):
    """
    Handler for Alpha-Hen (alpha-hen.com) using Ezme theme & Miru Player.
    Extracts hentai/anime series, episodes, and resolves qqstream/stream-aph HLS playlists (flower.txt).
    """
    name = "Alpha-Hen / Ezme"
    domains = [
        "alpha-hen.com",
    ]

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        if super().can_handle(url):
            return True
        if html and ("miru-player" in html or "EzmeAlphaHen" in html or "ez-episode-list" in html or "ez-watch-player" in html):
            return True
        return False

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        # 1. Title Extraction
        title = ""
        h1 = soup.find("h1")
        if h1:
            title = h1.get_text(strip=True)

        if not title:
            og_t = soup.find("meta", property="og:title")
            title = og_t["content"] if og_t and og_t.get("content") else (soup.title.string if soup.title else "")

        # Clean title
        clean_title = re.sub(r"\s*[-|–]\s*Alpha-Hen.*$", "", title, flags=re.I).strip()
        clean_title = re.sub(r"\s*ตอนที่\s*\d+.*$", "", clean_title, flags=re.I).strip()
        clean_title = re.sub(r"\s*TH\s*$", "", clean_title, flags=re.I).strip()
        clean_title = re.sub(r"\s*(?:ซับไทย|พากย์ไทย|Uncensored|อันเซ็นเซอร์).*$", "", clean_title, flags=re.I).strip()
        if not clean_title:
            clean_title = title or "Alpha-Hen Anime"

        # Slug
        slug = re.sub(r"[^a-zA-Z0-9]+", "-", clean_title.lower()).strip("-")
        if not slug:
            parsed = urlparse(url)
            slug = parsed.path.strip("/").split("/")[-1] or "alphahen-anime"

        # 2. Cover Image
        cover_url = ""
        # Look for the hero poster first
        hero_img = soup.select_one(".ez-hero-thumb img, .attachment-medium_large, img.wp-post-image")
        if hero_img:
            src = hero_img.get("src") or hero_img.get("data-src") or ""
            # Avoid ads
            if src and not any(ad in src for ad in ["banner", "ads", "logo"]):
                cover_url = urljoin(url, src)

        if not cover_url:
            og_img = soup.find("meta", property="og:image")
            if og_img and og_img.get("content"):
                cover_url = og_img["content"]

        # 3. Synopsis
        synopsis = ""
        syn_el = soup.select_one(".ez-synopsis, .entry-content")
        if syn_el:
            synopsis = syn_el.get_text(strip=True)
        if not synopsis:
            og_desc = soup.find("meta", property="og:description")
            if og_desc and og_desc.get("content"):
                synopsis = og_desc["content"]

        # 4. Genres & Tags
        genres = []
        for a in soup.select("a[href*='/category/'], a[href*='/tag/']"):
            g_text = a.get_text(strip=True)
            href = a.get("href", "")
            if g_text and not any(ad in href for ad in ["banner", "ads", "sponsor"]):
                # Clean up bilingual genres if present (e.g. "Hentai เฮ็นไต" -> "Hentai")
                clean_g = g_text.split(" ")[0].strip()
                if clean_g and clean_g not in genres and len(clean_g) > 1:
                    genres.append(clean_g)

        # 5. Rating, Year, Status
        hero_content = soup.select_one(".ez-hero-content")
        hero_text = hero_content.get_text(separator=" ", strip=True) if hero_content else html

        rating = "8.0"
        r_m = re.search(r"\b(\d+\.\d{1,2})\b", hero_text)
        if r_m:
            rating = r_m.group(1)

        year = ""
        y_a = soup.select_one("a[href*='/years/']")
        if y_a:
            year = y_a.get_text(strip=True)
        if not year:
            y_m = re.search(r"\b(19\d\d|20\d\d)\b", hero_text)
            if y_m:
                year = y_m.group(1)

        status = "จบแล้ว"
        if "จบแล้ว" in hero_text:
            status = "จบแล้ว"
        elif "กำลังฉาย" in hero_text:
            status = "กำลังฉาย"

        # 6. Episodes List
        episodes: List[Dict[str, Any]] = []
        seen_urls = set()

        # Find episode link elements
        ep_links = soup.select(".ez-episode-list a[href*='/watch/'], a[href*='/watch/']")
        for a in ep_links:
            ep_href = a.get("href", "")
            if not ep_href:
                continue
            full_ep_url = urljoin(url, ep_href)
            if full_ep_url in seen_urls:
                continue
            seen_urls.add(full_ep_url)

            # Ep title and number
            ep_title = a.get("title", "")
            y_b = a.select_one(".y-t-b")
            if y_b:
                y_b_text = y_b.get_text(strip=True)
                if not ep_title:
                    ep_title = y_b_text
                else:
                    if y_b_text not in ep_title:
                        ep_title = f"{ep_title} {y_b_text}"

            if not ep_title:
                ep_title = a.get_text(strip=True)

            # Extract episode number
            ep_num = 1.0
            num_m = re.search(r"(?:ตอนที่|EP\.?)\s*(\d+(?:\.\d+)?)", ep_title, re.I)
            if not num_m:
                num_m = re.search(r"-(\d+)$", ep_href.strip("/").split("/")[-1])
            if num_m:
                try:
                    ep_num = float(num_m.group(1))
                except ValueError:
                    ep_num = float(len(episodes) + 1)
            else:
                ep_num = float(len(episodes) + 1)

            # Episode thumbnail
            ep_thumb = ""
            ep_img = a.find("img")
            if ep_img:
                ep_thumb = ep_img.get("src") or ep_img.get("data-src") or ""
                if ep_thumb:
                    ep_thumb = urljoin(url, ep_thumb)
            if not ep_thumb:
                ep_thumb = cover_url

            episodes.append({
                "episode_number": ep_num,
                "title": ep_title or f"ตอนที่ {int(ep_num) if ep_num.is_integer() else ep_num}",
                "page_url": full_ep_url,
                "stream_url": "",
                "thumbnail_url": ep_thumb,
                "audio_type": "sub" if "ซับไทย" in (title + html) else "unknown",
                "id": f"{slug}-ep-{int(ep_num) if ep_num.is_integer() else ep_num}"
            })

        # Sort episodes by episode_number ascending
        episodes.sort(key=lambda x: x["episode_number"])

        # Deduplicate IDs if needed
        seen_ids = set()
        for idx, ep in enumerate(episodes):
            base_id = ep["id"]
            c = 1
            while ep["id"] in seen_ids:
                c += 1
                ep["id"] = f"{base_id}-{c}"
            seen_ids.add(ep["id"])

        is_movie = len(episodes) <= 1 and ("movie" in url.lower() or "the animation" in clean_title.lower())

        return {
            "slug": slug,
            "title": clean_title,
            "cover_url": cover_url,
            "backdrop_url": cover_url,
            "synopsis": synopsis,
            "genres": genres,
            "rating": rating,
            "status": f"{status} ({len(episodes)} ตอน)" if episodes else status,
            "year": year,
            "source_url": url,
            "is_movie": is_movie,
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
        """
        Resolves video stream for Alpha-Hen watch page.
        Workflow:
        1. Watch page -> <iframe> src (https://www.alpha-hen.com/watch_video/...)
        2. watch_video -> location.replace("https://qqstream.stream-aph.xyz/v/...")
        3. qqstream -> jwplayer sources -> file: "https://qqhls*.stream-aph.xyz/media/.../flower.txt"
        """
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://www.alpha-hen.com/",
        }

        try:
            # Look for watch_video iframe in the already loaded page
            iframe_srcs = []
            for ifr in soup.find_all("iframe"):
                src = ifr.get("src") or ifr.get("data-src")
                if src:
                    iframe_srcs.append(src)

            if not iframe_srcs:
                iframe_srcs = re.findall(r'<iframe[^>]+src=[\"\']([^\"\']+)[\"\']', html)

            if not iframe_srcs:
                iframe_srcs = re.findall(r'https?://(?:qqstream|stream-aph)[^\s\"\'<>]+', html)

            if not iframe_srcs:
                return None

            watch_video_url = iframe_srcs[0]

            # 2. Fetch watch_video
            r2 = await client.get(watch_video_url, headers={**headers, "Referer": page_url})
            if r2.status_code != 200:
                return None

            # Look for qqstream player URL
            loc_m = re.findall(r'location\.replace\([\"\']([^\"\']+)[\"\']\)', r2.text)
            if not loc_m:
                loc_m = re.findall(r'https?://(?:qqstream|stream-aph)[^\s\"\'<>]+', r2.text)

            if not loc_m:
                return None

            player_url = loc_m[0]

            # 3. Fetch player page
            r3 = await client.get(player_url, headers={**headers, "Referer": "https://www.alpha-hen.com/"})
            if r3.status_code != 200:
                return None

            # Extract stream playlist file
            file_m = re.findall(r'[\"\']file[\"\']\s*:\s*[\"\']([^\"\']+)[\"\']', r3.text)
            if file_m:
                return file_m[0]

            hls_m = re.findall(r'https?://[^\s\"\'<>]+\.(?:txt|m3u8|mp4)[^\s\"\'<>]*', r3.text)
            if hls_m:
                return hls_m[0]

        except Exception as e:
            pass

        return None
