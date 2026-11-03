import re
import time
from typing import Dict, Any, List, Optional, Tuple
from urllib.parse import urlparse, parse_qs
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler

class WowDramaHandler(BaseSiteHandler):
    """
    Dedicated site handler for wow-drama.com and Miru Player engine.
    Supports multi-audio tab switching (ซับไทย / พากย์ไทย), dynamic episode grid parsing,
    and resolves direct playable HLS streams (.m3u8) from ok-hd / getplay-cdn player APIs.
    """
    name = "Wow-Drama"
    domains = [
        "wow-drama.com",
        "ok-hd.com",
        "getplay-cdn.com",
        "ok-720.com",
    ]

    HEADERS = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "th-TH,th;q=0.9,en-US;q=0.8,en;q=0.7",
    }

    _nonce_cache: Dict[str, Tuple[str, float]] = {}

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        if super().can_handle(url):
            return True
        if html and ("miruNonce" in html or "miru-tab-btn" in html or "miru_get_api_player_url" in html or "wow-drama.com" in html):
            return True
        return False

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        # Cache nonce if present in page
        nonce_m = re.search(r'var miruNonce\s*=\s*["\']([^"\']+)["\']', html)
        if nonce_m:
            self._nonce_cache[url.split('?')[0]] = (nonce_m.group(1), time.time())

        # Title extraction
        title_el = soup.find("h1", class_="title-name") or soup.find("h1")
        raw_title = title_el.get_text(strip=True) if title_el else ""
        if not raw_title:
            og_title = soup.find("meta", property="og:title")
            raw_title = og_title.get("content", "") if og_title else ""
        if not raw_title and soup.title:
            raw_title = soup.title.string or ""

        # Clean title: remove prefixes like "ดูซีรี่ส์", "ดูซีรี่ย์จีน" and suffixes like "ซับไทย | พากย์ไทย"
        clean_title = re.sub(r'^(?:ดูซีรี่ส์จีน|ดูซีรี่ย์จีน|ดูซีรี่ส์เกาหลี|ดูซีรี่ย์เกาหลี|ดูซีรี่ส์|ดูซีรี่ย์|ดูอนิเมะ)\s*', '', raw_title, flags=re.I)
        clean_title = re.sub(r'\s*(?:ซับไทย|พากย์ไทย|\s*\|\s*)+\s*$', '', clean_title, flags=re.I).strip()
        clean_title = re.sub(r'\s*\((?:ครบทุกตอน|จบแล้ว|จบ)\)\s*$', '', clean_title, flags=re.I).strip()
        if not clean_title:
            clean_title = raw_title or "ซีรีส์ออนไลน์"

        # Poster & backdrop
        og_img = soup.find("meta", property="og:image")
        cover_img = soup.select_one(".poster img, .entry-thumbnail img, .post-content-img img")
        cover_url = og_img.get("content") if og_img else (cover_img.get("src") if cover_img else "")

        # Synopsis
        syn_el = soup.select_one(".entry-content p, .synopsis, meta[property='og:description']")
        synopsis = syn_el.get("content") if syn_el and syn_el.get("content") else (syn_el.get_text(strip=True) if syn_el else "ไม่มีเรื่องย่อ")

        # Year & genres
        year_m = re.search(r'\((\d{4})\)', raw_title) or re.search(r'-(\d{4})/?$', url)
        year = year_m.group(1) if year_m else "2026"

        genres = ["ซีรี่ย์จีน", "Drama"]
        cat_links = soup.select(".genres a, .categories a, a[rel='category tag']")
        for c in cat_links:
            g_name = c.get_text(strip=True)
            if g_name and g_name not in genres and len(g_name) < 25:
                genres.append(g_name)

        # Base slug
        slug_clean = re.sub(r'[^a-zA-Z0-9]+', '-', clean_title.lower()).strip('-')
        if not slug_clean:
            path_part = urlparse(url).path.strip('/').split('/')[-1]
            slug_clean = path_part or "wow-drama"
        base_slug = f"wow-{slug_clean}"

        # Parse episodes from grid container
        def parse_episodes_from_grid(grid_el) -> List[Dict[str, Any]]:
            eps = []
            if not grid_el:
                return eps
            ep_btns = grid_el.select(".miru-ep-btn")
            for i, btn in enumerate(ep_btns, 1):
                ep_id = btn.get("data-ep-id")
                if not ep_id:
                    continue
                title_attr = btn.get("title", "")
                ep_title_span = btn.select_one(".miru-ep-title")
                raw_ep_text = ep_title_span.get_text(strip=True) if ep_title_span else ""

                num_m = re.search(r'(?:ep|ตอนที่)\s*(\d+(?:\.\d+)?)', raw_ep_text, re.I) or re.search(r'(?:ep|ตอนที่)\s*(\d+(?:\.\d+)?)', title_attr, re.I)
                ep_num = float(num_m.group(1)) if num_m else float(i)
                display_title = raw_ep_text or f"EP {int(ep_num)}"
                ep_page_url = f"{url.rstrip('/')}/?ep_id={ep_id}"

                eps.append({
                    "episode_number": ep_num,
                    "title": display_title,
                    "page_url": ep_page_url,
                    "stream_url": "",
                    "thumbnail_url": cover_url,
                    "duration": "45:00"
                })

            eps.sort(key=lambda x: x["episode_number"])
            return eps

        def build_collection(col_title: str, col_slug: str, col_eps: List[Dict[str, Any]], audio_tag: str):
            c_genres = list(genres)
            if audio_tag and audio_tag not in c_genres:
                c_genres.append(audio_tag)
            return {
                "slug": col_slug,
                "title": col_title,
                "cover_url": cover_url,
                "backdrop_url": cover_url,
                "synopsis": synopsis,
                "genres": c_genres,
                "rating": "8.8",
                "status": f"{len(col_eps)} ตอน (จบแล้ว)" if ("จบ" in raw_title or any("ตอนจบ" in ep["title"] for ep in col_eps)) else f"{len(col_eps)} ตอน",
                "year": year,
                "source_url": url,
                "is_movie": False,
                "episodes": col_eps
            }

        tabs = soup.select(".miru-group-tabs .miru-tab-btn")
        collections = []
        for i, t in enumerate(tabs):
            tab_name = t.get_text(strip=True)
            target = t.get("data-target")
            grid = soup.find(id=target) if target else None
            tab_eps = parse_episodes_from_grid(grid)
            if not tab_eps:
                continue

            is_dub = "พากย์" in tab_name
            is_sub = "ซับ" in tab_name
            if is_dub:
                c_title = f"{clean_title} (พากย์ไทย)"
                c_slug = f"{base_slug}-dub"
                audio_tag = "พากย์ไทย"
            elif is_sub:
                c_title = f"{clean_title} (ซับไทย)"
                c_slug = f"{base_slug}-sub"
                audio_tag = "ซับไทย"
            else:
                c_title = f"{clean_title} ({tab_name})"
                c_slug = f"{base_slug}-tab-{i+1}"
                audio_tag = tab_name

            collections.append(build_collection(c_title, c_slug, tab_eps, audio_tag))

        if len(collections) >= 2:
            main_col = dict(collections[0])
            main_col["split_collections"] = [dict(c) for c in collections]
            return main_col
        elif len(collections) == 1:
            return collections[0]

        # Fallback if no tabs found
        fallback_grid = soup.select_one(".miru-ep-grid") or soup
        fallback_eps = parse_episodes_from_grid(fallback_grid)
        if fallback_eps:
            return build_collection(clean_title, base_slug, fallback_eps, "ซับไทย")

        return None

    async def _resolve_player_url(self, player_url: str, client: httpx.AsyncClient, parent_domain: str = "wow-drama.com") -> Optional[str]:
        md5 = player_url.strip("/").split("/")[-1]
        
        # 1. OK-HD Player (HD Server)
        if "ok-hd.com" in player_url or "ok-720" in player_url:
            try:
                r_token = await client.post(
                    "https://ok-hd.com/api/tokenplay",
                    headers={
                        "Referer": player_url,
                        "Origin": "https://ok-hd.com",
                        "X-Requested-With": "XMLHttpRequest",
                        "User-Agent": self.HEADERS["User-Agent"]
                    },
                    json={"md5": md5, "parent": parent_domain}
                )
                if r_token.status_code == 200:
                    td = r_token.json()
                    if "token" in td and "stream_id" in td:
                        stream_domain = "https://test1.ok-720.com"
                        try:
                            r_p = await client.get(
                                player_url,
                                headers={"Referer": f"https://{parent_domain}/", "User-Agent": self.HEADERS["User-Agent"]}
                            )
                            m_sd = re.search(r'STREAM_DOMAIN\s*=\s*["\']([^"\']+)["\']', r_p.text)
                            if m_sd:
                                stream_domain = m_sd.group(1).rstrip("/")
                        except Exception:
                            pass
                        return f"{stream_domain}/api/stream/{td['stream_id']}/playerlist.m3u8?token={td['token']}&expires={td['expires']}&parent={parent_domain}&sid={td['session_id']}"
            except Exception as e:
                print(f"[WowDramaHandler] Error resolving ok-hd token: {e}")

        # 2. GetPlay CDN Player (Main Server)
        elif "getplay-cdn.com" in player_url:
            try:
                r_token = await client.post(
                    "https://getplay-cdn.com/api/tokenplay",
                    headers={
                        "Referer": player_url,
                        "Origin": "https://getplay-cdn.com",
                        "X-Requested-With": "XMLHttpRequest",
                        "User-Agent": self.HEADERS["User-Agent"]
                    },
                    json={"md5": md5, "parent": parent_domain}
                )
                if r_token.status_code == 200:
                    td = r_token.json()
                    if "token" in td and "stream_id" in td:
                        return f"https://getplay-cdn.com/api/stream/{td['stream_id']}/index.m3u8?token={td['token']}&expires={td['expires']}&parent={parent_domain}&sid={td['session_id']}"
            except Exception as e:
                print(f"[WowDramaHandler] Error resolving getplay token: {e}")

        # 3. Direct video tag or regex fallback
        try:
            r_page = await client.get(
                player_url,
                headers={"Referer": f"https://{parent_domain}/", "User-Agent": self.HEADERS["User-Agent"]}
            )
            if r_page.status_code == 200:
                p_html = r_page.text
                m3u8 = re.search(r'https?://[^\s"\'<>]+\.m3u8[^\s"\'<>]*', p_html)
                if m3u8:
                    return m3u8.group(0)
                mp4 = re.search(r'https?://[^\s"\'<>]+\.mp4[^\s"\'<>]*', p_html)
                if mp4:
                    return mp4.group(0)
        except Exception:
            pass

        return None

    async def resolve_stream(
        self,
        page_url: str,
        html: str,
        soup: BeautifulSoup,
        client: httpx.AsyncClient,
        settings: Optional[Dict[str, str]] = None
    ) -> Optional[str]:
        # Fast path if URL is already an embed player URL
        if any(d in page_url for d in ["ok-hd.com", "getplay-cdn.com"]):
            return await self._resolve_player_url(page_url, client)

        # Parse ep_id from query params or URL
        parsed = urlparse(page_url)
        params = parse_qs(parsed.query)
        ep_id = params.get("ep_id", [None])[0]
        if not ep_id:
            m = re.search(r'ep_id=(\d+)', page_url)
            if m:
                ep_id = m.group(1)

        base_url = page_url.split("?")[0]

        # Retrieve nonce
        cached = self._nonce_cache.get(base_url)
        nonce = None
        if cached and (time.time() - cached[1] < 1800):
            nonce = cached[0]
        elif html:
            m_n = re.search(r'var miruNonce\s*=\s*["\']([^"\']+)["\']', html)
            if m_n:
                nonce = m_n.group(1)
                self._nonce_cache[base_url] = (nonce, time.time())

        if not nonce:
            try:
                r_page = await client.get(base_url, headers=self.HEADERS)
                m_n = re.search(r'var miruNonce\s*=\s*["\']([^"\']+)["\']', r_page.text)
                if m_n:
                    nonce = m_n.group(1)
                    self._nonce_cache[base_url] = (nonce, time.time())
                if not ep_id:
                    m_cur = re.search(r'var currentEpId\s*=\s*["\'](\d+)["\']', r_page.text)
                    if m_cur:
                        ep_id = m_cur.group(1)
            except Exception as e:
                print(f"[WowDramaHandler] Error fetching base drama page {base_url}: {e}")

        if not nonce or not ep_id:
            return None

        # Try server 1 (HD Server / OK-HD) first, then server 0 (Main Server / GetPlay)
        for s_idx in [1, 0]:
            try:
                ajax_resp = await client.post(
                    "https://wow-drama.com/wp-admin/admin-ajax.php",
                    headers={
                        "Referer": base_url,
                        "X-Requested-With": "XMLHttpRequest",
                        "User-Agent": self.HEADERS["User-Agent"]
                    },
                    data={
                        "action": "miru_get_api_player_url",
                        "ep_id": ep_id,
                        "server_idx": str(s_idx),
                        "nonce": nonce
                    }
                )
                if ajax_resp.status_code == 200:
                    data = ajax_resp.json()
                    if data.get("success") and data.get("data", {}).get("url"):
                        stream = await self._resolve_player_url(data["data"]["url"], client, parent_domain="wow-drama.com")
                        if stream:
                            return stream
            except Exception as e:
                print(f"[WowDramaHandler] Error querying server {s_idx} for ep {ep_id}: {e}")

        return None
