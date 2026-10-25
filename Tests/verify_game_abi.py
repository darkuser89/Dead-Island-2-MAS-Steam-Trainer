# SPDX-License-Identifier: GPL-3.0-only
"""Read-only verification of both exact game builds and their shared native ABI."""
from pathlib import Path
import hashlib
import json
import mmap
import os
import re
import struct
import subprocess
import sys

root = Path(sys.argv[1])
definition = json.loads((root / 'Resources/GameABI.json').read_text())
source = (root / 'Sources/GameAccess.m').read_text()
bindings = {field: int(address, 16) for field, address in re.findall(r'BIND\((\w+),\s*(0x[0-9a-fA-F]+)\)', source)}
tables = {int(index): int(address, 16) for index, address in re.findall(
    r'api->ingredientVTables\[(\d)\]=\(void \*\)\((0x[0-9a-fA-F]+)ULL\+16\+slide\)', source)}
if set(bindings) != set(definition['bindings']):
    raise SystemExit('Every native binding must have an ABI definition.')
for field, entry in definition['bindings'].items():
    if bindings[field] != int(entry['address'], 16):
        raise SystemExit(f'Native binding definition mismatch: {field}')
for index, entry in enumerate(definition['crafting_tables']):
    if tables.get(index) != int(entry['address'], 16):
        raise SystemExit(f'Crafting table definition mismatch: {index}')

required = {entry['symbol'] for entry in definition['bindings'].values()}
required.update(entry['symbol'] for entry in definition['crafting_tables'])
for profile in definition['profiles']:
    override = os.environ.get(f"DI2_ABI_{profile['edition'].upper()}_APP")
    game = Path(override or profile['default_path']).expanduser() / 'Contents/MacOS/DeadIsland2'
    if not game.is_file():
        print(f"{profile['edition']}: installed-build check not performed (not mounted/installed).")
        continue
    uuid = subprocess.check_output(['xcrun', 'dwarfdump', '--uuid', str(game)], text=True)
    if profile['uuid'] not in uuid:
        print(f"{profile['edition']}: installed-build check not performed (unknown UUID; runtime stays blocked).")
        continue
    symbols = {}
    process = subprocess.Popen(['/usr/bin/nm', '-nm', str(game)], stdout=subprocess.PIPE, text=True)
    for line in process.stdout:
        parts = line.split()
        if parts and parts[-1] in required:
            symbols[parts[-1]] = int(parts[0], 16)
    if process.wait():
        raise SystemExit(f"{profile['edition']}: could not read native symbols")
    for entry in [*definition['bindings'].values(), *definition['crafting_tables']]:
        if symbols.get(entry['symbol']) != int(entry['address'], 16):
            raise SystemExit(f"{profile['edition']}: ABI mismatch for {entry['symbol']}")
    sections = {}
    with game.open('rb') as handle, mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as data:
        ncmds = struct.unpack_from('<I', data, 16)[0]
        offset = 32
        for _ in range(ncmds):
            command, length = struct.unpack_from('<II', data, offset)
            if command == 0x19:
                count = struct.unpack_from('<I', data, offset + 64)[0]
                for index in range(count):
                    base = offset + 72 + index * 80
                    name = data[base:base + 16].rstrip(b'\0').decode()
                    segment = data[base + 16:base + 32].rstrip(b'\0').decode()
                    key = f'{segment},{name}'
                    if key in definition['shared_sections']:
                        address, size, file_offset = struct.unpack_from('<QQI', data, base + 32)
                        view = memoryview(data)[file_offset:file_offset + size]
                        digest = hashlib.sha256(view).hexdigest()
                        del view
                        sections[key] = {'address': hex(address), 'size': size, 'sha256': digest}
            offset += length
    if sections != definition['shared_sections']:
        raise SystemExit(f"{profile['edition']}: code/reflection/data sections differ from the shared ABI")
    print(f"{profile['edition']}: 95 bindings, three crafting tables and three shared code/data hashes checked ({profile['uuid']}).")
