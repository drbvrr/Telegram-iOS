# Story Audiences — offline native prototype v1

Reusable private story audiences implemented in original Telegram iOS, with native media editor, contacts/privacy UI, navigation, viewer and publication transition.

## Downloads

- **StoryAudiences-offline-demo-arm64-ios27.2.zip** — verified Simulator app, supplied avatars/icons/story photo, launch helper, source metadata and notices. Extract everything, then use the launch command or `python3 run-demo.py`.
- **story-audiences-native.patch** — binary-capable patch including source and demo fixtures, for upstream commit24638bc69bd083981b178dd1e7f921eebbf7fc46.
- **SHA256SUMS.txt** — checksums for both downloads.

Requires Apple Silicon, Xcode27.2 and the standard iOS27.2 Simulator runtime. It needs no Telegram account, Premium, API credentials or Telegram server connection. The executable is for iOS Simulator, not a physical iPhone or direct macOS launch.

Start with Next, create and save a list, Post, open My Story and change its audience. Lists persist locally; supplied fixtures populate the original chat/story screens.

[Source and instructions](https://github.com/drbvrr/Telegram-iOS/tree/story-audiences) · [Integration boundary](https://github.com/drbvrr/Telegram-iOS/blob/story-audiences/docs/story-audiences/INTEGRATION.md)

Live-account privacy wiring and cross-device synchronization are documented integration steps. The packaged demo verifies local behavior; it does not claim remote access enforcement. No authenticated account data is bundled.

The designer's final presentation video is submitted separately. This release preserves the runnable prototype and corresponding source.
