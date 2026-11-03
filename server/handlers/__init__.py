import os
from typing import List, Dict, Any, Optional
from bs4 import BeautifulSoup
import httpx

from .base import BaseSiteHandler
from .anifume import AnifumeHandler
from .alphahen import AlphaHenHandler
from .dooplay import DooPlayHandler
from .animenani import AnimenaniHandler
from .fairyanime import FairyAnimeHandler
from .animeruka import AnimeRukaHandler
from .animewaku import AnimeWakuHandler
from .wowdrama import WowDramaHandler
from .halim import HalimHandler
from .custom_rules import load_custom_rules
from .generic import GenericHandler

CONFIG_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "custom_sites.json")

def get_all_handlers() -> List[BaseSiteHandler]:
    """Returns all registered handlers in priority order."""
    handlers: List[BaseSiteHandler] = [
        AnifumeHandler(),
        AlphaHenHandler(),
        HalimHandler(),
        DooPlayHandler(),
        AnimenaniHandler(),
        FairyAnimeHandler(),
        AnimeRukaHandler(),
        AnimeWakuHandler(),
        WowDramaHandler(),
    ]
    
    # Load dynamic user-defined site rules
    if os.path.exists(CONFIG_FILE):
        custom_handlers = load_custom_rules(CONFIG_FILE)
        handlers.extend(custom_handlers)

    # Generic fallback handler is always last
    handlers.append(GenericHandler())
    return handlers

def get_handler_for_url(url: str, html: Optional[str] = None) -> BaseSiteHandler:
    """Finds the first handler that can handle the URL or HTML."""
    handlers = get_all_handlers()
    for h in handlers:
        if h.name != "Universal Generic Handler" and h.can_handle(url, html=html):
            return h
    return handlers[-1] # GenericHandler fallback

def list_supported_sites() -> List[Dict[str, Any]]:
    """Lists all explicitly supported websites and engines."""
    handlers = get_all_handlers()
    results = []
    for h in handlers:
        if h.name != "Universal Generic Handler":
            results.append({
                "name": h.name,
                "domains": h.domains,
            })
    return results
