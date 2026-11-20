# Story Audiences — offline Simulator demo

An unofficial feature prototype built into original Telegram iOS. Source: https://github.com/drbvrr/Telegram-iOS/tree/story-audiences

## Launch

Requires an Apple Silicon Mac, Xcode27.2 with first-run setup completed, and the standard iOS27.2 Simulator runtime installed in Xcode settings.

Extract the whole ZIP. Keep `Telegram.app`, `Assets`, `run-demo.py` and `Launch Story Audiences.command` in the same folder. Double-click the command file, or open Terminal in this folder and run:

```sh
python3 run-demo.py
```

The helper uses/creates a dedicated Story Audiences Demo iPhone17 Simulator and opens the native story editor. It does not download a runtime, erase a device or reset saved lists. `python3 run-demo.py --check` validates prerequisites without launching. `--device YOUR_UDID` selects an existing standard iOS27.2 Simulator.

This is an iOS Simulator app, not a macOS app or a phone IPA. Do not launch Telegram.app directly. The prebuilt executable is arm64; see the source repository for rebuilding on another environment. The helper copies fixture media into the Simulator app data container; ordinary app relaunches retain avatars even after moving the extracted folder. Keep the complete archive contents together if reinstalling.

## Walkthrough

1. Tap Next on the prepared story photo.
2. Tap Create List, select contacts and tap Next.
3. Enter a list name, choose an icon and save with the checkmark.
4. The new list is automatically selected. Tap Post.
5. On Chats, open My Story and advance to your newly published story if needed. Tap its audience badge.
6. Choose another audience and confirm Move. You can also edit the list or open the original viewers interface.

Everyone, My Contacts and Close Friends remain. Custom lists persist locally. Changing membership updates linked local stories; deleting a list makes linked stories visible to Everyone. No real contacts are accessed and no stories are published to Telegram.

## Included

The Simulator app, fixture media, launch helper, build metadata and attribution notices. A fresh launch creates the demo profile Pepe, contacts, chats and a Close Friends story. The audience picker starts with Everyone selected and three built-in audiences.

The UI and local behavior are implemented in original Telegram code. Production account wiring, remote privacy enforcement and synchronization across devices require the connected-client adapter described in the source repository.

## Requirements / troubleshooting

- Missing runtime: install the standard iOS27.2 runtime through Xcode settings; then rerun the helper.
- Missing developer tools: select the full Xcode installation in Xcode settings / Locations and complete its first-run setup.
- A command file does not open: run the readable Python helper from Terminal using the command above.
- Missing avatars after moving files: keep Assets with the scripts and rerun the helper. Lists are not cleared.
- Download integrity: compare the ZIP's SHA256 with the release's SHA256SUMS.txt. The helper also checks the app executable and fixture hashes in BUILD-INFO.json.
