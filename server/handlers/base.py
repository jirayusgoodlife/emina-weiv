from abc import ABC, abstractmethod
from typing import Dict, Any, List, Optional
from bs4 import BeautifulSoup
import httpx
from urllib.parse import urlparse

class BaseSiteHandler(ABC):
    """
    Base class for anime website adapters.
    Each website can implement its own extraction and stream resolution logic.
    """
    name: str = "BaseHandler"
    domains: List[str] = []

    def can_handle(self, url: str, html: Optional[str] = None) -> bool:
        """Check if this handler can process the given URL or HTML content."""
        if not url:
            return False
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        if domain.startswith("www."):
            domain = domain[4:]
        
        for d in self.domains:
            d_clean = d.lower()
            if d_clean.startswith("www."):
                d_clean = d_clean[4:]
            if domain == d_clean or domain.endswith("." + d_clean):
                return True
        return False

    def extract_anime(self, url: str, html: str, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        """
        Extract anime metadata and episode list from the main anime page.
        Returns a dictionary adhering to the catalog schema or None to fallback to generic heuristics.
        """
        return None

    async def resolve_stream(
        self,
        page_url: str,
        html: str,
        soup: BeautifulSoup,
        client: httpx.AsyncClient,
        settings: Optional[Dict[str, str]] = None
    ) -> Optional[str]:
        """
        Resolve the direct playable video stream URL (.mp4, .m3u8) from the episode page.
        Returns the stream URL string or None if unresolvable.
        """
        return None
