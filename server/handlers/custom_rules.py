import os
import re
import json
from typing import Dict, Any, List, Optional
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler

class RuleBasedSiteHandler(BaseSiteHandler):
    """
    A declarative site handler dynamically loaded from JSON configuration.
    Allows users to add support for new anime websites without editing Python code!
    """
    def __init__(self, rule: Dict[str, Any]):
        self.rule = rule
        self.name = rule.get("name", "CustomSite")
        self.domains = rule.get("domains", [])
        self.title_selector = rule.get("title_selector")
        self.title_clean_regex = rule.get("title_clean_regex")
        self.cover_selector = rule.get("cover_selector")
        self.synopsis_selector = rule.get("synopsis_selector")
        self.episodes_selector = rule.get("episodes_selector")
        self.episode_number_regex = rule.get("episode_number_regex", r"(?:ตอนที่|ep(?:isode)?)[-_.\s]*(\d+(?:\.\d+)?)")
        self.player_ajax_regex = rule.get("player_ajax_regex")
        self.player_iframe_selector = rule.get("player_iframe_selector", "iframe")
        self.stream_regex = rule.get("stream_regex", r"https?://[^\s\"\'<>]+\.(?:m3u8|mp4)[^\s\"\'<>]*")

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        # 1. Title
        title = ""
        if self.title_selector:
            tag = soup.select_one(self.title_selector)
            if tag:
                title = tag.get_text(strip=True)
        if not title:
            og_t = soup.find("meta", property="og:title")
            title = og_t["content"] if og_t and og_t.get("content") else (soup.title.string if soup.title else "")

        if self.title_clean_regex and title:
            title = re.sub(self.title_clean_regex, "", title, flags=re.I).strip()
        else:
            title = re.sub(r"\s*ตอนที่\s*\d+.*$", "", title, flags=re.I).strip()
            title = re.sub(r"\s*(?:และ\s*)?(?:ซับไทย|พากย์ไทย|จบแล้ว)\s*$", "", title, flags=re.I).strip()

        # 2. Cover
        cover_url = ""
        if self.cover_selector:
            img = soup.select_one(self.cover_selector)
            if img:
                src = img.get("src") or img.get("data-src") or img.get("data-lazy-src")
                if src:
                    cover_url = urljoin(url, src)
        if not cover_url:
            og_img = soup.find("meta", property="og:image")
            if og_img and og_img.get("content"):
                cover_url = urljoin(url, og_img["content"])

        # 3. Synopsis
        synopsis = ""
        if self.synopsis_selector:
            syn_elem = soup.select(self.synopsis_selector)
            if syn_elem:
                synopsis = "\n\n".join([e.get_text(strip=True) for e in syn_elem if e.get_text(strip=True)])
        if not synopsis:
            og_desc = soup.find("meta", property="og:description")
            if og_desc and og_desc.get("content"):
                synopsis = og_desc["content"].strip()

        # 4. Episodes
        episodes = []
        seen = set()
        selector = self.episodes_selector or "a[href]"
        for a in soup.select(selector):
            href = a.get("href", "").strip()
            if not href or href == "#":
                continue
            full_url = urljoin(url, href)
            if full_url in seen:
                continue

            text = a.get_text(strip=True)
            combined = f"{text} {href}"

            match = re.search(self.episode_number_regex, combined, re.I)
            if match or self.episodes_selector:
                ep_num = float(match.group(1)) if match else float(len(episodes) + 1)
                seen.add(full_url)

                is_dub = bool(re.search(r"พากย์ไทย|พากย์|dub", combined, re.I))
                is_sub = bool(re.search(r"ซับไทย|ซับ|sub", combined, re.I))
                audio_tag = "dub" if is_dub and not is_sub else ("sub" if is_sub else "unknown")

                episodes.append({
                    "episode_number": ep_num,
                    "title": text if len(text) > 3 else f"ตอนที่ {int(ep_num) if ep_num.is_integer() else ep_num}",
                    "page_url": full_url,
                    "stream_url": "",
                    "audio_type": audio_tag
                })

        if not episodes:
            return None

        episodes.sort(key=lambda x: x["episode_number"])

        parsed_u = urlparse(url)
        slug_raw = re.sub(r"[^a-zA-Z0-9]+", "-", title.lower()).strip("-")
        slug = f"{slug_raw}-{abs(hash(url)) % 100000}" if slug_raw else f"anime-{abs(hash(url)) % 100000}"

        return {
            "slug": slug,
            "title": title or "Anime",
            "cover_url": cover_url,
            "backdrop_url": cover_url,
            "synopsis": synopsis or "ไม่มีเรื่องย่อ",
            "genres": ["Anime"],
            "rating": "8.0",
            "status": f"{len(episodes)} ตอน",
            "year": "2024",
            "source_url": url,
            "is_movie": False,
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
                r = await client.get(page_url)
                html = r.text
                soup = BeautifulSoup(html, "html.parser")
            except Exception:
                return None

        # 1. AJAX Player pattern
        if self.player_ajax_regex:
            ajax_m = re.search(self.player_ajax_regex, html)
            if ajax_m:
                ajax_path = ajax_m.group(1) if ajax_m.groups() else ajax_m.group(0)
                ajax_url = urljoin(page_url, ajax_path)
                try:
                    r_ajax = await client.get(ajax_url, headers={"Referer": page_url, "X-Requested-With": "XMLHttpRequest"})
                    if r_ajax.status_code == 200:
                        # Extract iframe or stream from AJAX response
                        ifr_m = re.search(r'src=[\"\']([^\"\']+)[\"\']', r_ajax.text)
                        if ifr_m:
                            player_url = urljoin(ajax_url, ifr_m.group(1))
                            r_player = await client.get(player_url, headers={"Referer": page_url})
                            # Find stream
                            s_m = re.search(self.stream_regex, r_player.text)
                            if s_m:
                                return s_m.group(1) if s_m.groups() else s_m.group(0)
                except Exception as e:
                    print(f"[RuleBasedHandler] error in ajax resolve: {e}")

        # 2. Player iframe pattern
        if soup:
            for ifr in soup.select(self.player_iframe_selector):
                src = ifr.get("src") or ifr.get("data-src")
                if src:
                    player_url = urljoin(page_url, src)
                    try:
                        r_p = await client.get(player_url, headers={"Referer": page_url})
                        s_m = re.search(self.stream_regex, r_p.text)
                        if s_m:
                            return s_m.group(1) if s_m.groups() else s_m.group(0)
                    except Exception:
                        pass

        # 3. Direct regex search on page HTML
        s_m = re.search(self.stream_regex, html)
        if s_m:
            return s_m.group(1) if s_m.groups() else s_m.group(0)

        return None

def load_custom_rules(config_path: str) -> List[RuleBasedSiteHandler]:
    """Load user-defined custom site rules from JSON."""
    if not os.path.exists(config_path):
        return []
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            rules_data = json.load(f)
            handlers = []
            for r in rules_data:
                if isinstance(r, dict) and r.get("domains"):
                    handlers.append(RuleBasedSiteHandler(r))
            return handlers
    except Exception as e:
        print(f"[CustomRules] Error loading {config_path}: {e}")
        return []
