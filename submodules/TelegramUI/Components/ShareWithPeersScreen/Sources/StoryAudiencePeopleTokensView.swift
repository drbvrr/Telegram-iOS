import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import LocalizedPeerData
import AvatarNode
import ComponentFlow
import GlassBackgroundComponent

/// The new horizontal selection treatment uses the same AvatarNode as contact rows.
final class StoryAudiencePeopleTokensView: UIScrollView {
    private final class Token {
        let view = UIView()
        let avatar = AvatarNode(font: avatarPlaceholderFont(size: 23))
        let title = UILabel()
        let removeGlass = GlassBackgroundView(frame: .zero)
        let remove = UIButton()
        init() {
            view.addSubview(avatar.view); view.addSubview(title); view.addSubview(removeGlass)
            removeGlass.contentView.addSubview(remove)
            title.font = Font.regular(12); title.textColor = .white; title.textAlignment = .center
            title.lineBreakMode = .byTruncatingTail
            remove.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)), for: .normal)
            remove.tintColor = .white
            remove.backgroundColor = .clear
        }
    }
    private var tokens: [EnginePeer.Id: Token] = [:]
    override init(frame: CGRect) {
        super.init(frame: frame); showsHorizontalScrollIndicator = false; clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(context: AccountContext, theme: PresentationTheme, peers: [EnginePeer], transition: ComponentTransition, remove: @escaping (EnginePeer.Id) -> Void) {
        let ids = Set(peers.map(\.id))
        for id in Array(tokens.keys) where !ids.contains(id) {
            guard let token = tokens.removeValue(forKey: id) else { continue }
            // Remove interaction and accessibility immediately; the native glass
            // can keep its visual fade while the selection state is already gone.
            token.view.isUserInteractionEnabled = false
            token.view.accessibilityElementsHidden = true
            token.view.alpha = 0.0
            token.view.layer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { _ in token.view.removeFromSuperview() })
            token.view.layer.animateScale(from: 1, to: 0.01, duration: 0.2, removeOnCompletion: false)
        }
        for (i, peer) in peers.enumerated() {
            let token: Token
            if let current = tokens[peer.id] { token = current }
            else {
                token = Token(); tokens[peer.id] = token; addSubview(token.view)
                token.avatar.setPeer(accountPeerId: context.account.peerId, postbox: context.account.postbox, network: context.account.network, contentSettings: context.currentContentSettings.with { $0 }, theme: theme, peer: peer, synchronousLoad: true, displayDimensions: CGSize(width: 62, height: 62))
                token.view.layer.animateScale(from: 0.01, to: 1, duration: 0.3)
                token.view.layer.animateAlpha(from: 0, to: 1, duration: 0.2)
                token.remove.addAction(UIAction { _ in remove(peer.id) }, for: .touchUpInside)
            }
            let frame = CGRect(x: 12 + CGFloat(i) * 82, y: 10, width: 78, height: 86)
            if token.view.frame == .zero { token.view.frame = frame }
            else { transition.setFrame(view: token.view, frame: frame) }
            token.avatar.frame = CGRect(x: 8, y: 0, width: 62, height: 62)
            token.title.text = peer.compactDisplayTitle; token.title.frame = CGRect(x: 0, y: 66, width: 78, height: 16)
            transition.setFrame(view: token.removeGlass, frame: CGRect(x: 51, y: -5, width: 24, height: 24))
            token.remove.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            token.removeGlass.update(size: CGSize(width: 24, height: 24), cornerRadius: 12, isDark: true, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            token.remove.accessibilityLabel = "Remove " + peer.compactDisplayTitle
        }
        contentSize = CGSize(width: 24 + CGFloat(peers.count) * 82, height: 96)
    }
}
