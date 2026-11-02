import os
import re
import json
import httpx
from bs4 import BeautifulSoup
from urllib.parse import urlparse, urljoin
from typing import Dict, Any, List, Optional, Callable, Awaitable

from handlers.custom_rules import RuleBasedSiteHandler
from extractor import call_llm, clean_json_text

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "custom_sites.json")

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "th-TH,th;q=0.9,en-US;q=0.8,en;q=0.7",
}

def load_custom_sites() -> List[Dict[str, Any]]:
    if not os.path.exists(CONFIG_PATH):
        return []
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
            return []
    except Exception as e:
        print(f"[CustomSites] Error reading {CONFIG_PATH}: {e}")
        return []

def save_custom_sites(sites: List[Dict[str, Any]]) -> bool:
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(sites, f, ensure_ascii=False, indent=2)
        return True
    except Exception as e:
        print(f"[CustomSites] Error saving {CONFIG_PATH}: {e}")
        return False

def add_or_update_custom_site(new_rule: Dict[str, Any]) -> List[Dict[str, Any]]:
    sites = load_custom_sites()
    domains = [d.lower().strip() for d in new_rule.get("domains", []) if d.strip()]
    if not domains:
        raise ValueError("At least one domain is required")

    updated = False
    for i, s in enumerate(sites):
        existing_domains = [d.lower().strip() for d in s.get("domains", [])]
        if any(d in existing_domains for d in domains) or s.get("name") == new_rule.get("name"):
            sites[i] = new_rule
            updated = True
            break

    if not updated:
        sites.append(new_rule)

    save_custom_sites(sites)
    return sites

def delete_custom_site(identifier: str) -> List[Dict[str, Any]]:
    sites = load_custom_sites()
    ident = identifier.lower().strip()
    new_sites = []
    for s in sites:
        domains = [d.lower().strip() for d in s.get("domains", [])]
        name = s.get("name", "").lower().strip()
        if ident in domains or ident == name:
            continue
        new_sites.append(s)
    save_custom_sites(new_sites)
    return new_sites

def build_proxy_rules_for_sync(custom_sites: Optional[List[Dict[str, Any]]] = None) -> List[Dict[str, Any]]:
    """Builds unified proxy and anti-hotlinking rules for both server proxy and mobile client sync."""
    if custom_sites is None:
        custom_sites = load_custom_sites()

    rules = []

    # 1. Built-in system proxy rules
    rules.append({
        "name": "Stream-APH / QQStream",
        "match_domains": ["stream-aph", "qqhls", "qqstream"],
        "headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://qqstream.stream-aph.xyz/",
            "Origin": "https://qqstream.stream-aph.xyz",
            "Accept": "*/*"
        },
        "strip_fake_headers": True
    })
    rules.append({
        "name": "Animenani / Nya Stream",
        "match_domains": ["animenani", "nya.animenani"],
        "headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://nya.animenani.com/",
            "Origin": "https://nya.animenani.com",
            "Accept": "*/*"
        },
        "strip_fake_headers": True
    })
    rules.append({
        "name": "24PlayerHD / Orbitalkthai",
        "match_domains": ["24playerhd", "orbitalkthai"],
        "headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://main.24playerhd.com/",
            "Origin": "https://main.24playerhd.com",
            "Accept": "*/*"
        },
        "strip_fake_headers": True
    })
    rules.append({
        "name": "Anifume / Rukoluo",
        "match_domains": ["anifume", "rukoluo"],
        "headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://anifume.com/",
            "Accept": "*/*"
        },
        "strip_fake_headers": False
    })
    rules.append({
        "name": "FairyAnime / TonyTonyChopper",
        "match_domains": ["fairyanime", "tonytonychopper"],
        "headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://anime.tonytonychopper.net/",
            "Accept": "*/*"
        },
        "strip_fake_headers": False
    })
    rules.append({
        "name": "Animemami / Maimeorder",
        "match_domains": ["maimeorder", "animemami"],
        "headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://animemami.xyz/",
            "Origin": "https://animemami.xyz",
            "Accept": "*/*"
        },
        "strip_fake_headers": False
    })

    # 2. Dynamic custom sites proxy rules
    for site in custom_sites:
        if not isinstance(site, dict):
            continue
        req_proxy = site.get("requires_proxy") or bool(site.get("proxy_referer")) or bool(site.get("stream_domains"))
        if not req_proxy:
            continue

        match_domains = []
        for d in site.get("stream_domains", []):
            if d and d.lower().strip() not in match_domains:
                match_domains.append(d.lower().strip())
        for d in site.get("domains", []):
            if d and d.lower().strip() not in match_domains:
                match_domains.append(d.lower().strip())

        if not match_domains and site.get("proxy_referer"):
            parsed = urlparse(site["proxy_referer"])
            if parsed.netloc:
                match_domains.append(parsed.netloc.lower().replace("www.", ""))

        headers = {
            "User-Agent": site.get("proxy_user_agent") or "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Accept": "*/*"
        }
        if site.get("proxy_referer"):
            headers["Referer"] = site["proxy_referer"]
        elif site.get("domains"):
            headers["Referer"] = f"https://{site['domains'][0]}/"

        if site.get("proxy_origin"):
            headers["Origin"] = site["proxy_origin"]
        elif headers.get("Referer"):
            p = urlparse(headers["Referer"])
            headers["Origin"] = f"{p.scheme}://{p.netloc}"

        rules.append({
            "name": site.get("name", "Custom Proxy Rule"),
            "match_domains": match_domains,
            "headers": headers,
            "strip_fake_headers": bool(site.get("strip_fake_headers", False))
        })

    return rules

