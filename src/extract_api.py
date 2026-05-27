"""Optional API extract jobs; writes raw files under data/raw/."""

from pathlib import Path

import requests

from src.config import DATA_RAW_DIR


def fetch_and_save(url: str, filename: str) -> Path:
    """Download JSON from URL and save under data/raw/."""
    out_path = DATA_RAW_DIR / filename
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    out_path.write_bytes(response.content)
    return out_path


if __name__ == "__main__":
    print("Configure API endpoints in this module when needed.")
