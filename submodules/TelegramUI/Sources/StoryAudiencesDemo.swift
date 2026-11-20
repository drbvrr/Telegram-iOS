import Foundation
import UIKit
import ImageIO
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext
import Display
import ShareWithPeersScreen
import StoryContainerScreen
import TelegramNotices
import MediaEditorScreen
import ChatListUI
import ComponentFlow
import EdgeEffect

// Local bootstrap pattern adapted from riveauxmia/telegram-unmute-similar (GPL-2.0).
// This file deliberately uses original Telegram screens; no replacement rendering.
enum StoryAudiencesDemo {
    static let authorId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(7_880_001))
    static var isEnabled: Bool { storyAudiencesOfflineDemoEnabled }
    private static var assetsURL: URL? {
        let key = "StoryAudiencesDemoAssetsPath"
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--story-audiences-assets"), i + 1 < args.count {
            UserDefaults.standard.set(args[i + 1], forKey: key)
            return URL(fileURLWithPath: args[i + 1])
        }
        return UserDefaults.standard.string(forKey: key).map { URL(fileURLWithPath: $0) }
    }
    private static var editorPresenter: ((MediaEditorScreenImpl) -> Void)?
    static var publicationTransition: (() -> MediaEditorScreenImpl.TransitionOut?)?
    private static var audienceObservation: Disposable?
    private static var presenter: ((ViewController) -> Void)?

    static let entries: [(Int64, String, String?)] = [
        (7_880_001, "Pepe", "PepeProfile"),
        (7_880_002, "Sonya Litvinova", "Rectangle 8"),
        (7_880_003, "Marina", nil),
        (7_880_004, "daria", "Rectangle 16"),
        (7_880_005, "Lena Orlova", "Rectangle 10"),
        (7_880_006, "Mom", nil),
        (7_880_007, "Egor Gusev", "Rectangle 11"),
        (7_880_008, "Rita PM", "Rectangle 12"),
        (7_880_009, "eva", "Rectangle 13"),
        (7_880_010, "Aleksey", nil),
        (7_880_011, "Ilia", "Rectangle 14"),
        (7_880_012, "sister", "Rectangle 15")
    ]
    static func signIn(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount) -> Signal<Void, NoError> {
        let mediaBox = account.postbox.mediaBox
        return storyAudiencesOfflineDemoSignIn(accountManager: accountManager, account: account, accountPeerId: authorId, seed: { transaction in
            seed(transaction: transaction, mediaBox: mediaBox)
        })
    }
    private static func seed(transaction: Transaction, mediaBox: MediaBox) {
            var contacts = Set<PeerId>()
            for (number, name, avatar) in entries {
                let id = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(number))
                let photo = avatar.flatMap { localAvatar(mediaBox: mediaBox, name: $0, id: number) } ?? []
                var flags = (transaction.getPeer(id) as? TelegramUser)?.flags ?? []
                if number == 7_880_007 || number == 7_880_010 { flags.insert(.isPremium) }
                if id == authorId { flags.remove(.isPremium) }
                let nameColor: PeerColor? = number == 7_880_003 ? .preset(.green) : (number == 7_880_006 ? .preset(.pink) : nil)
                let user = TelegramUser(id: id, accessHash: .personal(0), firstName: name, lastName: nil, username: nil, phone: nil, photo: photo, botInfo: nil, restrictionInfo: nil, flags: flags, emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nameColor, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                transaction.updatePeersInternal([user], update: { _, updated in updated })
                let minutes: Int32? = number == 7_880_003 ? 31 : (number == 7_880_007 ? 1 : (number == 7_880_010 ? 37 : nil))
                let presence = minutes.map { TelegramUserPresence(status: .present(until: Int32(Date().timeIntervalSince1970) - $0 * 60), lastActivity: 0) } ?? TelegramUserPresence(status: .recently(isHidden: false), lastActivity: 0)
                transaction.updatePeerPresencesInternal(presences: [id: presence], merge: { _, updated in updated })
                if id != authorId { contacts.insert(id) }
            }
            transaction.replaceContactPeerIds(contacts)
            seedChats(transaction: transaction)
            seedPublishedStory(transaction: transaction, mediaBox: mediaBox)
            seedFriendsStories(transaction: transaction, mediaBox: mediaBox)

    }
    private static let publishedStoryResourceId: Int64 = 7_889_003

    private static func seedPublishedStory(transaction: Transaction, mediaBox: MediaBox) {
        var items = transaction.getStoryItems(peerId: authorId)
        func resourceId(for row: StoryItemsTableEntry) -> Int64? {
            guard let stored = row.value.get(Stories.StoredItem.self), case let .item(item) = stored else { return nil }
            return (item.media as? TelegramMediaImage)?.imageId.id
        }

        guard !items.contains(where: { resourceId(for: $0) == publishedStoryResourceId }),
              let image = storyImage(named: "PublishedStory.jpg", resourceId: publishedStoryResourceId, mediaBox: mediaBox) else { return }

        let previousIndex = items.firstIndex { resourceId(for: $0) == 7_889_002 }
        let now = Int32(Date().timeIntervalSince1970)
        let lastSeenId = transaction.getPeerStoryState(peerId: authorId)?.maxSeenId ?? 0
        let id = previousIndex.map { items[$0].id } ?? max(now - 1, max(lastSeenId, items.last?.id ?? 0) + 1)
        let item = Stories.Item(
            id: id, timestamp: now, expirationTimestamp: Int32.max,
            media: image, alternativeMediaList: [], mediaAreas: [], text: "", entities: [], views: nil,
            privacy: Stories.Item.Privacy(base: .closeFriends, additionallyIncludePeers: []),
            isPinned: true, isExpired: false, isPublic: false, isCloseFriends: true,
            isContacts: false, isSelectedContacts: false, isForwardingDisabled: false,
            isEdited: false, isMy: true, myReaction: nil, forwardInfo: nil, music: nil, authorId: nil, folderIds: nil
        )
        guard let entry = CodableEntry(Stories.StoredItem.item(item)) else { return }
        let row = StoryItemsTableEntry(value: entry, id: id, expirationTimestamp: item.expirationTimestamp, isCloseFriends: true, isLiveStream: false)
        if let previousIndex {
            items[previousIndex] = row
        } else {
            items.append(row)
        }
        transaction.setStoryItems(peerId: authorId, items: items)
        transaction.setStory(id: StoryId(peerId: authorId, id: id), value: entry)
        transaction.setStoryItemsInexactMaxId(peerId: authorId, id: id, hasLiveItems: false)
        if transaction.getPeerStoryState(peerId: authorId) == nil, let state = CodableEntry(Stories.PeerState(maxReadId: 0)) {
            transaction.setPeerStoryState(peerId: authorId, state: StoredStoryPeerState(entry: state, maxSeenId: 0))
        }
    }

    private static func seedFriendsStories(transaction: Transaction, mediaBox: MediaBox) {
        guard let assets = assetsURL,
              let data = try? Data(contentsOf: assets.appendingPathComponent("StoryPhoto.jpg")) else { return }
        let resource = LocalFileMediaResource(fileId: 7_889_000)
        mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
        let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: 7_889_000), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 1080, height: 1920), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let peers = [7_880_002, 7_880_003, 7_880_004, 7_880_007, 7_880_008].map { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64($0))) }
        for (index, peerId) in peers.enumerated() {
            let id: Int32 = 901 + Int32(index)
            let now = Int32(Date().timeIntervalSince1970) - Int32((index + 1) * 240)
            let item = Stories.Item(id: id, timestamp: now, expirationTimestamp: now + 86400, media: image, alternativeMediaList: [], mediaAreas: [], text: "", entities: [], views: nil, privacy: Stories.Item.Privacy(base: .everyone, additionallyIncludePeers: []), isPinned: false, isExpired: false, isPublic: true, isCloseFriends: false, isContacts: false, isSelectedContacts: false, isForwardingDisabled: false, isEdited: false, isMy: false, myReaction: nil, forwardInfo: nil, music: nil, authorId: nil, folderIds: nil)
            if let entry = CodableEntry(Stories.StoredItem.item(item)) {
                transaction.setStoryItems(peerId: peerId, items: [StoryItemsTableEntry(value: entry, id: id, expirationTimestamp: item.expirationTimestamp, isCloseFriends: false, isLiveStream: false)])
                transaction.setStory(id: StoryId(peerId: peerId, id: id), value: entry)
                transaction.setStoryItemsInexactMaxId(peerId: peerId, id: id, hasLiveItems: false)
                if let state = CodableEntry(Stories.PeerState(maxReadId: 0)) { transaction.setPeerStoryState(peerId: peerId, state: StoredStoryPeerState(entry: state, maxSeenId: 0)) }
            }
        }
        transaction.replaceAllStorySubscriptions(key: .filtered, state: CodableEntry(Stories.SubscriptionsState(opaqueState: "offline", refreshId: 0, hasMore: false)), peerIds: peers)
    }
    private static func seedChats(transaction: Transaction) {
        let conversations: [(Int64, String, String, String, Bool)] = [
            (7_880_002, "Sonya Litvinova", "Are we still on for coffee tomorrow?", "Yes! Same place at 11?", false),
            (7_880_008, "Rita PM", "The new screens look great. Just left a few comments.", "Thanks, I'll take a look after lunch", false),
            (7_880_003, "Marina", "I booked the table for Saturday", "Perfect, see you there!", true),
            (7_880_007, "Egor Gusev", "Could you send me the link to the presentation?", "Here you go — the final version is in our shared folder", false),
            (7_880_006, "Mom", "Did you get home okay?", "Just got in. Call you tomorrow ❤️", false),
            (7_880_101, "Alex Morgan", "Hi! We met at the design meetup last week.", "Great meeting you! Would love to see what you're working on", true),
            (7_880_004, "daria", "This made me think of our trip 😂", "We really need to do that again", true),
            (7_880_005, "Lena Orlova", "Have you tried that little bakery by the park?", "Their almond croissants are amazing", true),
            (7_880_102, "Maya Chen", "Thanks for your feedback on my portfolio", "You're welcome! Good luck with the interview", false),
            (7_880_012, "sister", "Can you pick up my parcel on your way?", "Sure, send me the collection code", false),
            (7_880_009, "eva", "Sending you the playlist tonight", "You have to hear the last track", true),
            (7_880_103, "Oliver Reed", "Hi Pepe, is the desk still available?", "Yes, you can come by tomorrow evening", false),
            (7_880_010, "Aleksey", "I pushed the latest changes", "The animation should feel much smoother now", true),
            (7_880_011, "Ilia", "Do you want to join us for a walk?", "Can't today, but let's do Sunday", false),
            (7_880_104, "Sophie Martin", "Your booking is confirmed for 3 pm", "Thank you! See you on Friday", false),
            (7_880_105, "Daniel Brooks", "I found the book you mentioned", "Already halfway through it. Such a good recommendation", true),
            (7_880_106, "Anna Wilson", "Would you mind sharing the photos from yesterday?", "Of course, I'll send them when I get home", false),
            (7_880_107, "Noah Parker", "The package should arrive on Thursday", "Thanks for the update!", false)
        ]
        let now = Int32(Date().timeIntervalSince1970)
        for (index, chat) in conversations.enumerated() {
            let (number, name, first, last, incoming) = chat
            let id = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(number))
            if transaction.getPeer(id) == nil {
                let user = TelegramUser(id: id, accessHash: .personal(0), firstName: name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                transaction.updatePeersInternal([user], update: { _, updated in updated })
            }
            let timestamp = now - Int32(120 + index * index * 147)
            let messages = [(first, !incoming), (last, incoming)].enumerated().map { offset, value in
                StoreMessage(id: MessageId(peerId: id, namespace: Namespaces.Message.Cloud, id: Int32(offset + 1)), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: timestamp - Int32((1 - offset) * 180), flags: value.1 ? [.Incoming] : [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: value.1 ? id : authorId, text: value.0, attributes: [], media: [])
            }
            let _ = transaction.addMessages(messages, location: .UpperHistoryBlock)
            transaction.updatePeerChatListInclusion(id, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: timestamp))
            transaction.updateCurrentPeerNotificationSettings([id: TelegramPeerNotificationSettings.defaultSettings])
            let unread: Int32 = incoming && index < 8 ? 1 : 0
            transaction.resetIncomingReadStates([id: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: unread == 0 ? 2 : 1, maxOutgoingReadId: 2, maxKnownId: 2, count: unread, markedUnread: false)]])
            transaction.removeHole(peerId: id, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
        }
    }
    private static func localAvatar(mediaBox: MediaBox, name: String, id: Int64) -> [TelegramMediaImageRepresentation]? {
        guard let assets = assetsURL else { return nil }
        let path = assets.appendingPathComponent("Avatars").appendingPathComponent(name + ".png")
        guard let source = CGImageSourceCreateWithURL(path as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 512] as CFDictionary) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        // New resource IDs invalidate previously cached avatars for the swapped profiles.
        let resourceId = (id == 7_880_001 || id == 7_880_004) ? id + 20_000 : id
        let resource = LocalFileMediaResource(fileId: resourceId)
        mediaBox.storeResourceData(resource.id, data: data as Data, synchronous: true)
        return [TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(image.width), height: Int32(image.height)), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)]
    }

    static func open(context: AccountContext, present: @escaping (ViewController) -> Void, privacy: EngineStoryPrivacy = EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: []), preview: Bool = true) {
        configure(context: context, present: present)
        // Also refresh fixtures in an existing demo database after fixture changes.
        let _ = (context.account.postbox.transaction { transaction in
            seed(transaction: transaction, mediaBox: context.account.postbox.mediaBox)
        } |> deliverOnMainQueue).startStandalone(completed: {
            openPrepared(context: context, present: present, privacy: privacy, preview: preview)
        })
    }

    private static func openPrepared(context: AccountContext, present: @escaping (ViewController) -> Void, privacy: EngineStoryPrivacy, preview: Bool) {
        if preview && CommandLine.arguments.contains("--story-audiences-open-contacts") {
            openPeople(context: context, present: present, privacy: EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: []))
            return
        }
        if preview && CommandLine.arguments.contains("--story-audiences-open-story") {
            openStory(context: context, present: present, privacy: EngineStoryPrivacy(base: .closeFriends, additionallyIncludePeers: []))
            return
        }
        if preview && !CommandLine.arguments.contains("--story-audiences-open-share") {
            openEditor(context: context, present: present)
            return
        }
        let state = ShareWithPeersScreen.StateContext(context: context, subject: .stories(editing: false, count: 1), initialSelectedPeers: [privacy.base: privacy.additionallyIncludePeers])
        let _ = (state.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).startStandalone(next: { _ in
            let screen = ShareWithPeersScreen(context: context, initialPrivacy: privacy, stateContext: state, completion: { _, privacy, _, _, _, _, completed in
                if completed {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        openStory(context: context, present: present, privacy: privacy)
                    }
                }
            }, editCategory: { privacy, _, _, _ in
                openPeople(context: context, present: present, privacy: privacy)
            })
            present(screen)
        })
    }

    static var preparePublication: (() -> Void)?
    static func installPublicationTransition(root: TelegramRootController) {
        editorPresenter = { [weak root] editor in root?.pushViewController(editor) }
        preparePublication = { [weak root] in (root?.chatListController as? ChatListControllerImpl)?.scrollToStories() }
        publicationTransition = { [weak root] in
            guard let view = (root?.chatListController as? ChatListControllerImpl)?.transitionViewForOwnStoryItem() else { return nil }
            return MediaEditorScreenImpl.TransitionOut(destinationView: view, destinationRect: view.bounds, destinationCornerRadius: view.bounds.height / 2)
        }
    }

    static func configure(context: AccountContext, present: @escaping (ViewController) -> Void) {
        presenter = present
        let _ = context.account.postbox.transaction { transaction in
            seed(transaction: transaction, mediaBox: context.account.postbox.mediaBox)
        }.startStandalone()
        let _ = ApplicationSpecificNotice.setDisplayStoryInteractionGuide(accountManager: context.sharedContext.accountManager).startStandalone()
        StoryAudienceUIHooks.configuration = { context in
            guard isEnabled else { return nil }
            let store = StoryAudienceStore.forAccount(context.account)
            var headerView: EdgeEffectView?
            let configuration = StoryAudienceConfiguration(store: store, icon: { audience, size in
                StoryAudienceEditor.icon(name: audience.icon, colorIndex: audience.colorIndex, size: size)
            }, color: { StoryAudienceEditor.colors[$0.colorIndex % StoryAudienceEditor.colors.count] }, edit: { id, source in
                let usesNavigation = source.navigationPresentation == .modal || id == nil
                let original = store.audience(id)
                let flowNavigation = source.navigationController as? NavigationController
                var draft: StoryAudienceEditor?
                weak var creationPicker: ShareWithPeersScreen?
                let presentFlow: (ViewController) -> Void = { [weak source] controller in
                    if usesNavigation {
                        if let picker = controller as? ShareWithPeersScreen { picker.prepareForAudienceNavigation() }
                        else { controller.navigationPresentation = .default }
                    }
                    if original == nil, let picker = controller as? ShareWithPeersScreen { creationPicker = picker }
                    if let navigation = flowNavigation {
                        if original == nil, let picker = controller as? ShareWithPeersScreen, !navigation.viewControllers.contains(where: { $0 === source }) {
                            picker.navigationPresentation = .modal
                            picker.modalPresentationAdditionalTopInset = 13.0
                        }
                        navigation.pushViewController(controller)
                    }
                    else {
                        if let picker = controller as? ShareWithPeersScreen, original == nil { picker.navigationPresentation = .modal; picker.modalPresentationAdditionalTopInset = 13.0 }
                        else if original == nil, let navigation = creationPicker?.navigationController as? NavigationController { navigation.pushViewController(controller); return }
                        presenter?(controller)
                    }
                }
                let showEditor: ([Int64]) -> Void = { members in
                    if let draft { draft.updateDraftMembers(members); presentFlow(draft); return }
                    let ids = entries.map { EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value($0.0)) }
                    let _ = (context.engine.data.get(EngineDataMap(ids.map { TelegramEngine.EngineData.Item.Peer.Peer(id: $0) })) |> deliverOnMainQueue).startStandalone(next: { peers in
                        weak var editorReference: StoryAudienceEditor?
                        let editor = StoryAudienceEditor(context: context, store: store, original: original, members: members, people: ids.compactMap { peers[$0] ?? nil }, editPeople: { selected, completion in
                            pickPeople(context: context, selected: selected, savingExisting: true, present: { picker in
                                (picker as? ShareWithPeersScreen)?.prepareForAudienceNavigation()
                                (editorReference?.navigationController as? NavigationController)?.pushViewController(picker)
                            }, completion: completion)
                        })
                        editorReference = editor
                        if original == nil && usesNavigation {
                            draft = editor
                            editor.creationBack = { [weak editor] in
                                if let editor { creationPicker?.updateAudiencePeopleSelection(editor.draftMembers) }
                                editor?.view.endEditing(true); editor?.dismiss()
                            }
                            editor.creationSaved = { [source, weak editor] in
                                (source as? ShareWithPeersScreen)?.applyCreatedAudience()
                                if let navigation = editor?.navigationController as? NavigationController, navigation.viewControllers.contains(where: { $0 === source }) {
                                    _ = navigation.popToViewController(source, animated: true)
                                } else if let picker = creationPicker, let navigation = picker.navigationController as? NavigationController,
                                          let index = navigation.viewControllers.firstIndex(where: { $0 === picker }), index > 0 {
                                    _ = navigation.popToViewController(navigation.viewControllers[index - 1], animated: true)
                                } else { editor?.dismiss() }
                            }
                        }
                        presentFlow(editor)
                    })
                }
                let begin = {
                    if let original { showEditor(original.members) }
                    else { pickPeople(context: context, selected: [], keepsForNextScreen: usesNavigation, present: presentFlow, completion: showEditor) }
                }
                if source.navigationPresentation == .flatModal {
                    source.dismiss(completion: { DispatchQueue.main.async(execute: begin) })
                } else { begin() }
            }, headerBackground: { size, transition in
                let view: EdgeEffectView
                if let current = headerView { view = current }
                else { view = EdgeEffectView(); headerView = view }
                view.isUserInteractionEnabled = false
                view.update(content: UIColor(rgb: 0x1e1c1f), blur: true, rect: CGRect(origin: .zero, size: size), edge: .top, edgeSize: min(64.0, size.height), transition: ComponentTransition(transition))
                return view
            })
            configuration.glyph = { audience, size in
                StoryAudienceIcons.image(audience.icon, size: size)
            }
            return configuration
        }
        audienceObservation?.dispose()
        // Existing published stories retain the segment identity; edits update their
        // stored privacy and deletion switches them to Everyone.
        audienceObservation = (StoryAudienceStore.forAccount(context.account).updated |> deliverOnMainQueue).start(next: { state in
            for story in state.stories {
                let base: EngineStoryPrivacy.Base
                switch story.base { case "contacts": base = .contacts; case "closeFriends": base = .closeFriends; case "nobody": base = .nobody; default: base = .everyone }
                let privacy = EngineStoryPrivacy(base: story.audienceId == nil ? base : .nobody, additionallyIncludePeers: story.members.map { EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value($0)) })
                let _ = context.engine.messages.editStoryPrivacy(id: story.id, privacy: privacy).startStandalone()
            }
        })
    }

    private static func pickPeople(context: AccountContext, selected: [Int64], keepsForNextScreen: Bool = false, savingExisting: Bool = false, present: @escaping (ViewController) -> Void, completion: @escaping ([Int64]) -> Void) {
        let ids = selected.map { EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value($0)) }
        let state = ShareWithPeersScreen.StateContext(context: context, subject: .contacts(base: .nobody), initialPeerIds: Set(ids))
        let _ = (state.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).startStandalone(next: { _ in
            let screen = ShareWithPeersScreen(context: context, initialPrivacy: EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: ids), audiencePeopleTitle: "Create List", stateContext: state, completion: { _, privacy, _, _, _, _, completed in
                if completed {
                    let selected = privacy.additionallyIncludePeers.map { $0.id._internalGetInt64Value() }
                    if keepsForNextScreen { completion(selected) }
                    else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { completion(selected) } }
                }
            })
            screen.audiencePeopleActionTitle = savingExisting ? "Save List" : nil
            screen.automaticallyDismissOnCompletion = !keepsForNextScreen
            present(screen)
        })
    }

    static func openFromCompose(context: AccountContext) {
        if let present = presenter { openEditor(context: context, present: present) }
    }

    static func openEditor(context: AccountContext, present: @escaping (ViewController) -> Void) {
        guard let assets = assetsURL,
              let image = UIImage(contentsOfFile: assets.appendingPathComponent("EditorStory.jpg").path) else { return }
        // A new demo story starts at Everyone, independently of the last edited story.
        StoryAudienceStore.forAccount(context.account).select(nil)
        let dimensions = PixelDimensions(width: Int32(image.size.width * image.scale), height: Int32(image.size.height * image.scale))
        let editor = MediaEditorScreenImpl(context: context, mode: .storyEditor(remainingCount: 100), subject: .single(.image(image: image, dimensions: dimensions, additionalImage: nil, additionalImagePosition: .topLeft, fromCamera: false)), transitionIn: .noAnimation, transitionOut: { finished, _ in
            return finished ? publicationTransition?() : nil
        }, completion: { results, commit in
            guard let result = results.first else { commit({}); return }
            publish(context: context, result: result, fallbackImage: image, completion: { commit({}) })
        })
        editor.navigationPresentation = .standaloneFlatModal
        if let editorPresenter { editorPresenter(editor) } else { present(editor) }
    }

    private static func publish(context: AccountContext, result: MediaEditorScreenImpl.Result, fallbackImage: UIImage, completion: @escaping () -> Void) {
        let rendered: UIImage
        if case let .image(image, _) = result.media { rendered = image } else { rendered = fallbackImage }
        guard let data = rendered.jpegData(compressionQuality: 0.9) else { return }
        let privacy = result.options.privacy
        let _ = (context.account.postbox.transaction { transaction -> Int32 in
            let now = Int32(Date().timeIntervalSince1970)
            let lastId = transaction.getStoryItems(peerId: authorId).last?.id ?? 0
            let lastSeenId = transaction.getPeerStoryState(peerId: authorId)?.maxSeenId ?? 0
            // The viewer's read marker can outlive a deleted story.
            let id = max(now, max(lastId, lastSeenId) + 1)
            let resource = LocalFileMediaResource(fileId: Int64(id))
            context.account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
            let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64(id)), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(rendered.size.width * rendered.scale), height: Int32(rendered.size.height * rendered.scale)), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            let viewerIds: [PeerId]
            if privacy.base == .nobody { viewerIds = Array(privacy.additionallyIncludePeers.prefix(4)) }
            else if privacy.base == .closeFriends {
                viewerIds = Array(transaction.getContactPeerIds().filter { id in (transaction.getPeer(id) as? TelegramUser)?.flags.contains(.isCloseFriend) == true }.sorted().prefix(4))
            } else { viewerIds = [7_880_002, 7_880_004, 7_880_007, 7_880_008].map { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) } }
            let item = Stories.Item(id: id, timestamp: now, expirationTimestamp: now + 86400, media: image, alternativeMediaList: [], mediaAreas: result.mediaAreas, text: result.caption.string, entities: [], views: Stories.Item.Views(seenCount: viewerIds.count, reactedCount: 0, forwardCount: 0, seenPeerIds: viewerIds, reactions: [], hasList: true), privacy: Stories.Item.Privacy(base: privacy.base, additionallyIncludePeers: privacy.additionallyIncludePeers), isPinned: result.options.pin, isExpired: false, isPublic: privacy.base == .everyone, isCloseFriends: privacy.base == .closeFriends, isContacts: privacy.base == .contacts, isSelectedContacts: privacy.base == .nobody, isForwardingDisabled: result.options.isForwardingDisabled, isEdited: false, isMy: true, myReaction: nil, forwardInfo: nil, music: nil, authorId: nil, folderIds: nil)
            if let entry = CodableEntry(Stories.StoredItem.item(item)) {
                var items = transaction.getStoryItems(peerId: authorId)
                items.append(StoryItemsTableEntry(value: entry, id: id, expirationTimestamp: item.expirationTimestamp, isCloseFriends: item.isCloseFriends, isLiveStream: false))
                transaction.setStoryItems(peerId: authorId, items: items)
                for row in items { transaction.setStory(id: StoryId(peerId: authorId, id: row.id), value: row.value) }
                if transaction.getPeerStoryState(peerId: authorId) == nil, let state = CodableEntry(Stories.PeerState(maxReadId: 0)) {
                    transaction.setPeerStoryState(peerId: authorId, state: StoredStoryPeerState(entry: state, maxSeenId: 0))
                }
                transaction.setStoryItemsInexactMaxId(peerId: authorId, id: id, hasLiveItems: false)
            }
            let (_, peers) = transaction.getAllStorySubscriptions(key: .filtered)
            transaction.replaceAllStorySubscriptions(key: .filtered, state: CodableEntry(Stories.SubscriptionsState(opaqueState: "offline", refreshId: 0, hasMore: false)), peerIds: peers)
            return id
        } |> deliverOnMainQueue).startStandalone(next: { id in
            let base: String
            switch privacy.base { case .everyone: base = "everyone"; case .contacts: base = "contacts"; case .closeFriends: base = "closeFriends"; case .nobody: base = "nobody" }
            StoryAudienceStore.forAccount(context.account).publish(id: id, base: base, members: privacy.additionallyIncludePeers.map { $0.id._internalGetInt64Value() })
            let _ = (context.engine.messages.storySubscriptions(isHidden: false) |> take(1) |> deliverOnMainQueue).startStandalone(next: { subscriptions in
                NSLog("StoryAudiences.Publish: local story count %d", subscriptions.accountItem?.storyCount ?? 0)
            })
            finishPublicationWhenTargetReady(attempt: 0, completion: completion)
        })
    }

    private static func finishPublicationWhenTargetReady(attempt: Int, completion: @escaping () -> Void) {
        preparePublication?()
        if publicationTransition?() != nil {
            NSLog("StoryAudiences.Publish: original avatar target ready")
            completion()
        } else if attempt < 30 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finishPublicationWhenTargetReady(attempt: attempt + 1, completion: completion) }
        } else {
            NSLog("StoryAudiences.Publish: avatar target not ready")
            completion()
        }
    }

    private static func storyImage(named name: String, resourceId: Int64, mediaBox: MediaBox) -> TelegramMediaImage? {
        guard let assets = assetsURL,
              let data = try? Data(contentsOf: assets.appendingPathComponent(name)),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let resource = LocalFileMediaResource(fileId: resourceId)
        mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
        return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: resourceId), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(width), height: Int32(height)), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
    }

    private static func openStory(context: AccountContext, present: @escaping (ViewController) -> Void, privacy: EngineStoryPrivacy) {
        guard let image = storyImage(named: "PublishedStory.jpg", resourceId: publishedStoryResourceId, mediaBox: context.account.postbox.mediaBox) else { return }
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: authorId)) |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer else { return }
            let content = StoryAudiencesLocalStoryContext(peer: peer, image: image, privacy: privacy)
            let viewer = StoryContainerScreen(context: context, content: content, transitionIn: nil, transitionOut: { _, _ in nil })
            let _ = (ApplicationSpecificNotice.setDisplayStoryInteractionGuide(accountManager: context.sharedContext.accountManager)
            |> deliverOnMainQueue).startStandalone(completed: {
                present(viewer)
            })
        })
    }
    private static func openPeople(context: AccountContext, present: @escaping (ViewController) -> Void, privacy: EngineStoryPrivacy) {
        let state = ShareWithPeersScreen.StateContext(context: context, subject: .contacts(base: privacy.base), initialPeerIds: Set(privacy.additionallyIncludePeers))
        let _ = (state.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).startStandalone(next: { _ in
            let screen = ShareWithPeersScreen(context: context, initialPrivacy: privacy, stateContext: state, completion: { _, selectedPrivacy, _, _, _, _, completed in
                if completed { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { open(context: context, present: present, privacy: selectedPrivacy, preview: false) } }
            })
            present(screen)
        })
    }
}

