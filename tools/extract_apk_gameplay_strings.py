#!/usr/bin/env python3
"""Extract gameplay-looking strings from APK binaries."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


ASCII_STRING = re.compile(rb"[ -~]{4,}")
DEFAULT_TERMS = (
    "coin",
    "dinars",
    "energy",
    "oil",
    "population",
    "phase",
    "goal",
    "souk",
    "farm",
    "business",
    "residential",
    "tourist",
    "worker",
    "goods",
)


def extract(path: Path, terms: tuple[str, ...]) -> list[str]:
    if not path.exists():
        return []

    data = path.read_bytes()
    byte_terms = [term.encode("ascii") for term in terms]
    found: list[str] = []

    for match in ASCII_STRING.finditer(data):
        value = match.group(0)
        lower = value.lower()
        if any(term in lower for term in byte_terms):
            found.append(value.decode("latin1", "ignore"))

    return sorted(set(found))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk-root", default="apk-extracted", type=Path)
    parser.add_argument("--limit", default=200, type=int)
    args = parser.parse_args()

    paths = [
        args.apk_root / "classes.dex",
        args.apk_root / "lib" / "armeabi-v7a" / "libgame.so",
    ]

    for path in paths:
        found = extract(path, DEFAULT_TERMS)
        print(f"\n{path} ({len(found)} matches)")
        for value in found[: args.limit]:
            print(value)
        if len(found) > args.limit:
            print(f"... {len(found) - args.limit} more")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
