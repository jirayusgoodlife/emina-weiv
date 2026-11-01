import sqlite3
import json
import os
from typing import List, Dict, Any, Optional

DB_PATH = os.path.join(os.path.dirname(__file__), "anime_studio.db")

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    with get_db() as conn:
        cursor = conn.cursor()
        
        # Anime Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS anime (
                slug TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                cover_url TEXT NOT NULL,
                backdrop_url TEXT,
                synopsis TEXT,
                genres TEXT,
                rating TEXT,
                status TEXT,
                year TEXT,
                source_url TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        # Episodes Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS episodes (
                id TEXT PRIMARY KEY,
                anime_slug TEXT NOT NULL,
                episode_number REAL NOT NULL,
                title TEXT NOT NULL,
                stream_url TEXT,
                page_url TEXT,
                thumbnail_url TEXT,
                duration TEXT,
                FOREIGN KEY (anime_slug) REFERENCES anime (slug) ON DELETE CASCADE
            )
        """)

        # Settings Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
        """)

        # Seed default settings if empty
        cursor.execute("SELECT COUNT(*) FROM settings")
        if cursor.fetchone()[0] == 0:
            default_settings = {
                "llm_provider": "lmstudio", # 'lmstudio' or 'ollama'
                "lmstudio_url": "http://localhost:1234/v1",
                "lmstudio_model": "auto",
                "ollama_url": "http://localhost:11434",
                "ollama_model": "auto"
            }
            for k, v in default_settings.items():
                cursor.execute("INSERT INTO settings (key, value) VALUES (?, ?)", (k, v))

        # Check if anime is empty, seed samples so user can test immediately
        cursor.execute("SELECT COUNT(*) FROM anime")
        if cursor.fetchone()[0] == 0:
            seed_sample_data(cursor)

        conn.commit()

def seed_sample_data(cursor):
    sample_animes = [
        {
            "slug": "frieren-beyond-journeys-end",
            "title": "คำอธิษฐานในวันที่จากลา FRIEREN (Sousou no Frieren)",
            "cover_url": "https://m.media-amazon.com/images/M/MV5BMjA5MWVjOGItN2NhOC00Y2U5LTg0MzctNWVmM2M5ODAzOWI2XkEyXkFqcGc@._V1_FMjpg_UX1000_.jpg",
            "backdrop_url": "https://images.alphacoders.com/133/1338522.jpeg",
            "synopsis": "เรื่องราวหลังการผจญภัยอันยาวนาน 10 ปีของกลุ่มผู้กล้าที่ปราบราชาปีศาจลงได้ ฟรีเรน เมจเอลฟ์ผู้มีอายุยืนยาวนับพันปี ได้ออกเดินทางครั้งใหม่เพื่อเรียนรู้และเข้าใจหัวใจของผู้คน",
            "genres": json.dumps(["Fantasy", "Adventure", "Drama", "Magic"]),
            "rating": "9.1",
            "status": "จบแล้ว (28 ตอน)",
            "year": "2023",
            "source_url": "https://example.com/frieren",
            "episodes": [
                {
                    "id": "frieren-ep-1",
                    "episode_number": 1.0,
                    "title": "ตอนที่ 1: จุดสิ้นสุดของการผจญภัย",
                    "stream_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                    "thumbnail_url": "https://images.alphacoders.com/133/1338522.jpeg",
                    "duration": "24:15"
                },
                {
                    "id": "frieren-ep-2",
                    "episode_number": 2.0,
                    "title": "ตอนที่ 2: มันไม่ใช่เวทมนตร์จริงๆ หรอก",
                    "stream_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                    "thumbnail_url": "https://images.alphacoders.com/133/1338522.jpeg",
                    "duration": "24:20"
                },
                {
                    "id": "frieren-ep-3",
                    "episode_number": 3.0,
                    "title": "ตอนที่ 3: เวทมนตร์สังหาร",
                    "stream_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                    "thumbnail_url": "https://images.alphacoders.com/133/1338522.jpeg",
                    "duration": "24:10"
                }
            ]
        },
        {
            "slug": "solo-leveling-s1",
            "title": "Solo Leveling (ชะตากรรมนักล่า)",
            "cover_url": "https://m.media-amazon.com/images/M/MV5BMjA3Y2NmNmEtOGE1ZS00MTM1LWExMGYtOGY3ZTNjNjVhOWU5XkEyXkFqcGc@._V1_.jpg",
            "backdrop_url": "https://images7.alphacoders.com/134/1349544.jpeg",
            "synopsis": "ซงจินอู ฮันเตอร์ระดับ E ผู้ที่อ่อนแอที่สุดในโลก ถูกทิ้งให้ตายในดันเจี้ยนสองชั้นสุดอันตราย ทว่าก่อนหมดลมหายใจ เขาได้รับภารกิจลับที่ทำให้เขาสามารถเลเวลอัปได้เพียงคนเดียวในโลก",
            "genres": json.dumps(["Action", "Fantasy", "Supernatural"]),
            "rating": "8.5",
            "status": "จบแล้ว (12 ตอน)",
            "year": "2024",
            "source_url": "https://example.com/sololeveling",
            "episodes": [
                {
                    "id": "solo-ep-1",
                    "episode_number": 1.0,
                    "title": "ตอนที่ 1: ฉันชินกับมันแล้ว",
                    "stream_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
                    "thumbnail_url": "https://images7.alphacoders.com/134/1349544.jpeg",
                    "duration": "23:45"
                },
                {
                    "id": "solo-ep-2",
                    "episode_number": 2.0,
                    "title": "ตอนที่ 2: หากฉันมีโอกาสอีกครั้ง",
                    "stream_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
                    "thumbnail_url": "https://images7.alphacoders.com/134/1349544.jpeg",
                    "duration": "24:00"
                }
            ]
        }
    ]

    for a in sample_animes:
        cursor.execute("""
            INSERT OR REPLACE INTO anime (slug, title, cover_url, backdrop_url, synopsis, genres, rating, status, year, source_url)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (a["slug"], a["title"], a["cover_url"], a["backdrop_url"], a["synopsis"], a["genres"], a["rating"], a["status"], a["year"], a["source_url"]))

        for ep in a["episodes"]:
            cursor.execute("""
                INSERT OR REPLACE INTO episodes (id, anime_slug, episode_number, title, stream_url, thumbnail_url, duration)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (ep["id"], a["slug"], ep["episode_number"], ep["title"], ep["stream_url"], ep["thumbnail_url"], ep["duration"]))

