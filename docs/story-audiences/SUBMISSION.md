# Submission checklist and recording guide

Feature source: https://github.com/drbvrr/Telegram-iOS/tree/story-audiences

Use the feature branch URL above, rather than the unchanged upstream master page. The public GitHub Release should attach the arm64 Simulator ZIP, binary patch and SHA256SUMS.txt. GitHub's automatically generated Source code ZIP is not the prebuilt demo.

The designer will record the presentation video. Suggested continuous sequence:

1. Start at the prepared native story editor and tap Next.
2. Create a named list: select several people, name it, choose an icon, save.
3. Show automatic selection, then Post and the original publication animation.
4. Open My Story and its top audience badge; show Move confirmation and the updated badge.
5. Optionally show Edit people / Save List and the original viewers interface.

Use the original app at natural speed. The technical XCTest recordings contain setup pauses and Simulator Home screens and should not be submitted as the presentation video.

## Suggested message

Story Audiences for Telegram iOS

Create reusable private audiences for stories, each with a name, icon and people. Everyone, My Contacts and Close Friends stay available. The feature uses Telegram's native editor, privacy/contact screens, navigation and publication animation.

Code and integration notes: https://github.com/drbvrr/Telegram-iOS/tree/story-audiences

Offline Simulator demo: https://github.com/drbvrr/Telegram-iOS/releases

The submission includes working native UI and local audience behavior, plus a pinned upstream patch. Live-account privacy wiring and cross-device list synchronization are documented integration steps.

Attach the designer's final demonstration video when sending the proposal to @designers.
