"""
Design Tokens - "Casefile" Design System
Single Source of Truth for ResumeAI & Career Copilot
Defines paper-and-ink semantic color palettes used across PDFs, reports, and backend templates.
Mirrored in Flutter frontend at: frontend/lib/core/theme/app_colors.dart

# TODO: swap in Fraunces/JetBrains Mono TTFs in pdf_generator.py
"""
from typing import Dict, Any

# Casefile Light Mode ("Day desk")
LIGHT_TOKENS: Dict[str, str] = {
    "paper": "#EEE9DC",        # background
    "paper_alt": "#E4DDC9",    # cards, elevated surfaces
    "ink": "#211F1A",          # primary text
    "ink_soft": "#6B6455",     # secondary text
    "rule": "#CFC6AE",         # hairline borders/dividers
    "cobalt": "#2C4A7C",       # primary accent (buttons, links, active nav)
    "cobalt_deep": "#1D3660",  # hover/pressed state
    "ochre": "#B8862E",        # in-progress / highlight / warning
    "forest": "#3F6B4A",       # success / verified
    "brick": "#9C3B34",        # error / flagged
}

# Casefile Dark Mode ("Night desk")
DARK_TOKENS: Dict[str, str] = {
    "paper": "#1B1914",
    "paper_alt": "#252119",
    "ink": "#ECE6D6",
    "ink_soft": "#A79C86",
    "rule": "#3A3527",
    "cobalt": "#7EA1DA",
    "cobalt_deep": "#A8C2E8",
    "ochre": "#E0A542",
    "forest": "#7CB88A",
    "brick": "#D9847A",
}

# Default canonical COLORS mapping (Day desk primary, with legacy aliases for ReportLab and templates)
COLORS: Dict[str, str] = {
    # Direct Casefile tokens
    **LIGHT_TOKENS,

    # Semantic Aliases
    "primary": LIGHT_TOKENS["cobalt"],
    "primary_alt": LIGHT_TOKENS["cobalt_deep"],
    "secondary": LIGHT_TOKENS["ochre"],
    "background": LIGHT_TOKENS["paper"],
    "card": LIGHT_TOKENS["paper_alt"],
    "border": LIGHT_TOKENS["rule"],
    "text_primary": LIGHT_TOKENS["ink"],
    "text_secondary": LIGHT_TOKENS["ink_soft"],
    "success": LIGHT_TOKENS["forest"],
    "warning": LIGHT_TOKENS["ochre"],
    "error": LIGHT_TOKENS["brick"],

    # Tints for badges / callouts
    "primary_light": "#E0E8F5",
    "secondary_light": "#F7EDDA",
    "success_light": "#E3EFE6",
    "warning_light": "#F7EDDA",
    "error_light": "#F8E4E2",

    # Dark counterparts for ReportLab dark mode support
    "bg_dark": DARK_TOKENS["paper"],
    "card_dark": DARK_TOKENS["paper_alt"],
    "border_dark": DARK_TOKENS["rule"],
    "text_primary_dark": DARK_TOKENS["ink"],
    "text_secondary_dark": DARK_TOKENS["ink_soft"],
}


def get_reportlab_color(token_name: str, mode: str = "light"):
    """
    Lazily loads ReportLab HexColor to avoid importing reportlab when not needed.
    """
    from reportlab.lib import colors
    palette = DARK_TOKENS if mode == "dark" else COLORS
    hex_code = palette.get(token_name, COLORS.get(token_name, "#000000"))
    return colors.HexColor(hex_code)


class ReportLabTokens:
    """
    Pre-instantiated ReportLab HexColor objects for direct usage in pdf_generator.py.
    """
    _cache: Dict[str, Any] = {}

    @classmethod
    def get(cls, name: str, mode: str = "light"):
        cache_key = f"{name}_{mode}"
        if cache_key not in cls._cache:
            cls._cache[cache_key] = get_reportlab_color(name, mode=mode)
        return cls._cache[cache_key]

    @classmethod
    def all_colors(cls, mode: str = "light") -> Dict[str, Any]:
        return {k: cls.get(k, mode=mode) for k in COLORS}