def get_settings() -> Dict[str, str]:
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT key, value FROM settings")
        rows = cursor.fetchall()
        return {row["key"]: row["value"] for row in rows}

def save_settings(new_settings: Dict[str, str]):
    with get_db() as conn:
        cursor = conn.cursor()
        for k, v in new_settings.items():
            cursor.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", (k, str(v)))
        conn.commit()

def get_all_anime() -> List[Dict[str, Any]]:
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM anime ORDER BY updated_at DESC")
        anime_rows = cursor.fetchall()
        
        result = []
        for a in anime_rows:
            a_dict = dict(a)
            try:
                a_dict["genres"] = json.loads(a_dict["genres"]) if a_dict["genres"] else []
            except Exception:
                a_dict["genres"] = [g.strip() for g in a_dict["genres"].split(",") if g.strip()]

            # Fetch episodes
            cursor.execute("SELECT * FROM episodes WHERE anime_slug = ? ORDER BY episode_number ASC", (a["slug"],))
            ep_rows = cursor.fetchall()
            a_dict["episodes"] = [dict(ep) for ep in ep_rows]
            a_dict["episode_count"] = len(ep_rows)
            result.append(a_dict)
        return result

def get_anime_by_slug(slug: str) -> Optional[Dict[str, Any]]:
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM anime WHERE slug = ?", (slug,))
        row = cursor.fetchone()
        if not row:
            return None
        a_dict = dict(row)
        try:
            a_dict["genres"] = json.loads(a_dict["genres"]) if a_dict["genres"] else []
        except Exception:
            a_dict["genres"] = [g.strip() for g in a_dict["genres"].split(",") if g.strip()]

        cursor.execute("SELECT * FROM episodes WHERE anime_slug = ? ORDER BY episode_number ASC", (slug,))
        ep_rows = cursor.fetchall()
        a_dict["episodes"] = [dict(ep) for ep in ep_rows]
        return a_dict

def get_anime_by_source_url(source_url: str) -> Optional[Dict[str, Any]]:
    if not source_url:
        return None
    normalized = source_url.strip().rstrip("/")
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT slug FROM anime WHERE RTRIM(source_url, '/') = ?", (normalized,))
        row = cursor.fetchone()
        if row:
            return get_anime_by_slug(row["slug"])
    return None

