import unittest
from fastapi.testclient import TestClient
import sys
import os

# Add server directory to sys.path
sys.path.insert(0, os.path.dirname(__file__))

from main import app
from db import get_all_anime, get_anime_by_slug

class TestUpdateAll(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_get_anime_catalog(self):
        res = self.client.get("/api/anime")
        self.assertEqual(res.status_code, 200)
        animes = res.json()
        self.assertIsInstance(animes, list)
        self.assertGreater(len(animes), 0)

    def test_single_update_episodes(self):
        animes = get_all_anime()
        target = next((a for a in animes if a.get("source_url")), None)
        self.assertIsNotNone(target, "Should have at least one anime with source_url")

        res = self.client.post(f"/api/anime/{target['slug']}/update_episodes")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn(data.get("status"), ["up_to_date", "updated"])
        self.assertEqual(data.get("slug"), target["slug"])

    def test_batch_update_all_filter_slugs(self):
        animes = get_all_anime()
        target = next((a for a in animes if a.get("source_url")), None)
        self.assertIsNotNone(target)

        res = self.client.post("/api/anime/update_all", json={"slugs": [target["slug"]]})
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data.get("status"), "ok")
        self.assertEqual(data.get("total_checked"), 1)
        self.assertEqual(len(data.get("results")), 1)

    def test_update_all_stream(self):
        animes = get_all_anime()
        target = next((a for a in animes if a.get("source_url")), None)
        self.assertIsNotNone(target)

        with self.client.stream("POST", "/api/anime/update_all_stream", json={"slugs": [target["slug"]]}) as resp:
            self.assertEqual(resp.status_code, 200)
            lines = [l for l in resp.iter_lines() if l]
            self.assertTrue(any("start" in l for l in lines))
            self.assertTrue(any("checking" in l for l in lines))
            self.assertTrue(any("item_done" in l for l in lines))
            self.assertTrue(any("complete" in l for l in lines))

if __name__ == "__main__":
    unittest.main()
