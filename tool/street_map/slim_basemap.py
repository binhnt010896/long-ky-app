#!/usr/bin/env python3
"""Slims the street map's base map (a Protomaps PMTiles extract) without touching its geometry.

  python3 tool/street_map/slim_basemap.py [--max-zoom 14] [--drop pois] [IN [OUT]]

What it does, and why (docs/wave-e-plan.md, S3):
  - drops tile layers the app's theme never draws (`pois` is hidden — see
    kHiddenBasemapLayers in apps/mobile/lib/screens/streets/street_basemap.dart);
  - drops zooms above --max-zoom (default 14): the app over-zooms the last level, and z15 was
    ~47% of the file and 74% of all tiles. At zoom 15–17 a z14 tile is stretched instead of
    four z15 tiles being fetched.

Tiles are filtered at the protobuf level (whole layer messages removed), so everything that
stays is byte-for-byte what Protomaps produced — no decode/re-encode, no geometry drift.

Needs:  pip install pmtiles
IN defaults to content/streets/hcm-basemap.pmtiles; OUT to build/basemap/hcm-basemap.slim.pmtiles.
Review the result, then copy it over content/streets/hcm-basemap.pmtiles, run
tool/push_sources.sh and publish (the media manifest's version changes, so phones fetch it
fresh and start a new tile cache).
"""
import argparse
import gzip
import os
import sys

from pmtiles.reader import MmapSource, Reader, all_tiles
from pmtiles.tile import Compression, TileType, tileid_to_zxy, zxy_to_tileid
from pmtiles.writer import write


def _varint(buf, i):
    shift = 0
    n = 0
    while True:
        b = buf[i]
        i += 1
        n |= (b & 0x7F) << shift
        if not b & 0x80:
            return n, i
        shift += 7


def _layer_name(payload):
    """Layer.name is field 1 (tag 0x0A), written first by every MVT encoder we meet."""
    i = 0
    while i < len(payload):
        tag, i = _varint(payload, i)
        field, wire = tag >> 3, tag & 7
        if wire == 2:
            ln, i = _varint(payload, i)
            if field == 1:
                return payload[i:i + ln].decode('utf-8', 'replace')
            i += ln
        elif wire == 0:
            _, i = _varint(payload, i)
        elif wire == 1:
            i += 8
        elif wire == 5:
            i += 4
        else:
            raise ValueError(f'unsupported wire type {wire}')
    return ''


def drop_layers(tile, names):
    """Removes whole `layers` (field 3) named in [names] from an uncompressed MVT tile."""
    out = bytearray()
    i = 0
    while i < len(tile):
        start = i
        tag, i = _varint(tile, i)
        field, wire = tag >> 3, tag & 7
        if wire == 2:
            ln, i = _varint(tile, i)
            payload = tile[i:i + ln]
            i += ln
            if field == 3 and _layer_name(payload) in names:
                continue
            out += tile[start:i]
        elif wire == 0:
            _, i = _varint(tile, i)
            out += tile[start:i]
        else:
            raise ValueError(f'unsupported wire type {wire} at top level')
    return bytes(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src', nargs='?', default='content/streets/hcm-basemap.pmtiles')
    ap.add_argument('dst', nargs='?', default='build/basemap/hcm-basemap.slim.pmtiles')
    ap.add_argument('--max-zoom', type=int, default=14)
    ap.add_argument('--drop', default='pois', help='comma-separated tile layers to remove')
    a = ap.parse_args()
    drop = {s for s in a.drop.split(',') if s}
    os.makedirs(os.path.dirname(a.dst) or '.', exist_ok=True)

    with open(a.src, 'rb') as f:
        reader = Reader(MmapSource(f))
        header = reader.header()
        metadata = reader.metadata()
        if header['tile_type'] != TileType.MVT:
            sys.exit('not a vector tile archive')
        gz = header['tile_compression'] == Compression.GZIP
        kept = 0
        before = after = 0
        with write(a.dst) as writer:
            for (z, x, y), data in all_tiles(MmapSource(f)):
                before += len(data)
                if z > a.max_zoom:
                    continue
                raw = gzip.decompress(data) if gz else data
                slim = drop_layers(raw, drop) if drop else raw
                out = gzip.compress(slim, 9, mtime=0) if gz else slim
                writer.write_tile(zxy_to_tileid(z, x, y), out)
                after += len(out)
                kept += 1
            header = dict(header)
            header['max_zoom'] = min(header['max_zoom'], a.max_zoom)
            if isinstance(metadata.get('vector_layers'), list):
                metadata['vector_layers'] = [l for l in metadata['vector_layers'] if l.get('id') not in drop]
            if 'maxzoom' in metadata:
                metadata['maxzoom'] = str(header['max_zoom'])
            writer.finalize(header, metadata)

    print(f'{kept} tiles kept; tile bytes {before/1e6:.1f} MB -> {after/1e6:.1f} MB; '
          f'file {os.path.getsize(a.src)/1e6:.1f} MB -> {os.path.getsize(a.dst)/1e6:.1f} MB')


if __name__ == '__main__':
    main()
