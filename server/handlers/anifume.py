import re
from typing import Dict, Any, List, Optional
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler

class AnifumeHandler(BaseSiteHandler):
    name = "Anifume"
    domains = ["anifume.com"]

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        # 1. Title Extraction
        title_tag = soup.find("h1", class_="post-title") or soup.find("h1")
        raw_title = title_tag.get_text(strip=True) if title_tag else ""
        if not raw_title and soup.title:
            raw_title = soup.title.get_text(strip=True)
            raw_title = re.sub(r"\s*[-|–]\s*Anifume.*$", "", raw_title, flags=re.I).strip()

        # Clean title: Kaifuku Jutsushi no Yarinaoshi การล้างแค้นของผู้กล้าสายฮีล ตอนที่ 1-12 ซับไทย (UNCEN 18+) [จบ]
        clean_title = re.sub(r"\s*ตอนที่\s*\d+[-–]\d+.*$", "", raw_title, flags=re.I).strip()
        clean_title = re.sub(r"\s*ตอนที่\s*\d+.*$", "", clean_title, flags=re.I).strip()
        clean_title = re.sub(r"\s*(?:\(UNCEN(?:\s*\d+\+)?\)|\bUNCEN\b|\[จบ\]|\bจบแล้ว\b)", "", clean_title, flags=re.I).strip()
        clean_title = re.sub(r"\s*(?:และ\s*)?(?:ซับไทย|พากย์ไทย)\s*$", "", clean_title, flags=re.I).strip()
        if not clean_title:
            clean_title = raw_title or "Anifume Anime"

        # 2. Cover Extraction
        cover_url = ""
        img_tag = soup.select_one(".post-content-img img, .content-row img, .content img")
        if img_tag:
            src = img_tag.get("src") or img_tag.get("data-src") or ""
            if src:
                cover_url = urljoin(url, src)

        if not cover_url:
            for img in soup.find_all("img"):
                src = img.get("src") or img.get("data-src") or ""
                if src and not any(x in src.lower() for x in ["logo", "icon", "banner", "avatar", "dm."]):
                    cover_url = urljoin(url, src)
                    break

        # 3. Synopsis Extraction
        synopsis_parts = []
        content_des = soup.select_one(".content-des")
        if content_des:
            for p in content_des.find_all("p"):
                txt = p.get_text(strip=True)
                if txt and not any(tag in txt.lower() for tag in ["uncen", "ซับไทยโดย", "ผู้แปล"]):
                    synopsis_parts.append(txt)
        synopsis = "\n\n".join(synopsis_parts)
        if not synopsis:
            og_desc = soup.find("meta", property="og:description") or soup.find("meta", attrs={"name": "description"})
            if og_desc and og_desc.get("content"):
                synopsis = og_desc["content"].strip()

        # 4. Episodes Detection
        sub_episodes = []
        dub_episodes = []
        other_episodes = []
        seen_urls = set()

        ep_elements = soup.select(".eplink a, .eplink-wrap a")
        if not ep_elements:
            ep_elements = soup.find_all("a", href=True)

        for a in ep_elements:
            href = a.get("href", "").strip()
            if not href or href == "#":
                continue
            full_url = urljoin(url, href)
            if full_url in seen_urls:
                continue

            text = a.get_text(strip=True)
            combined = f"{text} {href}"

            # Only consider if it matches episode patterns or is within .eplink
            is_in_eplink = bool(a.find_parent(class_="eplink") or a.find_parent(class_="eplink-wrap"))
            ep_match = re.search(r"ตอนที่\s*(\d+(?:\.\d+)?)", combined, re.I)
            if not ep_match:
                ep_match = re.search(r"(?:ep(?:isode)?)[-_.\s]*(\d+(?:\.\d+)?)", combined, re.I)

            if ep_match or is_in_eplink:
                if ep_match:
                    ep_num = float(ep_match.group(1))
                else:
                    ep_num = float(len(seen_urls) + 1)

                seen_urls.add(full_url)
                ep_title = text if len(text) > 3 else f"ตอนที่ {int(ep_num) if ep_num.is_integer() else ep_num}"

                is_dub = bool(re.search(r"พากย์ไทย|พากย์|dub", combined, re.I))
                is_sub = bool(re.search(r"ซับไทย|ซับ|sub", combined, re.I))
                audio_tag = "dub" if is_dub and not is_sub else ("sub" if is_sub else "sub")

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

        sub_episodes.sort(key=lambda x: x["episode_number"])
        dub_episodes.sort(key=lambda x: x["episode_number"])
        other_episodes.sort(key=lambda x: x["episode_number"])

        # Determine slug
        parsed_url = urlparse(url)
        path_parts = [p for p in parsed_url.path.strip("/").split("/") if p]
        base_id = path_parts[0] if path_parts else str(abs(hash(url)) % 100000)
        slug_name = re.sub(r"[^a-zA-Z0-9]+", "-", clean_title.lower()).strip("-")
        base_slug = f"{slug_name}-{base_id}" if slug_name else f"anifume-{base_id}"

        def build_coll(t_title: str, t_slug: str, t_eps: List[Dict[str, Any]], audio_label: Optional[str] = None):
            genres = ["Anime", "Action"]
            if audio_label:
                genres.append(audio_label)
            return {
                "slug": t_slug,
                "title": t_title,
                "cover_url": cover_url,
                "backdrop_url": cover_url,
                "synopsis": synopsis or "ไม่มีเรื่องย่อ",
                "genres": genres,
                "rating": "8.5",
                "status": f"{len(t_eps)} ตอน (จบแล้ว)" if "จบ" in raw_title else f"{len(t_eps)} ตอน",
                "year": "2024",
                "source_url": url,
                "is_movie": False,
                "episodes": t_eps
            }

        if sub_episodes and dub_episodes:
            sub_col = build_coll(f"{clean_title} (ซับไทย)", f"{base_slug}-sub", sub_episodes, "ซับไทย")
            dub_col = build_coll(f"{clean_title} (พากย์ไทย)", f"{base_slug}-dub", dub_episodes, "พากย์ไทย")
            sub_col["split_collections"] = [dict(sub_col), dict(dub_col)]
            return sub_col

        if dub_episodes and not sub_episodes:
            return build_coll(f"{clean_title} (พากย์ไทย)", f"{base_slug}-dub", dub_episodes + other_episodes, "พากย์ไทย")

        all_eps = sub_episodes + other_episodes
        if not all_eps and dub_episodes:
            all_eps = dub_episodes
        final_title = f"{clean_title} (ซับไทย)" if "ซับไทย" not in clean_title and "พากย์ไทย" not in clean_title else clean_title
        return build_coll(final_title, base_slug, all_eps, "ซับไทย")

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
                r_page = await client.get(page_url, headers={"Referer": "https://anifume.com/"})
                html = r_page.text
            except Exception as e:
                print(f"[AnifumeHandler] error fetching page {page_url}: {e}")
                return None

        # Anifume loads player via AJAX endpoint in script:
        # $.ajax({ url: "/k49dF65fkfl2X0So2lFB06?u=...", ... })
        ajax_matches = re.findall(r'url:\s*[\"\'](/[^\"\']+)[\"\']', html)
        if not ajax_matches:
            return None

        for ajax_path in ajax_matches:
            ajax_url = urljoin(page_url, ajax_path)
            try:
                r_ajax = await client.get(
                    ajax_url,
                    headers={
                        "Referer": page_url,
                        "X-Requested-With": "XMLHttpRequest"
                    }
                )
                if r_ajax.status_code != 200:
                    continue

                ajax_resp = r_ajax.text
                ifr_match = re.search(r'src=[\"\']([^\"\']+)[\"\']', ajax_resp)
                if not ifr_match:
                    continue

                player_url = urljoin(ajax_url, ifr_match.group(1))
                r_player = await client.get(player_url, headers={"Referer": page_url})
                if r_player.status_code != 200:
                    continue

                player_html = r_player.text

                # 1. Look for JWPlayer files array
                files = re.findall(r'[\"\']file[\"\']\s*:\s*[\"\']([^\"\']+)[\"\']', player_html)
                if files:
                    # Select best quality (1080p, 720p or first)
                    best_file = files[0]
                    for f in files:
                        if "720" in f or "1080" in f or "hd" in f.lower():
                            best_file = f
                            break
                    return best_file

                # 2. Check for direct m3u8 or mp4
                m3u8 = re.search(r'https?://[^\s\"\'<>]+\.(?:m3u8|mp4)[^\s\"\'<>]*', player_html)
                if m3u8:
                    return m3u8.group(0)

            except Exception as e:
                print(f"[AnifumeHandler] error resolving ajax {ajax_url}: {e}")

        return None
