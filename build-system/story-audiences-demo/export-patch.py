#!/usr/bin/env python3
"""Export the pinned upstream delta without changing the real Git index.

Delivery files are excluded so the patch never recursively contains itself.
"""
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[2]
base = '24638bc69bd083981b178dd1e7f921eebbf7fc46'


def git(args, env=None):
    return subprocess.check_output(['git', '-c', 'filter.lfs.process=', '-c', 'filter.lfs.required=false', *args], cwd=root, env=env)


changed = git(['diff', '--name-only', '-z', '--ignore-submodules=all', base, '--', '.', ':(exclude)story-audiences-delivery']).decode().split('\0')
new = git(['ls-files', '--others', '--exclude-standard', '-z']).decode().split('\0')
allowed = [p for p in new if p and (
    p.startswith('build-system/story-audiences-demo/') or
    p.startswith('docs/story-audiences/') or
    p.startswith('submodules/TelegramUI/Images.xcassets/StoryAudiences/') or
    (p.startswith('submodules/') and p.endswith('.swift'))
)]
files = sorted(set(p for p in changed + allowed if p and not any(x in Path(p).parts for x in ['.DS_Store', 'xcuserdata']) and not p.startswith('story-audiences-delivery/')))
assert files, 'No feature changes found relative to the pinned upstream base'
for p in files:
    assert not p.endswith(('.zip', '.xcuserstate')), 'Do not commit generated release artifacts: ' + p
    if (root / p).exists():
        assert (root / p).stat().st_size < 50 * 1024 * 1024, 'Unexpected large source file: ' + p
out = root / 'story-audiences-delivery'
out.mkdir(exist_ok=True)
patch = out / 'story-audiences-native.patch'
with tempfile.TemporaryDirectory(prefix='story-audiences-export-') as tmp:
    env = {**os.environ, 'GIT_INDEX_FILE': str(Path(tmp) / 'index')}
    git(['read-tree', base], env)
    git(['add', '--', *files], env)
    patch.write_bytes(git(['diff', '--cached', '--binary', '--full-index', base, '--'], env))
    git(['apply', '--reverse', '--check', str(patch)], env)
    git(['read-tree', base], env)
    git(['apply', '--cached', '--check', str(patch)], env)
metadata = {
    'base': base,
    'files': len(files),
    'paths': files,
    'bytes': patch.stat().st_size,
    'sha256': hashlib.sha256(patch.read_bytes()).hexdigest(),
    'checks': ['clean-base-index apply', 'working-tree reverse'],
}
(out / 'patch-manifest.json').write_text(json.dumps(metadata, indent=2) + '\n')
print(str(patch))
print(f'{len(files)} files; {patch.stat().st_size} bytes; both patch checks passed.')
