#!/usr/bin/env python3
"""Install and launch the supplied original-client demo without a Telegram account."""
import argparse
import hashlib
import json
import platform
import plistlib
import shutil
import subprocess
from pathlib import Path


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def output(args):
    return subprocess.check_output(args, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parent
    parser.add_argument('--app', type=Path, default=root / 'Telegram.app')
    parser.add_argument('--assets', type=Path, default=root / 'Assets')
    parser.add_argument('--device', help='An existing iOS27.2 Simulator UDID; otherwise use a dedicated demo device')
    parser.add_argument('--check', action='store_true', help='Verify files and prerequisites without installing or launching')
    parser.add_argument('--no-window', action='store_true', help='Do not open the Simulator window')
    args = parser.parse_args()
    app, assets = args.app.resolve(), args.assets.resolve()
    if platform.system() != 'Darwin':
        raise SystemExit('This demo requires macOS with Xcode and an iOS Simulator runtime.')
    if platform.machine() != 'arm64' and output(['sysctl', '-n', 'hw.optional.arm64']) != '1':
        raise SystemExit('The prebuilt app is for Apple Silicon. Build from source for another architecture.')
    if not (app / 'Info.plist').is_file():
        raise SystemExit('Telegram.app is missing. Extract the complete demo archive, or pass --app /path/Telegram.app.')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    bundle = info.get('CFBundleIdentifier')
    if bundle != 'design.storyaudiences.native':
        raise SystemExit('Expected the isolated design.storyaudiences.native demo bundle.')
    required_assets = ('StoryPhoto.jpg', 'EditorStory.jpg', 'PublishedStory.jpg', 'Avatars/PepeProfile.png')
    if any(not (assets / relative).is_file() for relative in required_assets):
        raise SystemExit('Fixture assets are missing. Keep the app, Assets and scripts together.')
    manifest = root / 'BUILD-INFO.json'
    if manifest.is_file():
        metadata = json.loads(manifest.read_text())
        digest = hashlib.sha256((app / 'Telegram').read_bytes()).hexdigest()
        if digest != metadata['appBinarySHA256']:
            raise SystemExit('App checksum mismatch. Extract a fresh copy of the release archive.')
        for relative, expected in metadata['assetSHA256'].items():
            if hashlib.sha256((assets / relative).read_bytes()).hexdigest() != expected:
                raise SystemExit('Fixture checksum mismatch: ' + relative)
    developer = Path(output(['xcode-select', '-p']))
    runtimes = json.loads(output(['xcrun', 'simctl', 'list', 'runtimes', '--json']))['runtimes']
    runtime = next((r for r in runtimes if r.get('isAvailable') and r['identifier'] == 'com.apple.CoreSimulator.SimRuntime.iOS-27-2'), None)
    if runtime is None:
        raise SystemExit('Install the standard iOS27.2 Simulator runtime in Xcode settings, then run this script again.')
    devices = json.loads(output(['xcrun', 'simctl', 'list', 'devices', '--json']))['devices'].get(runtime['identifier'], [])
    if args.device:
        device = next((d for d in devices if d['udid'] == args.device and d.get('isAvailable')), None)
        if device is None:
            raise SystemExit('The specified device must be an available standard iOS27.2 Simulator.')
    else:
        device = next((d for d in devices if d['name'] == 'Story Audiences Demo' and d.get('isAvailable')), None)
    print('Verified demo files, fixture assets and iOS27.2 runtime.')
    if args.check:
        print('No devices, apps or saved lists were changed.')
        return
    if device is None:
        udid = output(['xcrun', 'simctl', 'create', 'Story Audiences Demo', 'com.apple.CoreSimulator.SimDeviceType.iPhone-17', runtime['identifier']])
        device = {'udid': udid, 'state': 'Shutdown'}
    udid = device['udid']
    if device['state'] != 'Booted':
        run(['xcrun', 'simctl', 'boot', udid])
    run(['xcrun', 'simctl', 'bootstatus', udid, '-b'])
    run(['xcrun', 'simctl', 'ui', udid, 'appearance', 'dark'])
    if not args.no_window:
        applications = developer.parent / 'Applications'
        window = applications / 'DeviceHub.app'
        if not window.exists():
            window = applications / 'Simulator.app'
        run(['open', '-a', str(window)])
    subprocess.run(['xcrun', 'simctl', 'terminate', udid, bundle], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run(['xcrun', 'simctl', 'install', udid, str(app)])
    container = Path(output(['xcrun', 'simctl', 'get_app_container', udid, bundle, 'data']))
    installed_assets = container / 'Library/Application Support/StoryAudiencesDemoAssets'
    shutil.copytree(assets, installed_assets, dirs_exist_ok=True)
    run(['xcrun', 'simctl', 'launch', udid, bundle, '--story-audiences-demo', '--story-audiences-assets', str(installed_assets)])
    print('Story Audiences is running. Start with Next in the story editor.')
    print('Saved lists are retained. Device: ' + udid)


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit('Xcode/Simulator command failed. Complete Xcode first-run setup and try again: ' + str(error.cmd))
