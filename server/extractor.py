import re
import json
import base64
import asyncio
import httpx
import urllib.parse
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
from typing import Dict, Any, List, Optional, Callable, Awaitable

from handlers import get_handler_for_url, get_all_handlers, list_supported_sites
from handlers.generic import GenericHandler
from handlers.dooplay import DooPlayHandler
from handlers.animenani import AnimenaniHandler, decode_animenani_bootstrap
from handlers.fairyanime import FairyAnimeHandler
from handlers.animeruka import AnimeRukaHandler
from handlers.animewaku import AnimeWakuHandler
from handlers.halim import HalimHandler

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "th-TH,th;q=0.9,en-US;q=0.8,en;q=0.7",
}

async def fetch_html(url: str) -> str:
    async with httpx.AsyncClient(headers=HEADERS, follow_redirects=True, timeout=20.0, verify=False) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        return resp.text

async def get_active_model(provider: str, base_url: str) -> Optional[str]:
    try:
        base_url = base_url.rstrip("/")
        if provider == "ollama":
            async with httpx.AsyncClient(timeout=4.0) as client:
                resp = await client.get(f"{base_url}/api/tags")
                if resp.status_code == 200:
                    models = resp.json().get("models", [])
                    if models:
                        return models[0]["name"]
        else: # lmstudio or openai-compatible
            async with httpx.AsyncClient(timeout=4.0) as client:
                resp = await client.get(f"{base_url}/models")
                if resp.status_code == 200:
                    data = resp.json().get("data", [])
                    if data:
                        return data[0]["id"]
    except Exception as e:
        print(f"[AutoModel] Error detecting active model: {e}")
    return None

async def call_llm(
    prompt: str,
    settings: Dict[str, str],
    on_chunk: Optional[Callable[[str], Awaitable[None]]] = None
) -> str:
    provider = settings.get("llm_provider", "lmstudio")
    full_text = []
    
    if provider == "ollama":
        base_url = settings.get("ollama_url", "http://localhost:11434").rstrip("/")
        model = settings.get("ollama_model", "auto")
        if not model or model.lower() in ("auto", "default", ""):
            detected = await get_active_model("ollama", base_url)
            model = detected or "llama3.2"

        print(f"[LLM] Calling Ollama at {base_url} with model: {model}")
        endpoint = f"{base_url}/api/generate"
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": bool(on_chunk),
            "options": {"temperature": 0.2}
        }
        if on_chunk:
            async with httpx.AsyncClient(timeout=90.0) as client:
                async with client.stream("POST", endpoint, json=payload) as response:
                    response.raise_for_status()
                    async for line in response.aiter_lines():
                        if not line:
                            continue
                        try:
                            item = json.loads(line)
                            chunk = item.get("response", "")
                            if chunk:
                                full_text.append(chunk)
                                await on_chunk(chunk)
                        except Exception:
                            pass
            return "".join(full_text)
        else:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.post(endpoint, json=payload)
                resp.raise_for_status()
                data = resp.json()
                return data.get("response", "")
    else: # lmstudio or openai-compatible
        base_url = settings.get("lmstudio_url", "http://localhost:1234/v1").rstrip("/")
        model = settings.get("lmstudio_model", "auto")
        if not model or model.lower() in ("auto", "default", ""):
            detected = await get_active_model("lmstudio", base_url)
            model = detected or "local-model"

        print(f"[LLM] Calling LM Studio at {base_url} with model: {model}")
        endpoint = f"{base_url}/chat/completions"
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": "You are an expert anime metadata and video stream extractor. Always reply strictly with valid JSON without markdown fences."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.2,
            "stream": bool(on_chunk)
        }
        if on_chunk:
            async with httpx.AsyncClient(timeout=90.0) as client:
                async with client.stream("POST", endpoint, json=payload) as response:
                    response.raise_for_status()
                    async for line in response.aiter_lines():
                        if not line:
                            continue
                        if line.startswith("data: "):
                            data_str = line[6:].strip()
                            if data_str == "[DONE]":
                                break
                            try:
                                data_obj = json.loads(data_str)
                                choices = data_obj.get("choices", [])
                                if choices:
                                    delta = choices[0].get("delta", {})
                                    chunk = delta.get("content", "")
                                    reasoning = delta.get("reasoning_content") or delta.get("reasoning") or ""
                                    if reasoning:
                                        await on_chunk(reasoning)
                                    if chunk:
                                        full_text.append(chunk)
                                        await on_chunk(chunk)
                            except Exception:
                                pass
            return "".join(full_text)
        else:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.post(endpoint, json=payload)
                resp.raise_for_status()
                data = resp.json()
                return data["choices"][0]["message"]["content"]

