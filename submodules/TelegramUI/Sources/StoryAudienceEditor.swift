import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import AvatarNode
import TelegramCore
import AccountContext
import LocalizedPeerData
import ShareWithPeersScreen
import ItemListUI
import ReactionSelectionNode

// Only the new audience detail screen is drawn here. Glass and peer avatars use
// Telegram's existing renderers; contact picking is delegated to its native screen.
final class StoryAudienceEditor: ViewController, UITextFieldDelegate {
    private let context: AccountContext
    private let store: StoryAudienceStore
    private let original: StoryAudience?
    private let people: [EnginePeer]
    private var members: [Int64]
    private var iconName: String
    private let colorIndex: Int
    private let editPeople: ([Int64], @escaping ([Int64]) -> Void) -> Void
    private let panel = UIView()
    private let scroll = UIScrollView()
    private let nameField = UITextField()
    private let iconButton = UIButton()
    private let heroGlyph = UIImageView()
    private var isReplacingGlyph = false
    private var glyphRevision = 0
    private let changeButton = UIButton()
    private let group = UIView()
    private let nameLabel = UILabel()
    private let peopleLabel = UILabel()
    private let footnote = UILabel()
    private let deleteButton = UIButton()
    private let backGlass = GlassBackgroundView(frame: .zero)
    private let saveGlass = GlassBackgroundView(frame: .zero)
    private let backButton = UIButton()
    private let saveButton = UIButton()
    private var menu: StoryAudienceIconCloud?
    var draftMembers: [Int64] { members }
    var creationBack: (() -> Void)?
    var creationSaved: (() -> Void)?
    func updateDraftMembers(_ ids: [Int64]) {
        members = ids
        if isNodeLoaded { rebuildPeople(); changed(); if let layout { containerLayoutUpdated(layout, transition: .immediate) } }
    }
    private var layout: ContainerViewLayout?
    private var didFocus = false
    private var didSave = false
    private var avatarNodes: [AvatarNode] = []
    private var memberRows: [StoryAudienceMemberRow] = []
    private let cardColor = UIColor(rgb: 0x2e2c31)
    private let secondary = UIColor(rgb: 0x98989f)
    private let accent = UIColor(rgb: 0x008bff)
    static let colors: [UIColor] = [UIColor(rgb: 0x827fff), UIColor(rgb: 0xf7b73d), UIColor(rgb: 0xf96a5f), UIColor(rgb: 0x5fcef9)]

