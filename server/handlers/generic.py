import re
import json
import base64
import urllib.parse
from typing import Dict, Any, List, Optional
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler
from .animenani import decode_animenani_bootstrap

class GenericHandler(BaseSiteHandler):
    """
    Intelligent universal fallback handler capable of parsing metadata and streams
    from most anime and video streaming websites.
    """
    name = "Universal Generic Handler"
    domains = ["*"]

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        return True

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        # 1. Title
        og_title = soup.find("meta", property="og:title")
        title = og_title["content"] if og_title and og_title.get("content") else ""
        if not title and soup.title:
            title = soup.title.string or ""
        
        # Clean title from common branding
        title = re.sub(r"\s*[-|–]\s*(ดูอนิเมะ|Anime|พากย์ไทย|ซับไทย|ตอนล่าสุด|Anifume).*$", "", title, flags=re.IGNORECASE).strip()

        # 2. Cover
        cover_url = ""
        og_image = soup.find("meta", property="og:image") or soup.find("meta", attrs={"name": "twitter:image"})
        if og_image and og_image.get("content"):
            cover_url = og_image["content"]

        if not cover_url:
            # Try common poster/cover containers
            img_cand = soup.select_one(".post-content-img img, .content-row img, .poster img, .entry-thumbnail img, .thumb img, .anime-cover img, .featured-image img")
            if img_cand:
                cover_url = img_cand.get("src") or img_cand.get("data-src") or img_cand.get("data-lazy-src") or ""

        if not cover_url:
            img = soup.find("img", src=re.compile(r"(poster|cover|thumbnail)", re.I))
            if img and img.get("src"):
                cover_url = img["src"]

        if not cover_url:
            # Fallback to any content image
            for img in soup.find_all("img"):
                src = img.get("src") or img.get("data-src") or ""
                if src and not any(x in src.lower() for x in ["logo", "icon", "banner", "avatar", "button", "dm."]):
                    cover_url = src
                    break

        if cover_url and not cover_url.startswith("http"):
            cover_url = urljoin(url, cover_url)

        # 3. Synopsis
        synopsis = ""
        og_desc = soup.find("meta", property="og:description") or soup.find("meta", attrs={"name": "description"})
        if og_desc and og_desc.get("content"):
            synopsis = og_desc["content"].strip()
        
        if not synopsis:
            content_des = soup.select_one(".content-des, .entry-content, .synopsis, .description, .anime-info")
            if content_des:
                synopsis = "\n\n".join([p.get_text(strip=True) for p in content_des.find_all("p") if p.get_text(strip=True)])

        # 4. Episodes detection with Sub/Dub categorization
        sub_episodes = []
        dub_episodes = []
        other_episodes = []
        seen_urls = set()

        is_movie_page = bool(
            re.search(r"/(?:movies?|films?)/", url, re.I)
            or re.search(r"(?:เดอะมูฟวี่|ภาพยนตร์|the\s*movie|\bmovie\b|มูฟวี่|ตอนเดียวจบ|ตอนเดียว)", title, re.I)
            or soup.find(class_="dooplay_player_option", attrs={"data-type": "movie"})
            or soup.find(attrs={"data-type": "movie"})
        )

        # Check episode-specific link containers first, then all links
        ep_links = soup.select(".eplink a, .eplink-wrap a, .episode-list a, .episodes a, .episodios a, .list-episodes a, ul.episodes li a, .server-ep a, .les-content a, .content-ep a")
        if not ep_links:
            ep_links = soup.find_all("a", href=True)

        for a in ep_links:
            href = a.get("href", "").strip()
            if not href or href == "#":
                continue
            text = a.get_text(strip=True)
            full_url = urljoin(url, href)
            combined = f"{text} {href}"

            # Match patterns like: ep-1, ep1, ตอนที่ 1, episode-1, /watch/
            ep_match = re.search(r"(?:ep(?:isode)?|ตอน(?:ที่)?)[-_.\s]*(\d+(?:\.\d+)?)", combined, re.IGNORECASE)
            if ep_match and full_url not in seen_urls:
                try:
                    ep_num = float(ep_match.group(1))
                    seen_urls.add(full_url)
                    ep_title = text if len(text) > 2 else f"ตอนที่ {int(ep_num) if ep_num.is_integer() else ep_num}"

                    is_dub = bool(re.search(r"พากย์ไทย|พากย์|dub", combined, re.I))
                    is_sub = bool(re.search(r"ซับไทย|ซับ|sub", combined, re.I))

                    audio_tag = "dub" if is_dub and not is_sub else ("sub" if is_sub else "unknown")

                    ep_obj = {
                        "episode_number": ep_num,
                        "title": ep_title,
                        "page_url": full_url,
                        "stream_url": "",
                        "audio_type": audio_tag
                    }

                    if audio_tag == "dub":
                        dub_episodes.append(ep_obj)
                    elif audio_tag == "sub":
                        sub_episodes.append(ep_obj)
                    else:
                        other_episodes.append(ep_obj)
                except Exception:
                    pass

        # If no episode links found, check for single-episode movie / direct video player options
        if not (sub_episodes or dub_episodes or other_episodes):
            opts = soup.find_all(class_="dooplay_player_option") or soup.find_all(attrs={"data-post": True})
            has_player = bool(
                opts
                or soup.find("video")
                or soup.find("iframe", src=re.compile(r"embed|player|video|stream|nya", re.I))
                or re.search(r"https?://[^\s\"\'<>]+\.(?:m3u8|mp4)", html)
                or is_movie_page
            )

            if has_player or is_movie_page:
                is_movie_page = True
                if opts:
                    for opt in opts:
                        nume = str(opt.get("data-nume", "1"))
                        opt_text = opt.get_text(strip=True)
                        is_dub = bool(re.search(r"พากย์ไทย|พากย์|dub", opt_text, re.I))
                        is_sub = bool(re.search(r"ซับไทย|ซับ|sub", opt_text, re.I))

                        audio_tag = "dub" if is_dub and not is_sub else ("sub" if is_sub and not is_dub else "unknown")

                        opt_label = "เดอะมูฟวี่"
                        if audio_tag == "dub":
                            opt_label += " (พากย์ไทย)"
                        elif audio_tag == "sub":
                            opt_label += " (ซับไทย)"
                        elif opt_text and len(opt_text) < 30:
                            opt_label += f" ({opt_text})"

                        ep_obj = {
                            "episode_number": 1.0,
                            "title": opt_label,
                            "page_url": f"{url}?source={nume}",
                            "stream_url": "",
                            "audio_type": audio_tag
                        }

                        if audio_tag == "dub":
                            dub_episodes.append(ep_obj)
                        elif audio_tag == "sub":
                            sub_episodes.append(ep_obj)
                        else:
                            other_episodes.append(ep_obj)

                if not (sub_episodes or dub_episodes or other_episodes):
                    is_dub = bool(re.search(r"พากย์ไทย|พากย์|dub", title, re.I))
                    is_sub = bool(re.search(r"ซับไทย|ซับ|sub", title, re.I))
                    audio_tag = "dub" if is_dub and not is_sub else ("sub" if is_sub else "unknown")
                    ep_title = "เดอะมูฟวี่" + (" (พากย์ไทย)" if audio_tag == "dub" else (" (ซับไทย)" if audio_tag == "sub" else ""))

                    ep_obj = {
                        "episode_number": 1.0,
                        "title": ep_title,
                        "page_url": url,
                        "stream_url": "",
                        "audio_type": audio_tag
                    }
                    if audio_tag == "dub":
                        dub_episodes.append(ep_obj)
                    elif audio_tag == "sub":
                        sub_episodes.append(ep_obj)
                    else:
                        other_episodes.append(ep_obj)

        sub_episodes.sort(key=lambda x: x["episode_number"])
        dub_episodes.sort(key=lambda x: x["episode_number"])
        other_episodes.sort(key=lambda x: x["episode_number"])

        base_clean_title = re.sub(r"\s*(?:ตอนที่|ep|episode|\b\d+[-]\d+\b).*$", "", title, flags=re.I).strip()
        base_clean_title = re.sub(r"\s*(?:และ\s*)?(?:ซับไทย|พากย์ไทย|จบแล้ว)\s*$", "", base_clean_title, flags=re.I).strip()
        base_clean_title = re.sub(r"\s*(?:และ\s*)?(?:ซับไทย|พากย์ไทย)\s*$", "", base_clean_title, flags=re.I).strip()
        if not base_clean_title:
            base_clean_title = title or "ไม่ทราบชื่อเรื่อง"

        parsed_u = urlparse(url)
        path_slug = [p for p in parsed_u.path.strip("/").split("/") if p and p not in ("anime", "watch", "series", "video", "movies", "movie")]
        if path_slug:
            base_slug = re.sub(r"[^a-zA-Z0-9]+", "-", path_slug[-1].lower()).strip("-")
        else:
            base_slug = re.sub(r"[^a-zA-Z0-9]+", "-", base_clean_title.lower()).strip("-")
        if not base_slug:
            base_slug = f"anime-{abs(hash(url)) % 100000}"

        def make_collection(t_title: str, t_slug: str, t_episodes: List[Dict[str, Any]], audio_label: Optional[str] = None):
            genres_list = ["Anime"]
            if is_movie_page and "เดอะมูฟวี่" not in genres_list and "Movie" not in genres_list:
                genres_list.append("เดอะมูฟวี่")
            if audio_label:
                genres_list.append(audio_label)
            
            status_text = f"{len(t_episodes)} ตอน" if t_episodes else "ไม่ระบุ"
            if is_movie_page:
                status_text = "เดอะมูฟวี่ (ตอนเดียวจบ)"

            return {
                "slug": t_slug,
                "title": t_title,
                "cover_url": cover_url,
                "backdrop_url": cover_url,
                "synopsis": synopsis or "ไม่มีเรื่องย่อ",
                "genres": genres_list,
                "rating": "8.0",
                "status": status_text,
                "year": "2024",
                "source_url": url,
                "is_movie": is_movie_page,
                "episodes": t_episodes
            }

        if sub_episodes and dub_episodes:
            sub_coll = make_collection(f"{base_clean_title} (ซับไทย)", f"{base_slug}-sub", sub_episodes, "ซับไทย")
            dub_coll = make_collection(f"{base_clean_title} (พากย์ไทย)", f"{base_slug}-dub", dub_episodes, "พากย์ไทย")
            sub_clean = dict(sub_coll)
            dub_clean = dict(dub_coll)
            sub_clean.pop("split_collections", None)
            dub_clean.pop("split_collections", None)
            sub_coll["split_collections"] = [sub_clean, dub_clean]
            return sub_coll

        if dub_episodes and not sub_episodes:
            dub_title = f"{base_clean_title} (พากย์ไทย)" if "พากย์ไทย" not in base_clean_title else base_clean_title
            return make_collection(dub_title, f"{base_slug}-dub", dub_episodes + other_episodes, "พากย์ไทย")

        all_eps = sub_episodes + other_episodes
        if not all_eps and dub_episodes:
            all_eps = dub_episodes
        sub_title = base_clean_title
        if sub_episodes and "ซับไทย" not in sub_title and "พากย์ไทย" not in sub_title:
            sub_title = f"{base_clean_title} (ซับไทย)"

        return make_collection(sub_title, base_slug, all_eps, "ซับไทย" if sub_episodes else None)

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
                r = await client.get(page_url)
                html = r.text
                soup = BeautifulSoup(html, "html.parser")
            except Exception:
                return None

        # 1. Check animenani bootstrap
        manifest = decode_animenani_bootstrap(html)
        if manifest:
            return manifest

        # 2. Check JWPlayer setup
        jw_files = re.findall(r'[\"\']file[\"\']\s*:\s*[\"\']([^\"\']+\.(?:mp4|m3u8)[^\"\']*)[\"\']', html)
        if jw_files:
            return jw_files[0]

        # 3. Direct video or source tags
        for video in soup.find_all("video"):
            if video.get("src"):
                return urljoin(page_url, video["src"])
            for source in video.find_all("source"):
                if source.get("src"):
                    return urljoin(page_url, source["src"])

        # 4. Check iframes (video players, embed hosts)
        for iframe in soup.find_all("iframe"):
            isrc = iframe.get("src") or iframe.get("data-src") or iframe.get("data-lazy-src")
            if isrc and ("player" in isrc or "embed" in isrc or "video" in isrc or "nya" in isrc or "rukoluo" in isrc):
                iframe_url = urljoin(page_url, isrc)
                try:
                    iframe_resp = await client.get(iframe_url, headers={"Referer": page_url})
                    iframe_text = iframe_resp.text.replace(r"\/", "/")
                    
                    manifest = decode_animenani_bootstrap(iframe_text)
                    if manifest:
                        return manifest
                        
                    files = re.findall(r'[\"\']file[\"\']\s*:\s*[\"\']([^\"\']+)[\"\']', iframe_text)
                    if files:
                        for f in files:
                            if "mp4" in f or "m3u8" in f:
                                return f
                        return files[0]

                    m3u8_sub = re.search(r"https?://[^\s\"<>]+(?:\.m3u8|\.mp4)[^\s\"<>]*", iframe_text)
                    if m3u8_sub:
                        return m3u8_sub.group(0)
                except Exception:
                    pass

        # 5. Search m3u8 or mp4 in inline scripts or full text
        m3u8_match = re.search(r"https?://[^\s\"\'<>]+\.(?:m3u8|mp4)[^\s\"\'<>]*", html)
        if m3u8_match:
            return m3u8_match.group(0)

        return None
