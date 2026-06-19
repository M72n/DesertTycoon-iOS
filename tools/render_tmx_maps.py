#!/usr/bin/env python3
"""Render orthogonal TMX tile maps into PNG files.

The original APK stores phase maps as small tileset images plus TMX metadata.
SpriteKit does not load TMX directly, so this script generates stable composite
map PNGs that the iOS runtime can display without inventing map layout.
"""

from __future__ import annotations

import argparse
import base64
import gzip
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image


GID_MASK = 0x1FFFFFFF


def decode_layer_data(data_element: ET.Element, expected_count: int) -> list[int]:
    encoding = data_element.attrib.get("encoding")
    compression = data_element.attrib.get("compression")
    payload = "".join((data_element.text or "").split())

    if encoding != "base64" or compression != "gzip":
        raise ValueError(f"Unsupported TMX layer encoding: {encoding=} {compression=}")

    raw = gzip.decompress(base64.b64decode(payload))
    values = list(struct.unpack("<" + "I" * (len(raw) // 4), raw))
    if len(values) != expected_count:
        raise ValueError(f"Expected {expected_count} gids, got {len(values)}")

    return [value & GID_MASK for value in values]


def render_tmx(tmx_path: Path, output_path: Path) -> None:
    tree = ET.parse(tmx_path)
    root = tree.getroot()

    if root.attrib.get("orientation") != "orthogonal":
        raise ValueError(f"Only orthogonal maps are supported: {tmx_path}")

    map_width = int(root.attrib["width"])
    map_height = int(root.attrib["height"])
    tile_width = int(root.attrib["tilewidth"])
    tile_height = int(root.attrib["tileheight"])

    tileset = root.find("tileset")
    if tileset is None:
        raise ValueError(f"Missing tileset: {tmx_path}")

    first_gid = int(tileset.attrib.get("firstgid", "1"))
    source_image = tileset.find("image")
    if source_image is None:
        raise ValueError(f"Missing tileset image: {tmx_path}")

    source_path = tmx_path.parent / source_image.attrib["source"]
    tileset_image = Image.open(source_path).convert("RGBA")
    columns = max(1, tileset_image.width // tile_width)

    output = Image.new("RGBA", (map_width * tile_width, map_height * tile_height), (0, 0, 0, 0))

    for layer in root.findall("layer"):
        data_element = layer.find("data")
        if data_element is None:
            continue

        gids = decode_layer_data(data_element, map_width * map_height)
        for index, gid in enumerate(gids):
            if gid == 0:
                continue

            tile_index = gid - first_gid
            if tile_index < 0:
                continue

            source_x = (tile_index % columns) * tile_width
            source_y = (tile_index // columns) * tile_height
            tile_box = (source_x, source_y, source_x + tile_width, source_y + tile_height)
            tile = tileset_image.crop(tile_box)

            destination_x = (index % map_width) * tile_width
            destination_y = (index // map_width) * tile_height
            output.alpha_composite(tile, (destination_x, destination_y))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(output_path, optimize=True)
    print(f"rendered {tmx_path.name} -> {output_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--maps-dir", required=True, type=Path, help="Directory containing DT_Phase*_ortho.tmx")
    parser.add_argument("--output-dir", required=True, type=Path, help="Directory for rendered PNG maps")
    args = parser.parse_args()

    tmx_files = sorted(args.maps_dir.glob("DT_Phase*_ortho.tmx"))
    if not tmx_files:
        print(f"No orthogonal TMX maps found under {args.maps_dir}")
        return 1

    for tmx_path in tmx_files:
        output_name = tmx_path.stem + "_full.png"
        render_tmx(tmx_path, args.output_dir / output_name)

    print(f"Rendered {len(tmx_files)} map files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