    init(context: AccountContext, store: StoryAudienceStore, original: StoryAudience?, members: [Int64], people: [EnginePeer], editPeople: @escaping ([Int64], @escaping ([Int64]) -> Void) -> Void) {
        self.context = context; self.store = store; self.original = original
        self.members = members; self.people = people; self.iconName = original?.icon ?? "Person"
        self.colorIndex = original?.colorIndex ?? store.value.nextColorIndex
        self.editPeople = editPeople
        super.init(navigationBarPresentationData: nil)
        self.navigationPresentation = .modal
        self._hasGlassStyle = true
        self.modalPresentationAdditionalTopInset = 13.0
        self.modalPresentationDimAlpha = 0.75
        self.modalPresentationDimColor = UIColor(red: 22.4 / 255, green: 22.4 / 255, blue: 24.0 / 255, alpha: 1)
        self.statusBar.statusBarStyle = .Ignore
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static let iconCache = NSCache<NSString, UIImage>()
    static func icon(name: String, colorIndex: Int, size: CGFloat) -> UIImage {
        let key = "\(name):\(colorIndex % colors.count):\(size)" as NSString
        if let image = iconCache.object(forKey: key) { return image }
        let stops = StoryAudienceAppearance.palette[colorIndex % colors.count]
        let glyphSize: CGFloat = size > 80 ? 72 : 28
        let glyph = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            StoryAudienceIcons.image(name, size: glyphSize).draw(in: CGRect(x: (size - glyphSize) / 2, y: (size - glyphSize) / 2, width: glyphSize, height: glyphSize))
        }
        let image = StoryAudienceAppearance.image(size: CGSize(width:size,height:size), top: stops.0, bottom: stops.1, glyph: glyph)
        iconCache.countLimit = 128
        iconCache.setObject(image, forKey: key)
        return image
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()
        view.backgroundColor = .clear
        panel.backgroundColor = UIColor(rgb: 0x1e1c1f); panel.layer.cornerRadius = 38
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]; panel.clipsToBounds = true
        view.addSubview(panel); panel.addSubview(scroll)
        scroll.keyboardDismissMode = .interactive
        scroll.contentInsetAdjustmentBehavior = .never
        [iconButton, changeButton, nameLabel, nameField, peopleLabel, group, footnote].forEach { scroll.addSubview($0) }
        nameLabel.text = "LIST NAME"; peopleLabel.text = "WHO'S IN THIS LIST"
        for label in [nameLabel, peopleLabel, footnote] { label.font = Font.regular(13); label.textColor = secondary }
        let footnoteParagraph = NSMutableParagraphStyle()
        footnoteParagraph.minimumLineHeight = 18; footnoteParagraph.maximumLineHeight = 18
        footnote.attributedText = NSAttributedString(string: "People you add won't know they're\nin this list. Only you see it", attributes: [.font: Font.regular(13), .foregroundColor: secondary, .paragraphStyle: footnoteParagraph])
        footnote.numberOfLines = 0
        nameField.text = original?.name; nameField.placeholder = "Name"; nameField.font = Font.regular(17)
        nameField.keyboardAppearance = .dark
        nameField.attributedPlaceholder = NSAttributedString(string: "Name", attributes: [.foregroundColor: secondary])
        nameField.textColor = .white; nameField.tintColor = accent; nameField.backgroundColor = cardColor
        nameField.layer.cornerRadius = 26; nameField.delegate = self; nameField.returnKeyType = .default
        nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 52)); nameField.leftViewMode = .always
        nameField.addTarget(self, action: #selector(changed), for: .editingChanged)
        nameField.accessibilityIdentifier = "storyAudienceName"
        changeButton.setTitle("Change icon", for: .normal); changeButton.setTitleColor(accent, for: .normal)
        changeButton.titleLabel?.font = Font.regular(17); changeButton.addTarget(self, action: #selector(showIcons), for: .touchUpInside)
        let stops = StoryAudienceAppearance.palette[colorIndex % Self.colors.count]
        iconButton.setImage(StoryAudienceAppearance.image(size: CGSize(width: 102, height: 102), top: stops.0, bottom: stops.1), for: .normal)
        heroGlyph.isUserInteractionEnabled = false
        iconButton.addSubview(heroGlyph)
        iconButton.addTarget(self, action: #selector(showIcons), for: .touchUpInside)
        group.backgroundColor = cardColor; group.layer.cornerRadius = 28; group.clipsToBounds = true
        deleteButton.setTitle("Delete List", for: .normal); deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.titleLabel?.font = Font.regular(17); deleteButton.backgroundColor = cardColor; deleteButton.layer.cornerRadius = 26
        deleteButton.addTarget(self, action: #selector(deleteAudience), for: .touchUpInside)
        if original != nil { panel.addSubview(deleteButton) }
        panel.addSubview(backGlass); panel.addSubview(saveGlass)
        backGlass.contentView.addSubview(backButton); saveGlass.contentView.addSubview(saveButton)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)), for: .normal)
        var saveConfiguration = UIButton.Configuration.plain()
        saveConfiguration.image = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        saveConfiguration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        saveConfiguration.baseForegroundColor = .white
        saveConfiguration.imageColorTransformer = UIConfigurationColorTransformer { [weak saveButton] _ in UIColor.white.withAlphaComponent(saveButton?.isEnabled == false ? 0.35 : 1.0) }
        saveConfiguration.contentInsets = .zero
        saveButton.configuration = saveConfiguration
        for button in [backButton, saveButton] { button.tintColor = .white }
        backButton.accessibilityLabel = "Back"; saveButton.accessibilityLabel = "Save list"
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveAudience), for: .touchUpInside)
        rebuildPeople(); changed()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if original == nil && !didFocus {
            didFocus = nameField.becomeFirstResponder()
        }
    }
    private func rebuildPeople() {
        group.subviews.forEach { $0.removeFromSuperview() }; avatarNodes.removeAll(); memberRows.removeAll()
        let edit = UIButton(); edit.setTitle("Edit people", for: .normal); edit.setTitleColor(accent, for: .normal)
        edit.titleLabel?.font = Font.regular(17); edit.contentHorizontalAlignment = .left
        var editConfiguration = UIButton.Configuration.plain()
        editConfiguration.title = "Edit people"
        editConfiguration.image = UIImage(bundleImageName: "StoryAudiences/EditPeople")
        editConfiguration.imagePadding = 12
        editConfiguration.baseForegroundColor = accent
        editConfiguration.contentInsets = .zero
        edit.configuration = editConfiguration
        edit.frame = CGRect(x: 16, y: 10, width: 338, height: 38)
        edit.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.view.endEditing(true)
            if let creationBack = self.creationBack { creationBack(); return }
            self.editPeople(self.members) { [weak self] ids in
                guard let self else { return }; self.members = ids; self.rebuildPeople(); self.changed()
                if let layout = self.layout { self.containerLayoutUpdated(layout, transition: .animated(duration: 0.3, curve: .spring)) }
            }
        }, for: .touchUpInside)
        group.addSubview(edit)
        let theme = context.sharedContext.currentPresentationData.with { $0 }.theme
        for (i, id) in members.enumerated() {
            guard let peer = people.first(where: { $0.id.id._internalGetInt64Value() == id }) else { continue }
            let row = StoryAudienceMemberRow()
            row.frame = CGRect(x: 0, y: 56 + CGFloat(i) * 54, width: group.bounds.width == 0 ? 370 : group.bounds.width, height: 54)
            let content = row.content
            content.frame = row.bounds
            content.isUserInteractionEnabled = false
            row.accessibilityIdentifier = "audienceMember-\(id)"
            row.isAccessibilityElement = true; row.accessibilityLabel = peer.compactDisplayTitle
            row.setRevealOptions(([], [.init(key: 0, title: "Delete", icon: .animation(animation: "anim_delete", scale: 1.0, offset: 0.0, replaceColors: nil, flip: false), color: theme.list.itemDisclosureActions.destructive.fillColor, iconColor: .white, textColor: .white, isDestructive: true)]))
            row.onReveal = { [weak self, weak row] in
                guard let self, let row else { return }
                for other in self.memberRows where other !== row { other.setRevealOptionsOpened(false, animated: true) }
            }
            row.onRemove = { [weak self] in self?.confirmRemove(id: id, name: peer.compactDisplayTitle) }
            row.updateLayout(size: row.bounds.size, leftInset: 0, rightInset: 0)
            group.addSubview(row); memberRows.append(row)
            let avatar = AvatarNode(font: avatarPlaceholderFont(size: 17))
            avatar.setPeer(accountPeerId: context.account.peerId, postbox: context.account.postbox, network: context.account.network, contentSettings: context.currentContentSettings.with { $0 }, theme: theme, peer: peer, synchronousLoad: true)
            avatar.frame = CGRect(x: 16, y: 8, width: 38, height: 38)
            content.addSubview(avatar.view); avatarNodes.append(avatar)
            let label = UILabel(frame: CGRect(x: 66, y: 0, width: 240, height: 54))
            label.font = Font.medium(17); label.textColor = .white; label.text = peer.compactDisplayTitle; content.addSubview(label)
            let separator = UIView(frame: CGRect(x: 68, y: 0, width: 286, height: UIScreenPixel))
            separator.backgroundColor = UIColor.white.withAlphaComponent(0.08); content.addSubview(separator)
        }
    }
    private func confirmRemove(id: Int64, name: String) {
        view.endEditing(true)
        let alert = UIAlertController(title: "Remove person?", message: "\(name) will no longer see stories you post to this list", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            self.members.removeAll { $0 == id }; self.rebuildPeople(); self.changed()
            if let layout = self.layout { self.containerLayoutUpdated(layout, transition: .animated(duration: 0.3, curve: .spring)) }
        }))
        self.present(alert, animated: true)
    }
    @objc private func changed() {
        let dirty = original == nil || nameField.text != original?.name || iconName != original?.icon || Set(members) != Set(original?.members ?? [])
        let valid = !(nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        saveGlass.isHidden = !dirty; saveButton.isEnabled = valid; saveButton.alpha = 1
        updateSaveGlass()
        if !isReplacingGlyph { heroGlyph.image = StoryAudienceIcons.image(iconName, size: 72) }
    }
    private func updateSaveGlass() {
        saveButton.setNeedsUpdateConfiguration()
        saveGlass.update(size: saveGlass.bounds.size, cornerRadius: 22, isDark: true, tintColor: .init(kind: .custom(style: .default, color: accent)), transition: .immediate)
    }
    @objc private func saveAudience() {
        guard !didSave, store.save(id: original?.id, name: nameField.text ?? "", icon: iconName, members: members) != nil else { return }
        didSave = true; saveButton.isEnabled = false
        view.endEditing(true)
        if let creationSaved { creationSaved() } else { dismiss() }
    }
    @objc private func deleteAudience() {
        guard let original else { return }
        view.endEditing(true)
        let alert = UIAlertController(title: "Delete \(original.name)?", message: "Stories you posted to this list will become visible to Everyone", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }; self.store.delete(original.id); self.dismiss()
        }))
        present(alert, animated: true)
    }
    @objc private func goBack() { view.endEditing(true); if let creationBack { creationBack() } else { dismiss() } }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { textField.resignFirstResponder(); return true }
    @objc private func showIcons() {
        view.endEditing(true)
        if let menu { menu.close(); self.menu = nil; return }
        let cloud = StoryAudienceIconCloud(theme: context.sharedContext.currentPresentationData.with { $0 }.theme)
        cloud.frame = CGRect(x: panel.bounds.midX - 112, y: 144.28, width: 224, height: 243.724)
        let icons = ["Person", "Members", "Replies", "Home", "Heart", "Work", "Book", "Location", "Car", "Lock", "Crown", "Code", "Fire", "Sound", "Vine", "Verified"]
        for (i, name) in icons.enumerated() {
            let b = UIButton(frame: CGRect(x: 12 + CGFloat(i % 4) * 50, y: 32.72 + CGFloat(i / 4) * 50, width: 50, height: 50))
            b.accessibilityLabel = "Audience icon " + name
            b.setImage(StoryAudienceIcons.image(name, size: 32, color: name == iconName ? .white : UIColor.white.withAlphaComponent(0.4)), for: .normal)
            b.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.menu?.close(); self.menu = nil
                guard name != self.iconName else { return }
                self.iconName = name
                self.glyphRevision += 1
                let revision = self.glyphRevision
                self.isReplacingGlyph = true
                self.changed()
                let image = StoryAudienceIcons.image(name, size: 72)
                if UIAccessibility.isReduceMotionEnabled {
                    self.heroGlyph.image = image
                    self.heroGlyph.alpha = 1; self.heroGlyph.transform = .identity
                    self.isReplacingGlyph = false
                    return
                }
                // One image view and an invisible hand-off: never overlap two symbols.
                UIView.animate(withDuration: 0.10, delay: 0, options: [.beginFromCurrentState, .curveEaseOut], animations: {
                    self.heroGlyph.alpha = 0
                    self.heroGlyph.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
                }, completion: { [weak self] _ in
                    guard let self, self.glyphRevision == revision else { return }
                    UIView.performWithoutAnimation { self.heroGlyph.image = image }
                    UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                        self.heroGlyph.alpha = 1
                        self.heroGlyph.transform = .identity
                    }, completion: { [weak self] _ in
                        guard let self, self.glyphRevision == revision else { return }
                        self.isReplacingGlyph = false
                    })
                })
            }, for: .touchUpInside)
            cloud.addSubview(b)
        }
        panel.addSubview(cloud); menu = cloud; cloud.open()
    }
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition); self.layout = layout
        let panelFrame = CGRect(origin: .zero, size: layout.size)
        transition.updateFrame(view: panel, frame: panelFrame)
        scroll.frame = panel.bounds
        let w = panel.bounds.width
        backGlass.frame = CGRect(x: 16, y: 16, width: 44, height: 44)
        saveGlass.frame = CGRect(x: w - 60, y: 16, width: 44, height: 44)
        backButton.frame = backGlass.bounds; saveButton.frame = saveGlass.bounds
        backGlass.update(size: backGlass.bounds.size, cornerRadius: 22, isDark: true, tintColor: .init(kind: .panel), transition: .immediate)
        updateSaveGlass()
        iconButton.frame = CGRect(x: (w - 102) / 2, y: 48, width: 102, height: 102)
        // Setting frame during a transform animation changes bounds and causes a jump.
        heroGlyph.bounds = CGRect(x: 0, y: 0, width: 72, height: 72)
        heroGlyph.center = CGPoint(x: 51, y: 51)
        changeButton.frame = CGRect(x: 0, y: 153, width: w, height: 40)
        nameLabel.frame = CGRect(x: 32, y: 216, width: w - 64, height: 18)
        nameField.frame = CGRect(x: 16, y: 242, width: w - 32, height: 52)
        peopleLabel.frame = CGRect(x: 32, y: 322, width: w - 64, height: 18)
        group.frame = CGRect(x: 16, y: 348, width: w - 32, height: 61 + CGFloat(members.count) * 54)
        footnote.frame = CGRect(x: 32, y: group.frame.maxY + 10, width: w - 64, height: 40)
        if original != nil {
            if members.count <= 4 {
                panel.addSubview(deleteButton)
                deleteButton.frame = CGRect(x: 32, y: panel.bounds.height - layout.safeInsets.bottom - 88, width: w - 64, height: 52)
            } else {
                scroll.addSubview(deleteButton)
                deleteButton.frame = CGRect(x: 32, y: footnote.frame.maxY + 44, width: w - 64, height: 52)
            }
        }
        scroll.contentSize = CGSize(width: w, height: max(footnote.frame.maxY + 32, members.count > 4 && original != nil ? deleteButton.frame.maxY + 40 : 0))
        scroll.contentInset.bottom = layout.inputHeight ?? 0
    }
}

// Telegram's current reveal implementation (also used by native item lists),
// with its original touch recognizer, measured spring, overswipe and trash animation.
private final class StoryAudienceMemberRow: ItemListRevealOptionsItemView {
    let content = UIView()
    var onRemove: (() -> Void)?
    var onReveal: (() -> Void)?
    override init() { super.init(); addSubview(content) }
    required init?(coder: NSCoder) { preconditionFailure() }
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateBounds(layer: content.layer, bounds: CGRect(x: -offset, y: 0, width: content.bounds.width, height: content.bounds.height))
    }
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        setRevealOptionsOpened(false, animated: true)
        onRemove?()
    }
    override func revealOptionsInteractivelyOpened() { onReveal?() }
}
