#!/usr/bin/env python3
"""Uploads the manually-chosen exercise videos (output/<slug>/chosen.mp4)
to the `exercise-videos` public bucket in Supabase Storage, one object per
exercise slug (exercise-videos/<slug>.mp4).

Run this on your own machine — Supabase's API is not reachable from the
agent sandbox that wrote this script, and this needs the project's
service_role key, which should never be pasted into a chat or committed.

Usage:

    export SUPABASE_URL=https://<your-project-ref>.supabase.co
    export SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
    pip install -r requirements.txt
    python upload_to_supabase.py

Safe to re-run: uploads use x-upsert, so an exercise already uploaded is
simply overwritten with the current local file, never duplicated.
"""

import os
import sys
from pathlib import Path

import requests

from exercises import EXERCISES

BUCKET = "exercise-videos"
OUTPUT_DIR = Path(__file__).parent / "output"
REQUEST_TIMEOUT_SECONDS = 60
# Matches this project's local Supabase Storage default (supabase/config.toml);
# the hosted project may enforce the same or a different limit — checking
# here just gives a clear, per-file error instead of an opaque API failure.
MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024


def upload_file(base_url: str, service_role_key: str, slug: str, file_path: Path) -> None:
    with open(file_path, "rb") as f:
        response = requests.post(
            f"{base_url}/storage/v1/object/{BUCKET}/{slug}.mp4",
            headers={
                "Authorization": f"Bearer {service_role_key}",
                "apikey": service_role_key,
                "Content-Type": "video/mp4",
                "x-upsert": "true",
            },
            data=f,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
    response.raise_for_status()


def main() -> None:
    base_url = os.environ.get("SUPABASE_URL")
    service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not base_url or not service_role_key:
        print("Erro: defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY antes de rodar.")
        print("(Project Settings -> API Keys no painel do Supabase; a service_role")
        print("key nunca deve ser colada no chat nem commitada.)")
        sys.exit(1)
    base_url = base_url.rstrip("/")

    known_slugs = [slug for slug, _, _ in EXERCISES]
    uploaded: list[str] = []
    skipped_no_file: list[str] = []
    too_large: list[str] = []
    failed: list[str] = []

    total = len(known_slugs)
    for index, slug in enumerate(known_slugs, start=1):
        chosen_path = OUTPUT_DIR / slug / "chosen.mp4"
        if not chosen_path.exists():
            skipped_no_file.append(slug)
            continue

        size = chosen_path.stat().st_size
        if size > MAX_FILE_SIZE_BYTES:
            print(
                f"[{index}/{total}] {slug}: arquivo tem {size / 1024 / 1024:.1f}MiB, "
                f"acima do limite de {MAX_FILE_SIZE_BYTES / 1024 / 1024:.0f}MiB — pulado."
            )
            too_large.append(slug)
            continue

        print(f"[{index}/{total}] {slug}: enviando...")
        try:
            upload_file(base_url, service_role_key, slug, chosen_path)
        except requests.RequestException as exc:
            print(f"  Erro: {exc}")
            failed.append(slug)
            continue
        uploaded.append(slug)

    print(f"\n{len(uploaded)} vídeo(s) enviado(s) com sucesso.")
    print(f"{len(skipped_no_file)} exercício(s) sem chosen.mp4 (esperado para os não escolhidos).")
    if too_large:
        print(f"{len(too_large)} arquivo(s) acima do limite de tamanho: {', '.join(too_large)}")
    if failed:
        print(f"{len(failed)} falha(s) de upload: {', '.join(failed)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
