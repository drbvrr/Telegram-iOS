# Run Story Audiences

## Fastest: the prebuilt offline demo

1. Open [Releases](https://github.com/drbvrr/Telegram-iOS/releases) and download **StoryAudiences-offline-demo-arm64-ios27.2.zip** from Assets.
2. Extract the whole archive. Keep the app, Assets and launch scripts together.
3. Double-click **Launch Story Audiences.command**. Or open Terminal in the extracted folder and run `python3 run-demo.py`.
4. The helper selects/creates a dedicated **Story Audiences Demo** iPhone Simulator, installs the app and opens the original editor with a local photo.

Requires Apple Silicon, Xcode with command-line tools selected, and an installed iOS27.2 Simulator runtime. First-time Xcode setup and Apple's license acceptance must be completed by the reviewer. Install the runtime through Xcode settings if the helper reports it missing. The script does not download a runtime or remove devices/data.

The app needs no Telegram account, Premium, API application or Telegram server access. It is a Simulator app: do not double-click Telegram.app or attempt to install it on a phone. For a different toolchain, use the source route below; only the listed environment was validated.

## Build this fork in Xcode

Install Git LFS and upstream build dependencies, then clone with submodules:

```sh
git clone --recursive --branch story-audiences https://github.com/drbvrr/Telegram-iOS.git
cd Telegram-iOS
git lfs pull
python3 build-system/story-audiences-demo/prepare.py
open Telegram/StoryAudiencesNative.xcodeproj
```

Select **StoryAudiencesDemo**, select an iPhone with **iOS27.2**, and Run. The shared scheme supplies the offline launch arguments and an asset path computed from this checkout. Regenerate the scheme after moving the checkout:

```sh
python3 build-system/story-audiences-demo/configure-scheme.py
```

The generated Xcode project is intentionally not committed: its paths and generated Bazel files depend on the local checkout. Generation/build can download dependencies; the running demo stays offline. The prepare script limits build concurrency and disk-cache size for smaller Macs. Keep current build outputs for incremental changes.

Validated command-line build (Xcode27.2):

```sh
xcodebuild -project Telegram/StoryAudiencesNative.xcodeproj \
  -scheme StoryAudiencesDemo -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO -jobs 1 build
```

## Apply the patch to upstream instead

Use a separate checkout if you want to preserve another working tree:

```sh
git clone --recursive https://github.com/TelegramMessenger/Telegram-iOS.git Telegram-iOS-Audiences
cd Telegram-iOS-Audiences
git checkout 24638bc69bd083981b178dd1e7f921eebbf7fc46
git submodule update --init --recursive
git lfs pull
git apply --check /absolute/path/story-audiences-native.patch
git apply /absolute/path/story-audiences-native.patch
python3 build-system/story-audiences-demo/prepare.py
open Telegram/StoryAudiencesNative.xcodeproj
```

The binary-capable patch includes supplied icons, avatars and story photo. Apply to the pinned upstream base; newer revisions may conflict. [Integration notes](../../docs/story-audiences/INTEGRATION.md) explain connected-client wiring.

## Review the scenario

**Next → Create List → people → Next → name/icon → checkmark → Post → My Story → top audience badge.** The normal viewers button opens the original viewers interface.

Lists persist between ordinary launches. Empty membership and duplicate names are allowed; empty names are rejected. Membership changes affect linked local stories, Move replaces membership, and Delete List falls back to Everyone. The demo starts with synthetic contacts/chats/friend stories using the supplied media; it contains no authenticated account database.

## Checks and credits

[Verification and test commands](../../docs/story-audiences/VERIFICATION.md) · [Source map and production boundary](../../docs/story-audiences/INTEGRATION.md) · [NOTICE](NOTICE.md).

Model check: `python3 build-system/story-audiences-demo/check-model.py`.

The dummy configuration has invalid credentials on purpose. The dedicated Debug bundle always uses an inert transport and loopback-only auxiliary connection settings. Live-account privacy and list synchronization are not validated by this demo.
