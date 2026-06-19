#!/usr/bin/env python3
"""Generate scaled Cocos2d/TexturePacker plist metadata.

This does not modify the original plist files. It reads plist files from an
input asset tree and writes scaled copies to an output tree, preserving relative
paths. Use it when an upscaled spritesheet keeps the exact same layout ratio.
"""

from __future__ import annotations

import argparse
import plistlib
import re
from pathlib import Path
from typing import Any


COCOS_NUMBER_PATTERN = re.compile(r"-?\d+(?:\.\d+)?")


def scale_number(match: re.Match[str], factor: float) -> str:
    value = float(match.group(0)) * factor
    rounded = round(value)
    if abs(value - rounded) < 0.000001:
        return str(int(rounded))
    return f"{value:.4f}".rstrip("0").rstrip(".")


def scale_cocos_string(value: str, factor: float) -> str:
    return COCOS_NUMBER_PATTERN.sub(lambda match: scale_number(match, factor), value)


def scale_node(node: Any, factor: float) -> Any:
    if isinstance(node, dict):
        return {key: scale_node(value, factor) for key, value in node.items()}
    if isinstance(node, list):
        return [scale_node(value, factor) for value in node]
    if isinstance(node, str) and "{" in node and "}" in node:
        return scale_cocos_string(node, factor)
    return node


def scale_plist(source: Path, destination: Path, factor: float) -> None:
    with source.open("rb") as handle:
        data = plistlib.load(handle)

    scaled = scale_node(data, factor)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as handle:
        plistlib.dump(scaled, handle, sort_keys=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path, help="Input asset directory containing .plist files")
    parser.add_argument("--output", required=True, type=Path, help="Output directory for scaled .plist files")
    parser.add_argument("--factor", default=1.875, type=float, help="Coordinate scale factor")
    args = parser.parse_args()

    plist_paths = sorted(args.input.rglob("*.plist"))
    if not plist_paths:
        print(f"No plist files found under {args.input}")
        return 1

    for plist_path in plist_paths:
        relative_path = plist_path.relative_to(args.input)
        scale_plist(plist_path, args.output / relative_path, args.factor)
        print(f"scaled {relative_path}")

    print(f"Generated {len(plist_paths)} scaled plist files in {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
