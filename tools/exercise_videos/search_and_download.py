#!/usr/bin/env python3
"""Downloads a handful of candidate stock-video clips per exercise from the
Pexels API, so exercise-demonstration videos can be picked once and shipped
with the app instead of generated per-user at runtime.

Usage (run on your own machine — api.pexels.com is not reachable from the
agent sandbox that wrote this script):

    export PEXELS_API_KEY=your-key-from-pexels.com/api
    pip install -r requirements.txt
    python search_and_download.py

Re-running is safe: any exercise whose output folder already has a
candidate_*.mp4 is skipped, so an interrupted run can just be restarted.
"""

import json
import os
import sys
import time
from pathlib import Path
from urllib.parse import urlencode

import requests

from exercises import EXERCISES

API_URL = "https://api.pexels.com/videos/search"
OUTPUT_DIR = Path(__file__).parent / "output"
RESULTS_PER_EXERCISE = 3
PAUSE_BETWEEN_EXERCISES_SECONDS = 1.5
REQUEST_TIMEOUT_SECONDS = 30


def pick_video_file(video: dict) -> dict | None:
    """Picks the `hd` quality rendition of a Pexels video result, falling
    back to the smallest available file if no `hd` rendition exists (some
    results only offer `sd`/`hls`)."""
    files = video.get("video_files", [])
    hd_files = [f for f in files if f.get("quality") == "hd"]
    if hd_files:
        return min(hd_files, key=lambda f: f.get("width") or 0)
    if files:
        return min(files, key=lambda f: f.get("width") or 0)
    return None


def already_downloaded(exercise_dir: Path) -> bool:
    return any(exercise_dir.glob("candidate_*.mp4"))


def download_file(url: str, destination: Path) -> None:
    with requests.get(url, stream=True, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        response.raise_for_status()
        with open(destination, "wb") as f:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                f.write(chunk)


def search_exercise(query: str, api_key: str) -> list[dict]:
    params = urlencode({"query": query, "per_page": RESULTS_PER_EXERCISE})
    response = requests.get(
        f"{API_URL}?{params}",
        headers={"Authorization": api_key},
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    response.raise_for_status()
    return response.json().get("videos", [])


def main() -> None:
    api_key = os.environ.get("PEXELS_API_KEY")
    if not api_key:
        print("Erro: defina a variável de ambiente PEXELS_API_KEY antes de rodar.")
        print("Gere uma chave grátis em https://www.pexels.com/api/")
        sys.exit(1)

    OUTPUT_DIR.mkdir(exist_ok=True)
    no_results_path = OUTPUT_DIR / "_sem_resultado.txt"
    no_results: list[str] = []

    total = len(EXERCISES)
    for index, (slug, pt_name, query) in enumerate(EXERCISES, start=1):
        exercise_dir = OUTPUT_DIR / slug
        exercise_dir.mkdir(exist_ok=True)

        if already_downloaded(exercise_dir):
            print(f"[{index}/{total}] {slug}: já baixado, pulando.")
            continue

        print(f"[{index}/{total}] {slug} ({pt_name!r}) — buscando {query!r}...")
        try:
            videos = search_exercise(query, api_key)
        except requests.RequestException as exc:
            print(f"  Erro na busca: {exc}")
            no_results.append(f"{slug}: erro na busca ({exc})")
            time.sleep(PAUSE_BETWEEN_EXERCISES_SECONDS)
            continue

        if not videos:
            print("  Nenhum resultado.")
            no_results.append(f"{slug}: nenhum resultado para {query!r}")
            time.sleep(PAUSE_BETWEEN_EXERCISES_SECONDS)
            continue

        downloaded = 0
        for candidate_index, video in enumerate(videos, start=1):
            video_file = pick_video_file(video)
            if video_file is None or not video_file.get("link"):
                continue

            candidate_path = exercise_dir / f"candidate_{candidate_index}.mp4"
            try:
                download_file(video_file["link"], candidate_path)
            except requests.RequestException as exc:
                print(f"  Erro baixando candidato {candidate_index}: {exc}")
                continue

            meta_path = exercise_dir / f"candidate_{candidate_index}.meta.json"
            meta_path.write_text(
                json.dumps(
                    {
                        "pexels_id": video.get("id"),
                        "pexels_url": video.get("url"),
                        "photographer": video.get("user", {}).get("name"),
                        "photographer_url": video.get("user", {}).get("url"),
                        "width": video_file.get("width"),
                        "height": video_file.get("height"),
                        "quality": video_file.get("quality"),
                        "search_query": query,
                    },
                    indent=2,
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            downloaded += 1

        print(f"  {downloaded} candidato(s) baixado(s).")
        time.sleep(PAUSE_BETWEEN_EXERCISES_SECONDS)

    if no_results:
        no_results_path.write_text("\n".join(no_results) + "\n", encoding="utf-8")
        print(f"\n{len(no_results)} exercício(s) sem resultado — ver {no_results_path}")
    elif no_results_path.exists():
        no_results_path.unlink()

    print("\nConcluído. Revise cada pasta em output/<slug>/ e escolha o melhor")
    print("candidato renomeando-o para chosen.mp4.")


if __name__ == "__main__":
    main()
