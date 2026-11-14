# Integration map

## Feature code and original components

Paths below are relative to the Telegram repository root.

| Code | Responsibility |
| --- | --- |
| `submodules/TelegramCore/Sources/Account/StoryAudienceStore.swift` | Codable per-account list definitions, validation, stable palette slots, linked story references, membership replacement and deletion fallback. |
| `submodules/TelegramUI/Components/ShareWithPeersScreen/Sources/StoryAudienceConfiguration.swift` | Optional UI configuration and callbacks for the existing privacy/contact screen. |
| `submodules/TelegramUI/Components/ShareWithPeersScreen/Sources/StoryAudienceGlyphs.swift` | Shared vector geometry from the supplied SVGs. |
| `submodules/TelegramUI/Sources/StoryAudienceEditor.swift` | New native list detail/editor, icon cloud, draft navigation and member removal. |
| `submodules/TelegramUI/Components/ShareWithPeersScreen/Sources/StoryAudiencePeopleTokensView.swift` | Selected people strip using native AvatarNode and glass controls. |
| `submodules/TelegramUI/Components/Stories/StoryContainerScreen/Sources/StoryPrivacyIconComponent.swift` | Uniform author audience badge; original story controls stay separate. |
| `submodules/Display/Source/Navigation/NavigationModalContainer.swift` | Existing modal presentation with opt-in tint attached to the real clipped viewport, following its native transform. |
| `submodules/TelegramUI/Sources/StoryAudiencesDemo.swift` | Reference wiring, fixture contacts/avatars/chats, local publication and privacy observation. |
| `submodules/TelegramCore/Sources/Account/StoryAudiencesOfflineDemo.swift` | Synthetic account and inert transport, used only for the offline demo. |

Existing rows, peer cells, contact selection, reveal actions, header edge blur, navigation transitions and publication animation are reused. Their new styling parameters have defaults for other callers.

## What must be wired for a connected client

The current UI hook is configured by `StoryAudiencesDemo.configure` and gated by the offline feature. Copying the patch does not enable lists for authenticated production accounts. To integrate:

1. Move/install the audience configuration from the reference demo wiring into a normal account feature owner. Use the real `AccountContext`, contacts and presentation data; keep fixture seeding and inert transport out of that owner.
2. Keep list metadata per account, using `StoryAudienceStore` or an account database implementation. A custom list maps to the existing `EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: ...)` allowlist. Do not encode a custom list ID as an existing server enum or expose its private name to recipients.
3. On publication, pass the resolved peer IDs to the normal story publication engine, and associate the returned story ID with the local list after successful publication. Preserve the original media publication transition.
4. On list changes, submit normal story privacy edits for each still-existing linked story through the existing engine privacy operation (`_internal_editStoryPrivacy` / its public engine wrapper). Handle server errors, expired/deleted stories, and partial multi-story updates. Demo persistence alone does not enforce remote access.
5. On Move, replace the story allowlist after confirmation, update its list link only on successful remote mutation, and stop applying future updates from its former list. On Delete List, update linked stories to Everyone before removing their list link, with an explicit error/retry policy.
6. Use real contact/privacy operations for Everyone exclusions, contacts and Close Friends. Retain the Close Friends indication; custom lists should not notify recipients of membership.
7. Synchronizing private list names/icons/membership and story-list associations across devices needs an approved persistence/synchronization design. No new server RPC/schema is introduced by this patch.

The existing `Stories.swift` offline branches emulate publication/privacy locally. Their original non-demo engine path is retained; do not activate the offline bundle/transport for a real account.

## Demo boundary

Debug bundle `design.storyaudiences.native` always uses the offline bootstrap. Ordinary app identifiers require the explicit demo launch flag. The supplied configuration deliberately has invalid API credentials and is only for the Simulator demo. Runtime data lives in a separate demo Postbox root. It is not a dump of a logged-in Telegram account.

The model tests exercise local retroactive privacy, deletion fallback, color stability, duplicate names, zero-member lists and relaunch persistence. They do not prove live server behavior or cross-device synchronization.
