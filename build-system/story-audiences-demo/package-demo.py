#!/usr/bin/env python3
"""Package an already-built Simulator app and the supplied fixtures for a GitHub Release."""
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
from pathlib import Path

here = Path(__file__).resolve().parent
repo = here.parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--build-revision', type=int, required=True)
args = parser.parse_args()
app = args.app.resolve()
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'design.storyaudiences.native'
assert 'iphonesimulator' in info.get('DTSDKName', '')
arch = subprocess.check_output(['lipo', '-archs', str(app / 'Telegram')], text=True).strip()
assert arch == 'arm64', 'Expected the verified arm64 Simulator app'
name = 'StoryAudiences-offline-demo-arm64-ios27.2'
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)
folder = out / name
folder.mkdir(exist_ok=False)
clone = subprocess.run(['/bin/cp', '-cR', str(app), str(folder / 'Telegram.app')])
if clone.returncode:
    shutil.copytree(app, folder / 'Telegram.app', symlinks=True, dirs_exist_ok=True)
shutil.copytree(here / 'Assets', folder / 'Assets')
for filename in ['run-demo.py', 'Launch Story Audiences.command', 'NOTICE.md']:
    shutil.copy2(here / filename, folder / filename)
shutil.copy2(here / 'DEMO-README.md', folder / 'README.md')
licenses = repo / 'docs/story-audiences/licenses'
if licenses.exists():
    shutil.copytree(licenses, folder / 'licenses')
metadata = {
    'project': 'Story Audiences — unofficial Telegram iOS prototype',
    'source': 'https://github.com/drbvrr/Telegram-iOS/tree/story-audiences',
    'sourceCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
    'upstreamBase': '24638bc69bd083981b178dd1e7f921eebbf7fc46',
    'buildRevision': args.build_revision,
    'architecture': arch,
    'simulatorRuntime': 'iOS 27.2 / iPhone 17 Simulator',
    'sdk': info.get('DTSDKName'),
    'bundleIdentifier': info['CFBundleIdentifier'],
    'appBinarySHA256': hashlib.sha256((app / 'Telegram').read_bytes()).hexdigest(),
    'assetSHA256': {str(p.relative_to(folder / 'Assets')): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((folder / 'Assets').rglob('*')) if p.is_file()},
}
(folder / 'BUILD-INFO.json').write_text(json.dumps(metadata, indent=2) + '\n')
archive = out / (name + '.zip')
subprocess.run(['/usr/bin/ditto', '-c', '-k', '--keepParent', '--noextattr', '--norsrc', str(folder), str(archive)], check=True)
print(archive)
print('Archive bytes:', archive.stat().st_size)
