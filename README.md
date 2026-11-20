# Custom Lists: share stories with exactly the right people

Build custom lists for the different circles in your life — coworkers, relatives, classmates — and pick the right one with a single tap when posting a story. Lists are invisible to their members: no badges, no notifications, no visible list names

<img width="2243" height="1364" alt="image" src="https://github.com/user-attachments/assets/c131788a-599e-4c3e-89bb-29ac73a16e1a" />

## Why
Telegram currently offers four audience options: Everyone, My Contacts, Close Friends, and Selected Users. Hand-picking viewers for every story is tedious, and Close Friends is too personal for some circles.

This concept replaces Selected Users with a Create List button. You build reusable segments once and pick them in a single tap. People you add won't know they are in a segment.

## Try it

On an Apple Silicon Mac with Xcode and the iOS 27.2 Simulator runtime, download and extract the demo ZIP, then run **Launch Story Audiences.command**. The app opens the story editor with a demo photo and works offline without a Telegram account.

Tap **Next → Create List**, choose people, name the list, pick an icon and save. Tap **Post**, then open **My Story** and tap the audience badge on your new story to switch audiences.

## Prototype scope

The feature uses Telegram iOS screens and navigation. Lists and story privacy changes are stored locally in the demo. A connected client would need server-side access enforcement and list synchronization.

## Links

- [Download the offline Simulator demo](https://github.com/drbvrr/Telegram-iOS/releases/tag/story-audiences-v2)
- [Review all changes from upstream](https://github.com/drbvrr/Telegram-iOS/compare/24638bc69bd083981b178dd1e7f921eebbf7fc46...story-audiences)
- [Apply the Git patch](story-audiences-delivery/story-audiences-native.patch) or [build from source](build-system/story-audiences-demo/README.md)
- [Integration notes](docs/story-audiences/INTEGRATION.md) and [credits](build-system/story-audiences-demo/NOTICE.md)