async def fetch_page_html(url: str) -> str:
    async with httpx.AsyncClient(headers=HEADERS, follow_redirects=True, timeout=20.0, verify=False) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        return resp.text

def extract_page_signals(url: str, html: str) -> Dict[str, Any]:
    soup = BeautifulSoup(html, "html.parser")
    parsed_url = urlparse(url)
    domain = parsed_url.netloc.lower().replace("www.", "")

    # Clean non-content tags
    for tag in soup(["script", "style", "svg", "noscript", "nav", "footer", "header"]):
        tag.decompose()

    # Title candidates
    title_candidates = []
    if soup.title and soup.title.string:
        title_candidates.append(f"<title>: {soup.title.string.strip()}")
    for h in soup.find_all(["h1", "h2"], limit=6):
        text = h.get_text(strip=True)
        if text and len(text) > 2:
            cls = ".".join(h.get("class", []))
            tag_desc = f"<{h.name}{('.' + cls) if cls else ''}>: {text}"
            title_candidates.append(tag_desc)

    # Image candidates
    cover_candidates = []
    for img in soup.find_all("img", limit=10):
        src = img.get("src") or img.get("data-src") or img.get("data-lazy-src")
        cls = ".".join(img.get("class", []))
        parent = img.parent
        p_cls = ".".join(parent.get("class", [])) if parent else ""
        if src and not any(src.lower().endswith(x) for x in [".svg", ".gif", "logo", "icon"]):
            cover_candidates.append(f"img[class='{cls}'] parent[class='{p_cls}']: {src}")

    # Episode link candidates
    episode_candidates = []
    for a in soup.find_all("a", href=True):
        text = a.get_text(strip=True)
        href = a.get("href", "")
        combined = f"{text} {href}".lower()
        if re.search(r"ตอนที่|ตอน|ep|episode|\b\d+\b", combined) and len(text) < 100:
            cls = ".".join(a.get("class", []))
            parent_tag = a.parent.name if a.parent else ""
            parent_cls = ".".join(a.parent.get("class", [])) if a.parent else ""
            episode_candidates.append({
                "text": text,
                "href": href,
                "selector_hint": f"{parent_tag}.{parent_cls} a.{cls}".replace("..", ".").strip("."),
                "parent_cls": parent_cls,
                "cls": cls
            })

    # Synopsis candidates
    synopsis_candidates = []
    for p in soup.find_all(["p", "div"], limit=30):
        t = p.get_text(strip=True)
        if len(t) > 60 and not re.search(r"ตอนที่|ep|copyright|cookie", t, re.I):
            cls = ".".join(p.get("class", []))
            synopsis_candidates.append(f"<{p.name}.{cls}>: {t[:150]}...")
            if len(synopsis_candidates) >= 3:
                break

    return {
        "domain": domain,
        "title_candidates": title_candidates[:5],
        "cover_candidates": cover_candidates[:5],
        "synopsis_candidates": synopsis_candidates[:3],
        "episode_samples": episode_candidates[:12],
        "total_ep_links_found": len(episode_candidates)
    }