def clean_json_text(text: str) -> str:
    text = text.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()

def parse_html_heuristics(html: str, base_url: str) -> Dict[str, Any]:
    soup = BeautifulSoup(html, "html.parser")
    handler = get_handler_for_url(base_url, html=html)
    if handler.name != "Universal Generic Handler":
        custom_data = handler.extract_anime(base_url, html, soup)
        if custom_data:
            return custom_data

    # Fallback to universal generic heuristics
    return GenericHandler().extract_anime(base_url, html, soup)

async def extract_anime(
    url: str,
    settings: Dict[str, str],
    use_ai: bool = True,
    on_event: Optional[Callable[[Dict[str, Any]], Awaitable[None]]] = None
) -> Dict[str, Any]:
    if on_event:
        await on_event({"type": "log", "message": f"🌐 เริ่มต้นดาวน์โหลดหน้าเว็บจาก {url}..."})

    html = await fetch_html(url)
    heuristic_data = parse_html_heuristics(html, url)

    handler = get_handler_for_url(url, html=html)
    if on_event:
        await on_event({"type": "log", "message": f"🔍 ตรวจพบประเภทเว็บไซต์: {handler.name}"})

    async def auto_resolve_episodes(ep_list: List[Dict[str, Any]]):
        if not ep_list:
            return
        if on_event:
            await on_event({"type": "log", "message": f"🎬 เริ่มถอดรหัสวิดีโอสตรีมสด {len(ep_list)} ตอน..."})
        
        sem = asyncio.Semaphore(4)
        resolved_count = 0

        async with httpx.AsyncClient(headers=HEADERS, follow_redirects=True, timeout=20.0, verify=False) as client:
            async def _fill(idx: int, ep: Dict[str, Any]):
                nonlocal resolved_count
                if not ep.get("stream_url") and ep.get("page_url"):
                    async with sem:
                        s = await resolve_direct_stream(ep["page_url"], client=client, settings=settings)
                        if s:
                            ep["stream_url"] = s
                            resolved_count += 1
                            if on_event:
                                await on_event({
                                    "type": "log",
                                    "message": f"  ▶ ตอนที่ {ep.get('episode_number')} ({ep.get('title')}): ถอดรหัสสำเร็จ"
                                })
            await asyncio.gather(*(_fill(i, ep) for i, ep in enumerate(ep_list, 1)))
        
        if on_event:
            await on_event({
                "type": "log",
                "message": f"✨ ถอดรหัสวิดีโอเรียบร้อย ({resolved_count}/{len(ep_list)} ตอน)"
            })

    def ensure_unique_episode_ids(episodes: list, slug: str):
        seen = set()
        for i, ep in enumerate(episodes, 1):
            ep_num = ep.get("episode_number", i)
            try:
                num_val = float(ep_num)
                num_str = str(int(num_val)) if num_val.is_integer() else str(num_val)
            except Exception:
                num_str = str(i)
            
            base_id = f"{slug}-ep-{num_str}"
            ep_id = base_id
            counter = 1
            while ep_id in seen:
                counter += 1
                ep_id = f"{base_id}-{counter}"
            seen.add(ep_id)
            ep["id"] = ep_id

    # If use_ai is disabled or site has dedicated custom handler with reliable episode parsing
    is_dedicated = handler.name != "Universal Generic Handler" and len(heuristic_data.get("episodes", [])) > 0

    if not use_ai or is_dedicated:
        if on_event:
            await on_event({
                "type": "log",
                "message": f"📑 แยกข้อมูลสำเร็จ: เรื่อง \"{heuristic_data.get('title')}\" (พบ {len(heuristic_data.get('episodes', []))} ตอน)"
            })

        if heuristic_data.get("split_collections"):
            splits = heuristic_data["split_collections"]
            for col in splits:
                ensure_unique_episode_ids(col.get("episodes", []), col["slug"])
                await auto_resolve_episodes(col.get("episodes", []))
            if on_event:
                await on_event({"type": "log", "message": "✅ ประมวลผลเสร็จสิ้น พร้อมบันทึก!"})
            return heuristic_data
        else:
            ensure_unique_episode_ids(heuristic_data.get("episodes", []), heuristic_data["slug"])
            await auto_resolve_episodes(heuristic_data.get("episodes", []))
            if on_event:
                await on_event({"type": "log", "message": "✅ ประมวลผลเสร็จสิ้น พร้อมบันทึก!"})
            return heuristic_data

    # Prepare condensed context for Local LLM
    if on_event:
        await on_event({
            "type": "log",
            "message": f"🧠 ส่งข้อมูลหน้าเว็บไปยัง Local LLM ({settings.get('llm_provider', 'lmstudio')}) เพื่อวิเคราะห์..."
        })

    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "noscript", "svg", "nav", "footer"]):
        tag.decompose()

    text_snippet = soup.get_text(separator="\n", strip=True)[:3500]

    is_movie = heuristic_data.get("is_movie", False) or bool(
        heuristic_data.get("split_collections") and any(c.get("is_movie") for c in heuristic_data["split_collections"])
    )

    detected_eps = heuristic_data.get("episodes", [])
    if heuristic_data.get("split_collections"):
        detected_eps = []
        for col in heuristic_data["split_collections"]:
            detected_eps.extend(col.get("episodes", []))

    ep_links_desc = "\n".join([f"- ตอนที่ {ep.get('episode_number')}: {ep.get('title')} ({ep.get('page_url')})" for ep in detected_eps[:60]])

    prompt = f"""You are analyzing an anime webpage to extract structured movie/series information.
Target URL: {url}
Detected Type: {"Movie / Single Episode (ภาพยนตร์ / เดอะมูฟวี่ / ตอนเดียวจบ)" if is_movie else "Anime Series"}
Initial Detected Title: {heuristic_data.get('title')}
Initial Detected Cover: {heuristic_data.get('cover_url')}
Total Detected Episodes: {len(detected_eps)}

Detected Episodes:
{ep_links_desc if ep_links_desc else "None detected automatically"}

Webpage Text Snippet:
{text_snippet}

Extract the anime metadata and list of ALL episodes.
SPECIAL INSTRUCTIONS:
- If this webpage is a single-episode Movie (ภาพยนตร์ / เดอะมูฟวี่ / The Movie), OVA, or anime with no multiple episode links, you MUST include 1 episode for the movie (episode_number: 1.0, title: "เดอะมูฟวี่" or movie title, page_url: "{url}").
- If Thai Sub (ซับไทย) and/or Thai Dub (พากย์ไทย) are mentioned, indicate them appropriately.
- Extract the clean title in Thai and/or English (without website branding or trailing tags).
- Extract a detailed synopsis/summary in Thai.
- Extract accurate genres (e.g. Action, Fantasy, Movie).
- Extract rating (e.g. 8.5) and release year (e.g. 2024).
- Set status (e.g. 'เดอะมูฟวี่ (ตอนเดียวจบ)' or 'จบแล้ว').

Return ONLY a single raw JSON object with this exact structure:
{{
  "title": "Title in Thai or English",
  "cover_url": "Image URL of the poster/cover",
  "synopsis": "Synopsis/summary in Thai",
  "genres": ["Action", "Fantasy", "Movie"],
  "rating": "8.5",
  "status": "จบแล้ว (เดอะมูฟวี่)",
  "year": "2024",
  "is_movie": true,
  "episodes": [
    {{
      "episode_number": 1.0,
      "title": "เดอะมูฟวี่",
      "page_url": "{url}",
      "stream_url": ""
    }}
  ]
}}
Do NOT wrap in markdown code fences. Output valid JSON only."""

    try:
        async def on_llm_chunk(chunk: str):
            if on_event:
                await on_event({"type": "thinking", "chunk": chunk})

        raw_response = await call_llm(prompt, settings, on_chunk=on_llm_chunk)
        cleaned = clean_json_text(raw_response)
        parsed = json.loads(cleaned)

        if on_event:
            await on_event({"type": "log", "message": f"🤖 LLM วิเคราะห์เสร็จสิ้น: \"{parsed.get('title')}\""})

        if heuristic_data.get("split_collections"):
            splits = heuristic_data["split_collections"]
            clean_title = re.sub(r"\s*(?:และ\s*)?(?:ซับไทย|พากย์ไทย|จบแล้ว)\s*$", "", parsed.get("title") or heuristic_data["title"], flags=re.I).strip()
            for col in splits:
                if "พากย์ไทย" in col["title"]:
                    col["title"] = f"{clean_title} (พากย์ไทย)"
                elif "ซับไทย" in col["title"]:
                    col["title"] = f"{clean_title} (ซับไทย)"
                else:
                    col["title"] = clean_title
                col["synopsis"] = parsed.get("synopsis") or col.get("synopsis")
                col["genres"] = parsed.get("genres") or col.get("genres")
                col["rating"] = str(parsed.get("rating") or col.get("rating"))
                col["year"] = str(parsed.get("year") or col.get("year"))
                col["status"] = parsed.get("status") or col.get("status")
                if parsed.get("cover_url"):
                    col["cover_url"] = parsed["cover_url"]
                    col["backdrop_url"] = parsed.get("backdrop_url") or parsed["cover_url"]
                for i, ep in enumerate(col.get("episodes", []), 1):
                    ep_num = ep.get("episode_number", i)
                    ep["id"] = f"{col['slug']}-ep-{int(ep_num) if isinstance(ep_num, (int, float)) and ep_num.is_integer() else ep_num}"
                col.pop("split_collections", None)
                await auto_resolve_episodes(col.get("episodes", []))
            
            if splits:
                for k, v in splits[0].items():
                    if k != "split_collections":
                        heuristic_data[k] = v
            if on_event:
                await on_event({"type": "log", "message": "✅ วิเคราะห์และถอดรหัสวิดีโอสมบูรณ์!"})
            return heuristic_data

        slug = heuristic_data.get("slug")
        if not slug:
            slug = re.sub(r"[^a-zA-Z0-9]+", "-", (parsed.get("title") or "anime").lower()).strip("-")

        ep_map = {}
        for ep in detected_eps:
            num = ep.get("episode_number")
            if num is not None:
                ep_map[float(num)] = dict(ep)

        parsed_eps = parsed.get("episodes") or []
        for ep in parsed_eps:
            num = float(ep.get("episode_number") or len(ep_map) + 1)
            p_url = ep.get("page_url") or ""
            if p_url and not p_url.startswith("http"):
                p_url = urljoin(url, p_url)
            s_url = ep.get("stream_url", "")
            if s_url and not s_url.startswith("http"):
                s_url = urljoin(url, s_url)

            if num in ep_map:
                if ep.get("title") and len(ep.get("title")) > 3:
                    ep_map[num]["title"] = ep["title"]
                if s_url:
                    ep_map[num]["stream_url"] = s_url
                if p_url:
                    ep_map[num]["page_url"] = p_url
            else:
                ep_map[num] = {
                    "episode_number": num,
                    "title": ep.get("title") or f"ตอนที่ {int(num) if num.is_integer() else num}",
                    "page_url": p_url or url,
                    "stream_url": s_url,
                }

        if is_movie and not ep_map:
            ep_map[1.0] = {
                "episode_number": 1.0,
                "title": "เดอะมูฟวี่",
                "page_url": url,
                "stream_url": "",
            }

        final_episodes = []
        for num in sorted(ep_map.keys()):
            item = ep_map[num]
            final_episodes.append({
                "episode_number": num,
                "title": item.get("title") or (f"เดอะมูฟวี่" if is_movie else f"ตอนที่ {int(num) if num.is_integer() else num}"),
                "page_url": item.get("page_url") or url,
                "stream_url": item.get("stream_url", ""),
                "thumbnail_url": parsed.get("cover_url") or heuristic_data.get("cover_url"),
                "duration": item.get("duration", "Movie" if is_movie else "24:00")
            })

        ensure_unique_episode_ids(final_episodes, slug)

        if final_episodes:
            await auto_resolve_episodes(final_episodes)

        if on_event:
            await on_event({"type": "log", "message": "✅ วิเคราะห์และถอดรหัสวิดีโอสมบูรณ์!"})

        return {
            "slug": slug,
            "title": parsed.get("title") or heuristic_data["title"],
            "cover_url": parsed.get("cover_url") or heuristic_data["cover_url"],
            "backdrop_url": parsed.get("backdrop_url") or heuristic_data["cover_url"],
            "synopsis": parsed.get("synopsis") or heuristic_data["synopsis"],
            "genres": parsed.get("genres") or heuristic_data["genres"],
            "rating": str(parsed.get("rating") or heuristic_data["rating"]),
            "status": parsed.get("status") or heuristic_data["status"],
            "year": str(parsed.get("year") or heuristic_data["year"]),
            "is_movie": is_movie,
            "source_url": url,
            "episodes": final_episodes
        }
    except Exception as e:
        print(f"[Extractor] LLM Extraction failed or returned invalid JSON ({e}). Falling back to heuristics.")
        if on_event:
            await on_event({"type": "log", "message": f"⚠️ LLM ตอบสนองไม่สำเร็จ ({e}) กำลังใช้ Heuristics สำรอง..."})
        if heuristic_data.get("split_collections"):
            for col in heuristic_data["split_collections"]:
                ensure_unique_episode_ids(col.get("episodes", []), col["slug"])
                await auto_resolve_episodes(col.get("episodes", []))
            return heuristic_data
        else:
            eps = heuristic_data.get("episodes", [])
            ensure_unique_episode_ids(eps, heuristic_data["slug"])
            await auto_resolve_episodes(eps)
            return heuristic_data

