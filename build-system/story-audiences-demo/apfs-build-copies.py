"""Clone generated framework binaries on APFS before rules_xcodeproj's rsync.
Only build products are replaced. Unsupported filesystems use original rsync.
Run with --install after generating the native Xcode project.
"""
from pathlib import Path
import ctypes, os, sys, shlex

if sys.argv[1:] == ['--install']:
    root = Path(__file__).resolve().parents[2]
    p = root / 'Telegram/StoryAudiencesNative.xcodeproj/rules_xcodeproj/bazel/copy_outputs.sh'
    if not p.exists(): raise SystemExit('Generate StoryAudiencesNative.xcodeproj first.')
    line = '      /usr/bin/python3 ' + shlex.quote(str(Path(__file__).resolve())) + ' "$PWD/$BAZEL_OUTPUTS_PRODUCT_BASENAME" "$TARGET_BUILD_DIR/$BAZEL_OUTPUTS_PRODUCT_BASENAME"\n'
    text = p.read_text()
    if 'apfs-build-copies.py' not in text:
        p.write_text(text.replace('      # Product is a bundle\n', '      # Product is a bundle\n' + line))
    print('Enabled APFS clones for generated framework products.')
    raise SystemExit()

if len(sys.argv) != 3: raise SystemExit('Expected source and destination bundle paths.')
source, target = map(Path, sys.argv[1:])
if source.suffix != '.framework': raise SystemExit()
name = source.stem
binary = source / name
if not binary.is_file(): raise SystemExit()
lib = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True)
lib.clonefile.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
targets = [target / name]
embedded = target.parent / 'Telegram.app/Frameworks' / source.name
if embedded.is_dir(): targets.append(embedded / name)
for output in targets:
    before = binary.stat()
    if output.exists():
        current = output.stat()
        if current.st_size == before.st_size and current.st_mtime_ns == before.st_mtime_ns: continue
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name('.' + name + '.apfs-' + str(os.getpid()))
    if lib.clonefile(os.fsencode(binary), os.fsencode(temporary), 0) == 0:
        os.replace(temporary, output)
