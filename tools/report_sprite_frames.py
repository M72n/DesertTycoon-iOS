#!/usr/bin/env python3
"""Print frame names from Cocos2d/TexturePacker plist files."""

from __future__ import annotations

import argparse
import plistlib
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="ios-scaffold/Resources/LegacyAssets/iphone-hd", type=Path)
    parser.add_argument("--limit", default=120, type=int)
    parser.add_argument("--filter", default="", help="Case-insensitive frame-name filter")
    args = parser.parse_args()

    query = args.filter.lower()
    total = 0

    for plist_path in sorted(args.root.rglob("*.plist")):
        with plist_path.open("rb") as handle:
            data = plistlib.load(handle)

        frames = sorted(data.get("frames", {}).keys())
        if query:
            frames = [frame for frame in frames if query in frame.lower()]

        if not frames:
            continue

        all_frames = data.get("frames", {})
        rotated_count = sum(1 for frame in all_frames.values() if frame.get("rotated") is True)
        print(f"\n{plist_path.relative_to(args.root)} ({len(frames)} frames, {rotated_count} rotated)")
        for frame in frames[: args.limit]:
            print(f"  {frame}")
        if len(frames) > args.limit:
            print(f"  ... {len(frames) - args.limit} more")
        total += len(frames)

    print(f"\nTotal listed frames: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
