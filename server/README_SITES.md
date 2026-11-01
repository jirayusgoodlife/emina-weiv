# 🌐 คู่มือการรองรับเว็บไซต์และการเพิ่มเว็บใหม่ (AnimeView Server)

Server รองรับการดึงข้อมูลอนิเมะ (Metadata) และถอดรหัส URL วิดีโอสตรีมสด (Direct Stream เช่น `.mp4`, `.m3u8`) จากหลากหลายเว็บไซต์ ด้วยสถาปัตยกรรม **Modular Site Handlers** และ **Rule-Based Engine** ที่ยืดหยุ่น

---

## 🚀 เว็บไซต์และระบบที่รองรับในปัจจุบัน

1. **Anifume (`anifume.com`)**
   - รองรับหน้าอนิเมะ เช่น `https://anifume.com/40235` (Kaifuku Jutsushi no Yarinaoshi ตอนที่ 1-12)
   - ดึงชื่อเรื่อง, รูปภาพหน้าปก, เรื่องย่อ, และรายการตอนทั้งหมด
   - ถอดรหัส AJAX Player และดึงลิงก์ตรง `.mp4` คุณภาพสูงจากเซิร์ฟเวอร์ Rukoluo แบบเรียลไทม์
2. **เว็บตระกูล WordPress DooPlay**
   - เช่น `anime-waku.com`, `animekimi.com`, `123-hd.com`, `anime-subthai.com`
   - ถอดรหัสผ่าน DooPlay REST API (`/wp-json/dooplayer/v1/post/...`)
3. **Animenani / Nya Stream**
   - ถอดรหัส Reverse Base64 Bootstrap Payload จากเครื่องเล่นวิดีโอ
4. **Universal Generic Handler & Local AI Fallback**
   - รองรับเว็บอนิเมะทั่วไปด้วย Heuristics อัจฉริยะ (ค้นหาแท็ก `<video>`, `<source>`, JWPlayer, Video.js, iframe embed)
   - ผสานพลังกับ Local LLM (Ollama / LM Studio) ในการวิเคราะห์โครงสร้างหน้าเว็บอัตโนมัติ

---

## 🛠️ วิธีการปรับแก้และเพิ่มเว็บใหม่ในอนาคต

คุณสามารถเพิ่มการรองรับเว็บไซต์ใหม่ได้ **2 วิธี** ตามความซับซ้อนของเว็บไซต์:

---

### วิธีที่ 1: เพิ่มเว็บใหม่ผ่านไฟล์คอนฟิก `custom_sites.json` (ง่ายที่สุด ไม่ต้องเขียนโค้ด)

เปิดไฟล์ `server/custom_sites.json` แล้วเพิ่มการตั้งค่าของเว็บใหม่ลงใน Array ตัวอย่างเช่น:

```json
[
  {
    "name": "ชื่อเว็บตัวอย่าง",
    "domains": ["my-anime-site.com"],
    "title_selector": "h1.entry-title, h1.post-title",
    "title_clean_regex": "\\s*ตอนที่\\s*\\d+.*$",
    "cover_selector": ".poster img, .entry-thumbnail img",
    "synopsis_selector": ".entry-content p, .synopsis",
    "episodes_selector": ".episode-list a, .eplink a",
    "episode_number_regex": "(?:ตอนที่|ep(?:isode)?)[-_.\\s]*(\\d+(?:\\.\\d+)?)",
    "player_ajax_regex": "url:\\s*[\"'](/ajax/player/[^\"']+)[\"']",
    "stream_regex": "https?://[^\\s\"'<>]+(?:\\.m3u8|\\.mp4)[^\\s\"'<>]*"
  }
]
```