async def resolve_direct_stream(page_url: str, client: Optional[httpx.AsyncClient] = None, settings: Optional[Dict[str, str]] = None) -> Optional[str]:
    """Resolves direct stream URL using modular site handlers, Halim, DooPlay, Animenani, and generic video engines."""
    should_close_client = False
    if client is None:
        client = httpx.AsyncClient(headers=HEADERS, follow_redirects=True, timeout=20.0, verify=False)
        should_close_client = True

    try:
        # 0. Fast pre-resolve attempt with dedicated handler (avoids downloading 500KB+ HTML if URL has ID)
        pre_handler = get_handler_for_url(page_url)
        if pre_handler.name != "Universal Generic Handler":
            fast_res = await pre_handler.resolve_stream(page_url, "", None, client, settings=settings)
            if fast_res:
                return fast_res

        parsed_page = urllib.parse.urlparse(page_url)
        base_origin = f"{parsed_page.scheme}://{parsed_page.netloc}"
        r = await client.get(page_url, headers={"Referer": base_origin})
        html = r.text
        soup = BeautifulSoup(html, "html.parser")

        # 1. Primary handler for this URL
        handler = get_handler_for_url(page_url, html=html)
        if handler.name != "Universal Generic Handler":
            res = await handler.resolve_stream(page_url, html, soup, client, settings=settings)
            if res:
                return res

        # 2. Halim fallback
        halim = HalimHandler()
        if halim.can_handle(page_url, html=html):
            res = await halim.resolve_stream(page_url, html, soup, client, settings=settings)
            if res:
                return res

        # 3. DooPlay fallback if page exhibits DooPlay structures
        dooplay = DooPlayHandler()
        if dooplay.can_handle(page_url, html=html):
            res = await dooplay.resolve_stream(page_url, html, soup, client, settings=settings)
            if res:
                return res

        # 4. Animenani fallback
        animenani = AnimenaniHandler()
        if animenani.can_handle(page_url, html=html):
            res = await animenani.resolve_stream(page_url, html, soup, client, settings=settings)
            if res:
                return res

        # 5. FairyAnime fallback
        fairyanime = FairyAnimeHandler()
        if fairyanime.can_handle(page_url, html=html):
            res = await fairyanime.resolve_stream(page_url, html, soup, client, settings=settings)
            if res:
                return res

        # 6. AnimeRuka fallback
        animeruka = AnimeRukaHandler()
        if animeruka.can_handle(page_url, html=html):
            res = await animeruka.resolve_stream(page_url, html, soup, client, settings=settings)
            if res:
                return res

        # 7. AnimeWaku fallback
        animewaku = AnimeWakuHandler()
        if animewaku.can_handle(page_url, html=html):
            res = await animewaku.resolve_stream(page_url, html, soup, client, settings=settings)
            if res:
                return res

        # 5. Universal generic fallback
        res = await GenericHandler().resolve_stream(page_url, html, soup, client, settings=settings)
        if res:
            return res

        # 6. Optional AI Fallback
        if settings and (settings.get("llm_provider") or settings.get("lmstudio_url") or settings.get("ollama_url")):
            try:
                for tag in soup(["style", "svg", "noscript"]):
                    tag.decompose()
                page_text = soup.get_text(separator="\n", strip=True)[:1500]
                script_snippets = "\n".join([s.get_text()[:300] for s in soup.find_all("script") if s.get_text()][:5])
                
                llm_prompt = f"""Find the video stream or embed URL for this anime episode page.
Episode URL: {page_url}
Text snippet:
{page_text}

Script snippet:
{script_snippets}

Return ONLY the direct video stream URL (ending in .m3u8, .mp4) or the player iframe embed URL. If nothing found, return NONE."""
                ans = await call_llm(llm_prompt, settings)
                url_m = re.search(r"https?://[^\s\"<>]+", ans)
                if url_m:
                    found = url_m.group(0)
                    if found != "NONE" and (".m3u8" in found or ".mp4" in found):
                        return found
            except Exception:
                pass

    except Exception as e:
        print(f"[StreamResolver] Error resolving {page_url}: {e}")
    finally:
        if should_close_client:
            await client.aclose()

    return None
