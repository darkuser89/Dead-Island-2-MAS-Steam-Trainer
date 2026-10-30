#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Package the tested macOS app outside source and verify a ZIP round trip."""
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile


def run(*args):
    subprocess.run(args, check=True)


def files(root):
    entries = {}
    for path in root.rglob('*'):
        if path.is_symlink():
            raise ValueError(f'Unexpected symlink in app: {path.relative_to(root)}')
        if path.is_file():
            entries[path.relative_to(root)] = (hashlib.sha256(path.read_bytes()).hexdigest(),
                                               path.stat().st_mode & 0o111)
    return entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path)
    parser.add_argument('--expected-tag', default='')
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    info = plistlib.loads((source / 'Resources/Info.plist').read_bytes())
    version = info['CFBundleShortVersionString']
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        raise ValueError('Expected a stable x.y.z version in Info.plist')
    if args.expected_tag and args.expected_tag != f'v{version}':
        raise ValueError(f'Tag {args.expected_tag!r} does not match app version v{version}')
    if args.check_only:
        print(f'Release version checked: {version} (build {info["CFBundleVersion"]})')
        return
    if args.build_dir is None:
        parser.error('--build-dir is required for packaging')
    build = args.build_dir.expanduser().resolve()
    if build == source or source in build.parents:
        raise ValueError('Build folder must be outside source')
    app = build / 'Dead Island 2 Trainer.app'
    built_info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if built_info != info or built_info['CFBundleIdentifier'] != 'local.deadisland2.trainer':
        raise ValueError('Built app metadata does not match the source version')
    run('codesign', '--verify', '--deep', '--strict', str(app))
    for binary in [app / 'Contents/MacOS/Trainer', app / 'Contents/Resources/TrainerOverlay.dylib']:
        if subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip() != 'arm64':
            raise ValueError('Expected an Apple Silicon binary')
        symbols = subprocess.check_output(['nm', '-m', str(binary)], text=True)
        if not any('weak external _OBJC_CLASS_$_NSGlassEffectView' in line for line in symbols.splitlines()):
            raise ValueError('Release binary lacks weak-linked Liquid Glass support; build with macOS SDK 26+')
    release = build / 'Release'
    release.mkdir(exist_ok=True)
    archive = f'Dead-Island-2-Trainer-{version}-macOS-arm64.zip'
    # Keep the prior package until its replacement passes every check.
    with tempfile.TemporaryDirectory(prefix='.package-', dir=build) as temporary:
        temporary = Path(temporary)
        candidate = temporary / archive
        run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(candidate))
        unpacked = temporary / 'unpacked'
        run('ditto', '-x', '-k', str(candidate), str(unpacked))
        restored = unpacked / app.name
        if files(app) != files(restored):
            raise ValueError('ZIP round trip changed files or executable permissions')
        run('codesign', '--verify', '--deep', '--strict', str(restored))
        digest = hashlib.sha256(candidate.read_bytes()).hexdigest()
        os.replace(candidate, release / archive)
    (release / 'SHA256SUMS.txt').write_text(f'{digest}  {archive}\n')
    changes = (source / 'RELEASE_NOTES.md').read_text().strip()
    notes = f'''# Dead Island 2 Trainer {version}

{changes}

## Download und Voraussetzungen

`{archive}` entpacken und „Dead Island 2 Trainer.app“ in Programme verschieben.
Apple Silicon, macOS 14 oder neuer und eine eigene unterstützte Originalinstallation
von Dead Island 2 sind erforderlich. Die freigegebenen Spiel-UUIDs stehen in der README.
Für Steam muss der Client laufen und angemeldet sein. Spiele, Saves und der optionale
externe Uncut-Helfer sind nicht enthalten. Beide Spiele-Apps bleiben unverändert.
Geld, XP und Inventaränderungen können vom Spiel gespeichert werden.

Ad hoc signiert, ohne Developer-ID-Notarisierung; macOS kann den ersten Start blockieren.
`SHA256SUMS.txt` enthält die ZIP-Prüfsumme. Lizenz: GPL-3.0-only.

## Automatische Prüfung

Der Build führt synthetische Engine-/UI-Tests aus. Das Paket wurde entpackt und auf
Dateigleichheit, Ausführungsrechte, arm64-Architektur und gültige Signaturen geprüft.
Auf GitHub sind keine Originalspiele installiert: echte MAS-/Steam-ABI-Abgleiche,
Spielstarts, Ingame-Funktionstests und iCloud-Tests werden dort nicht durchgeführt.
'''
    (release / 'ReleaseNotes.md').write_text(notes)
    if os.environ.get('GITHUB_OUTPUT'):
        with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
            output.write(f'version={version}\narchive={archive}\n')
    print(f'Package verified: {release / archive}\nSHA256: {digest}')


if __name__ == '__main__':
    main()