def save_anime(data: Dict[str, Any]) -> Dict[str, Any]:
    with get_db() as conn:
        cursor = conn.cursor()
        slug = data["slug"]
        source_url = (data.get("source_url") or "").strip()

        # Check if anime already exists by slug or by source_url (only if slug has no specific sub/dub suffix)
        existing = get_anime_by_slug(slug)
        if not existing and source_url and not (slug.endswith("-sub") or slug.endswith("-dub")):
            existing = get_anime_by_source_url(source_url)
            if existing:
                slug = existing["slug"]
                data["slug"] = slug

        # Merge episodes if existing
        incoming_eps = data.get("episodes", [])
        if existing:
            existing_eps = {ep["episode_number"]: ep for ep in existing.get("episodes", [])}
            new_added = 0
            updated_streams = 0

            # Merge: update existing with new stream_urls or add new episodes
            for ep in incoming_eps:
                num = float(ep.get("episode_number", 1.0))
                if num in existing_eps:
                    # Update stream_url or title if existing had none
                    if ep.get("stream_url") and not existing_eps[num].get("stream_url"):
                        existing_eps[num]["stream_url"] = ep["stream_url"]
                        updated_streams += 1
                    if ep.get("page_url") and not existing_eps[num].get("page_url"):
                        existing_eps[num]["page_url"] = ep["page_url"]
                else:
                    existing_eps[num] = ep
                    new_added += 1

            # Sorted merged episodes
            merged_eps = [existing_eps[k] for k in sorted(existing_eps.keys())]
            data["episodes"] = merged_eps

            # If no new episode added and no stream was updated and anime already existed:
            if new_added == 0 and updated_streams == 0 and len(existing.get("episodes", [])) > 0:
                print(f"[DB] No updates detected for '{slug}' (Episodes: {len(merged_eps)}). Skipping write.")
                return existing

        genres_json = json.dumps(data.get("genres", []))
        cursor.execute("""
            INSERT OR REPLACE INTO anime (slug, title, cover_url, backdrop_url, synopsis, genres, rating, status, year, source_url, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        """, (
            slug,
            data.get("title", existing.get("title") if existing else "Untitled"),
            data.get("cover_url", existing.get("cover_url") if existing else ""),
            data.get("backdrop_url", existing.get("backdrop_url") if existing else ""),
            data.get("synopsis", existing.get("synopsis") if existing else ""),
            genres_json,
            data.get("rating", existing.get("rating") if existing else "N/A"),
            data.get("status", existing.get("status") if existing else ""),
            data.get("year", existing.get("year") if existing else ""),
            source_url or (existing.get("source_url") if existing else "")
        ))

        # Clear existing episodes for clean update
        cursor.execute("DELETE FROM episodes WHERE anime_slug = ?", (slug,))

        seen_ids = set()
        for idx, ep in enumerate(data.get("episodes", []), 1):
            ep_num = ep.get("episode_number", idx)
            try:
                num_val = float(ep_num)
                num_str = str(int(num_val)) if num_val.is_integer() else str(num_val)
            except Exception:
                num_val = float(idx)
                num_str = str(idx)

            raw_id = ep.get("id")
            if not raw_id:
                raw_id = f"{slug}-ep-{num_str}"
            elif not raw_id.startswith(f"{slug}-"):
                raw_id = f"{slug}-{raw_id}"

            ep_id = raw_id
            counter = 1
            while ep_id in seen_ids:
                counter += 1
                ep_id = f"{raw_id}-{counter}"
            seen_ids.add(ep_id)

            cursor.execute("""
                INSERT OR REPLACE INTO episodes (id, anime_slug, episode_number, title, stream_url, page_url, thumbnail_url, duration)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                ep_id,
                slug,
                num_val,
                ep.get("title", f"ตอนที่ {num_str}"),
                ep.get("stream_url", ""),
                ep.get("page_url", ""),
                ep.get("thumbnail_url", data.get("cover_url", "")),
                ep.get("duration", "")
            ))

        conn.commit()
    return get_anime_by_slug(slug)

def delete_anime(slug: str) -> bool:
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM anime WHERE slug = ?", (slug,))
        cursor.execute("DELETE FROM episodes WHERE anime_slug = ?", (slug,))
        conn.commit()
        return True