async def generate_site_rule_with_llm(
    url: str,
    settings: Dict[str, str],
    hint: Optional[str] = None,
    on_event: Optional[Callable[[Dict[str, Any]], Awaitable[None]]] = None
) -> Dict[str, Any]:
    if on_event:
        await on_event({"type": "log", "message": f"🌐 กำลังดาวน์โหลดและวิเคราะห์โค้ด HTML จาก {url}..."})

    html = await fetch_page_html(url)
    soup = BeautifulSoup(html, "html.parser")
    signals = extract_page_signals(url, html)
    domain = signals["domain"]

    ep_sample_str = "\n".join([
        f"- text: \"{ep['text']}\" | href: \"{ep['href']}\" | selector_hint: \"{ep['selector_hint']}\""
        for ep in signals["episode_samples"]
    ])

    prompt = f"""You are an expert web scraping and CSS reverse engineer.
Target Website URL: {url}
Target Domain: {domain}

Detected Signals from Page:
Domain: {domain}
Title Candidates:
{chr(10).join(signals['title_candidates']) if signals['title_candidates'] else 'None detected'}

Cover Image Candidates:
{chr(10).join(signals['cover_candidates']) if signals['cover_candidates'] else 'None detected'}

Synopsis Candidates:
{chr(10).join(signals['synopsis_candidates']) if signals['synopsis_candidates'] else 'None detected'}

Episode Link Candidates ({signals['total_ep_links_found']} found):
{ep_sample_str if ep_sample_str else 'None detected'}

Additional User Hint:
{hint if hint else 'None'}

TASK:
Generate a Custom Site Rule JSON to extract anime series/episodes from this website automatically.
Fields:
- "name": Clean human readable site name (e.g. "{domain.split('.')[0].capitalize()} Anime")
- "domains": ["{domain}"]
- "title_selector": Accurate CSS selector for main anime title (e.g. "h1.entry-title, h1.post-title, h1")
- "title_clean_regex": Regex to strip episode numbers or trailers from title (e.g. "\\s*ตอนที่\\s*\\d+.*$")
- "cover_selector": CSS selector for cover/poster img (e.g. ".post-content-img img, .poster img, .entry-thumbnail img")
- "synopsis_selector": CSS selector for synopsis/description text (e.g. ".content-des p, .entry-content p, .synopsis")
- "episodes_selector": CSS selector targeting the <a> tags of the episode list (e.g. ".eplink a, .episode-list a, .list-episode a")
- "episode_number_regex": Regex for parsing episode number (e.g. "(?:ตอนที่|ep(?:isode)?)[-_.\\s]*(\\d+(?:\\.\\d+)?)")
- "stream_regex": Regex to find video stream URL in player or page (e.g. "https?://[^\\s\"'<>]+(?:\\.m3u8|\\.mp4)[^\\s\"'<>]*")
- "requires_proxy": Set true if video streaming requires Referer or anti-hotlinking bypass proxy
- "proxy_referer": Referer URL for stream proxy (e.g. "https://{domain}/")
- "proxy_origin": Origin URL for stream proxy (e.g. "https://{domain}")
- "stream_domains": List of video/stream host domains that require this proxy header (e.g. ["{domain}"])
- "strip_fake_headers": Set true if MPEG-TS chunks are masked with fake PNG/JPEG/WebP headers

Return ONLY a valid JSON object without markdown code blocks:
{{
  "name": "{domain.split('.')[0].capitalize()}",
  "domains": ["{domain}"],
  "title_selector": "h1.entry-title",
  "title_clean_regex": "\\s*ตอนที่\\s*\\d+.*$",
  "cover_selector": ".poster img",
  "synopsis_selector": ".entry-content p",
  "episodes_selector": ".episode-list a",
  "episode_number_regex": "(?:ตอนที่|ep(?:isode)?)[-_.\\s]*(\\d+(?:\\.\\d+)?)",
  "stream_regex": "https?://[^\\s\"'<>]+(?:\\.m3u8|\\.mp4)[^\\s\"'<>]*",
  "requires_proxy": true,
  "proxy_referer": "https://{domain}/",
  "proxy_origin": "https://{domain}",
  "stream_domains": ["{domain}"],
  "strip_fake_headers": false
}}"""

    if on_event:
        await on_event({"type": "log", "message": f"🤖 ส่งข้อมูลโครงสร้างหน้าเว็บให้ Local LLM สร้างกฎ CSS Selector..."})

    async def on_chunk(c: str):
        if on_event:
            await on_event({"type": "thinking", "chunk": c})

    raw_response = await call_llm(prompt, settings, on_chunk=on_chunk)
    cleaned = clean_json_text(raw_response)
    
    rule = None
    try:
        rule = json.loads(cleaned)
    except Exception:
        # Regex fallback to find JSON
        m = re.search(r"(\{[\s\S]*\})", cleaned)
        if m:
            try:
                rule = json.loads(m.group(1))
            except Exception:
                pass

    if not rule or not isinstance(rule, dict):
        # Heuristic fallback if LLM returned malformed JSON
        rule = {
            "name": f"{domain.split('.')[0].capitalize()} (Auto)",
            "domains": [domain],
            "title_selector": "h1.entry-title, h1.post-title, h1",
            "title_clean_regex": r"\s*ตอนที่\s*\d+.*$",
            "cover_selector": ".post-content-img img, .poster img, .entry-thumbnail img",
            "synopsis_selector": ".content-des p, .entry-content p, .synopsis",
            "episodes_selector": ".eplink a, .episode-list a, .eplister ul li a",
            "episode_number_regex": r"(?:ตอนที่|ep(?:isode)?)[-_.\s]*(\d+(?:\.\d+)?)",
            "stream_regex": r"https?://[^\s\"'<>]+(?:\.m3u8|\.mp4)[^\s\"'<>]*",
            "requires_proxy": True,
            "proxy_referer": f"https://{domain}/",
            "proxy_origin": f"https://{domain}",
            "stream_domains": [domain],
            "strip_fake_headers": False
        }

    # Ensure domains contains domain
    if domain not in rule.get("domains", []):
        rule.setdefault("domains", []).insert(0, domain)

    # Ensure proxy fields
    rule.setdefault("requires_proxy", True)
    rule.setdefault("proxy_referer", f"https://{domain}/")
    rule.setdefault("proxy_origin", f"https://{domain}")
    rule.setdefault("stream_domains", [domain])
    rule.setdefault("strip_fake_headers", False)

    if on_event:
        await on_event({"type": "log", "message": f"🧪 ทดสอบกฎที่สร้างขึ้นกับหน้าเว็บจริง..."})

    # Test the rule immediately on the actual page
    test_result = test_site_rule(rule, url, html=html)

    return {
        "status": "ok",
        "rule": rule,
        "test_result": test_result
    }

