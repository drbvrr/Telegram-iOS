"""Generate the original Telegram app project for offline Simulator use."""
from pathlib import Path
import json, platform, subprocess
root=Path(__file__).resolve().parents[2]
def run(args): subprocess.run(args,cwd=root,check=True)
run(['python3','build-system/Make/Make.py','--overrideXcodeVersion','--cacheDir',str(root/'.build-cache'),'generateProject','--configurationPath','build-system/story-audiences-demo/configuration.json','--xcodeManagedCodesigning','--disableExtensions'])
rc=root/'xcodeproj.bazelrc'
s=rc.read_text().replace('swift:copt="6"', 'swift:copt="2"');s+='build --jobs=2\n' if 'build --jobs=2\n' not in s else '';flag='build --//Telegram:disableProvisioningProfiles\n'
if flag not in s:s+=flag
# Keep historical action-cache copies bounded on small development disks.
for cache_flag in ['build --experimental_disk_cache_gc_max_size=4G', 'build --experimental_disk_cache_gc_idle_delay=1m']:
    if cache_flag + '\n' not in s: s += cache_flag + '\n'
rc.write_text(s)
version=json.loads((root/'versions.json').read_text())['bazel'].split(':')[0]
arch='arm64' if platform.machine()=='arm64' else 'x86_64'
run([str(root/f'build-input/bazel-{version}-darwin-{arch}'),'run','//Telegram:StoryAudiencesNative_xcodeproj','--//Telegram:disableProvisioningProfiles','--//Telegram:disableExtensions','--//Telegram:disableStripping','--disk_cache='+str(root/'.build-cache')])
run(['python3','build-system/story-audiences-demo/configure-scheme.py'])
print(root/'Telegram/StoryAudiencesNative.xcodeproj')