#### รายละเอียดฟิลด์:
- **`domains`**: รายชื่อโดเมนของเว็บ เช่น `["animesite.com"]`
- **`title_selector`**: CSS Selector สำหรับชื่อเรื่อง เช่น `h1.title`
- **`title_clean_regex`**: Regular Expression สำหรับตัดคำที่ไม่ต้องการออกจากชื่อ เช่น `\s*ตอนที่\s*\d+.*$`
- **`cover_selector`**: CSS Selector สำหรับรูปภาพโปสเตอร์
- **`synopsis_selector`**: CSS Selector สำหรับเนื้อเรื่องย่อ
- **`episodes_selector`**: CSS Selector ของแท็ก `<a>` รายการตอน
- **`episode_number_regex`**: Regex สำหรับดึงหมายเลขตอน
- **`player_ajax_regex`** *(ถ้ามี)*: Regex ดึง endpoint AJAX ของตัวเล่นวิดีโอ
- **`stream_regex`**: Regex ค้นหา URL วิดีโอ `.mp4` หรือ `.m3u8`

> 💡 **ข้อดี:** Server จะโหลดค่าในไฟล์ `custom_sites.json` ทันทีโดยไม่ต้องเขียนโปรแกรมใหม่

---

### วิธีที่ 2: เขียน Handler คลาสใหม่ด้วย Python (สำหรับเว็บที่มีการเข้ารหัสซับซ้อน)

หากเว็บไซต์มีการถอดรหัสเฉพาะตัว เช่น AJAX หลายชั้น หรือเข้ารหัส token ให้สร้างไฟล์ Python ใหม่ในโฟลเดอร์ `server/handlers/`:

1. สร้างไฟล์ เช่น `server/handlers/my_custom_site.py`:
```python
import re
from bs4 import BeautifulSoup
import httpx
from typing import Dict, Any, Optional
from .base import BaseSiteHandler

class MyCustomSiteHandler(BaseSiteHandler):
    name = "MyCustomSite"
    domains = ["mycustomanime.com"]

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        # ดึงชื่อเรื่อง, รูปภาพปก, เรื่องย่อ, และรายการตอน
        title = soup.find("h1").get_text(strip=True)
        cover_url = soup.find("meta", property="og:image")["content"]
        
        episodes = []
        for i, a in enumerate(soup.select(".ep-list a"), 1):
            episodes.append({
                "episode_number": float(i),
                "title": a.get_text(strip=True),
                "page_url": a["href"],
                "stream_url": "",
                "audio_type": "sub"
            })
            
        return {
            "slug": f"custom-{title.lower()}",
            "title": title,
            "cover_url": cover_url,
            "backdrop_url": cover_url,
            "synopsis": "เรื่องย่อ...",
            "genres": ["Anime"],
            "rating": "8.0",
            "status": f"{len(episodes)} ตอน",
            "year": "2024",
            "source_url": url,
            "is_movie": False,
            "episodes": episodes
        }

    async def resolve_stream(self, page_url: str, html: str, soup: BeautifulSoup, client: httpx.AsyncClient, settings=None) -> Optional[str]:
        # ดึงลิงก์ตรง .mp4 หรือ .m3u8
        # เช่น ยิง AJAX หรือแกะ iframe
        match = re.search(r'https?://[^\s"\'<>]+\.(?:mp4|m3u8)', html)
        return match.group(0) if match else None
```

2. ลงทะเบียน Handler ใน `server/handlers/__init__.py`:
```python
from .my_custom_site import MyCustomSiteHandler

def get_all_handlers() -> List[BaseSiteHandler]:
    handlers: List[BaseSiteHandler] = [
        AnifumeHandler(),
        DooPlayHandler(),
        AnimenaniHandler(),
        MyCustomSiteHandler(), # <-- เพิ่มตรงนี้
    ]
    ...
```

---

## 🧪 การทดสอบรัน

คุณสามารถทดสอบดึงข้อมูลเว็บและสตรีมผ่านสคริปต์ Python ใน virtual environment ได้ทันที:

```bash
cd /home/jirayus/Projects/AnimeView/server
.venv/bin/python -c "
import asyncio
from extractor import extract_anime

async def test():
    data = await extract_anime('https://anifume.com/40235', settings={}, use_ai=False)
    print('เรื่อง:', data['title'])
    print('รูปปก:', data['cover_url'])
    print('จำนวนตอน:', len(data['episodes']))
    for ep in data['episodes'][:3]:
        print(' -', ep['title'], '->', ep['stream_url'])

asyncio.run(test())
"
```