def test_site_rule(rule: Dict[str, Any], url: str, html: Optional[str] = None) -> Dict[str, Any]:
    try:
        if not html:
            import urllib.request
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=15) as r:
                html = r.read().decode("utf-8", errors="ignore")

        soup = BeautifulSoup(html, "html.parser")
        handler = RuleBasedSiteHandler(rule)
        extracted = handler.extract_anime(url, html, soup)

        if not extracted:
            return {
                "success": False,
                "message": "ไม่สามารถดึงข้อมูลได้ กรุณาตรวจสอบ selectors",
                "title": "",
                "cover_url": "",
                "synopsis": "",
                "episode_count": 0,
                "episodes": []
            }

        episodes = extracted.get("episodes", [])
        return {
            "success": True if (extracted.get("title") or episodes) else False,
            "message": f"ตรวจพบ {len(episodes)} ตอน" if episodes else "ดึงข้อมูลชื่อเรื่องได้ แต่ไม่พบรายการตอน",
            "title": extracted.get("title", ""),
            "cover_url": extracted.get("cover_url", ""),
            "synopsis": extracted.get("synopsis", "")[:300],
            "episode_count": len(episodes),
            "sample_episodes": episodes[:10],
            "requires_proxy": rule.get("requires_proxy", False) or bool(rule.get("proxy_referer")),
            "proxy_referer": rule.get("proxy_referer", ""),
            "proxy_origin": rule.get("proxy_origin", ""),
            "stream_domains": rule.get("stream_domains", [])
        }
    except Exception as e:
        return {
            "success": False,
            "message": f"เกิดข้อผิดพลาดในการทดสอบกฎ: {str(e)}",
            "title": "",
            "cover_url": "",
            "synopsis": "",
            "episode_count": 0,
            "sample_episodes": []
        }