private final class StoryAudiencesLocalStoryContext: StoryContentContext {
    let stateValue: StoryContentContextState?
    var state: Signal<StoryContentContextState, NoError> { return .single(self.stateValue!) }
    var updated: Signal<Void, NoError> { return .never() }
    init(peer: EnginePeer, image: TelegramMediaImage, privacy: EngineStoryPrivacy) {
        let now = Int32(Date().timeIntervalSince1970)
        let story = EngineStoryItem(id: 1, timestamp: now, expirationTimestamp: now + 86400, media: EngineMedia(image), alternativeMediaList: [], mediaAreas: [], text: "", entities: [], views: nil, privacy: privacy, isPinned: false, isExpired: false, isPublic: privacy.base == .everyone, isPending: false, isCloseFriends: privacy.base == .closeFriends, isContacts: privacy.base == .contacts, isSelectedContacts: privacy.base == .nobody, isForwardingDisabled: false, isEdited: false, isMy: true, myReaction: nil, forwardInfo: nil, music: nil, author: nil, folderIds: nil)
        let item = StoryContentItem(id: EngineStoryId(peerId: peer.id, id: 1), position: 0, dayCounters: nil, peerId: peer.id, storyItem: story, entityFiles: [:], itemPeer: nil)
        let data = StoryContentContextState.AdditionalPeerData(isMuted: false, areVoiceMessagesAvailable: false, presence: nil, canViewStats: false, isPremiumRequiredForMessaging: false, preferHighQualityStories: false, boostsToUnrestrict: nil, appliedBoosts: nil, sendPaidMessageStars: nil)
        self.stateValue = StoryContentContextState(slice: .init(peer: peer, additionalPeerData: data, item: item, totalCount: 1, previousItemId: nil, nextItemId: nil, allItems: [item], forwardInfoStories: [:]), previousSlice: nil, nextSlice: nil)
    }
    func resetSideStates() {}
    func navigate(navigation: StoryContentContextNavigation) {}
    func markAsSeen(id: EngineStoryId) {}
}
