import Foundation
import UIKit
import ShareWithPeersScreen
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import AsyncDisplayKit
import AvatarNode

final class StoryPrivacyIconComponent: Component {
    enum Privacy {
        case everyone
        case closeFriends
        case contacts
        case selectedContacts
    }
    let audienceLayout: Bool
    let privacy: Privacy
    let customImage: UIImage?
    let customColor: UIColor?
    let isEditable: Bool
    
    init(privacy: Privacy, isEditable: Bool, audienceLayout: Bool = false, customImage: UIImage? = nil, customColor: UIColor? = nil) {
        self.audienceLayout = audienceLayout
        self.customImage = customImage; self.customColor = customColor
        self.privacy = privacy
        self.isEditable = isEditable
    }

    static func ==(lhs: StoryPrivacyIconComponent, rhs: StoryPrivacyIconComponent) -> Bool {
        if lhs.audienceLayout != rhs.audienceLayout { return false }
        if lhs.customImage != rhs.customImage || lhs.customColor != rhs.customColor { return false }
        if lhs.privacy != rhs.privacy {
            return false
        }
        if lhs.isEditable != rhs.isEditable {
            return false
        }
        return true
    }

    final class View: UIImageView {
        private let iconView = UIImageView()
        
        private var component: StoryPrivacyIconComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StoryPrivacyIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousPrivacy = self.component?.privacy
            self.component = component
            self.state = state
            
            var colors: [CGColor]
            var icon: UIImage?
            
            if let previousPrivacy, previousPrivacy != component.privacy, !transition.animation.isImmediate {
                let disappearingBackgroundView = UIImageView(image: self.image)
                disappearingBackgroundView.frame = self.bounds
                self.insertSubview(disappearingBackgroundView, at: 0)
                
                disappearingBackgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak disappearingBackgroundView] _ in
                    disappearingBackgroundView?.removeFromSuperview()
                })
                
                let disappearingIconView = UIImageView(image: self.iconView.image)
                disappearingIconView.frame = self.iconView.frame
                self.insertSubview(disappearingIconView, belowSubview: self.iconView)
                
                disappearingIconView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak disappearingIconView] _ in
                    disappearingIconView?.removeFromSuperview()
                })
                disappearingIconView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                
                self.iconView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.iconView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
            }
            
            switch component.privacy {
            case .everyone:
                colors = [UIColor(rgb: 0x4faaff).cgColor, UIColor(rgb: 0x017aff).cgColor]
                icon = UIImage(bundleImageName: "Stories/PrivacyEveryone")
            case .closeFriends:
                colors = [UIColor(rgb: 0x87d93a).cgColor, UIColor(rgb: 0x31b73b).cgColor]
                icon = UIImage(bundleImageName: "Stories/PrivacyCloseFriends")
            case .contacts:
                colors = [UIColor(rgb: 0xc36eff).cgColor, UIColor(rgb: 0x8c61fa).cgColor]
                icon = UIImage(bundleImageName: "Stories/PrivacyContacts")
            case .selectedContacts:
                colors = [UIColor(rgb: 0xffb643).cgColor, UIColor(rgb: 0xf69a36).cgColor]
                icon = UIImage(bundleImageName: "Stories/PrivacySelectedContacts")
            }
            
            let usesAudienceStyle = component.audienceLayout || component.customColor != nil
            if usesAudienceStyle && component.customImage == nil {
                let name: String
                let stops: (UInt32, UInt32)
                switch component.privacy {
                case .everyone: name = "Everyone"; stops = (0x45a7ff, 0x1184ff)
                case .contacts: name = "My Contacts"; stops = (0xcd7efe, 0xae51dd)
                case .closeFriends: name = "Close Friends"; stops = (0x57eb73, 0x1ccb46)
                case .selectedContacts: name = "Person"; stops = (0xf7b73d, 0xf29800)
                }
                colors = [UIColor(rgb: stops.0).cgColor, UIColor(rgb: stops.1).cgColor]
                icon = StoryAudienceGlyphs.image(name, size: 20)
            }
            if let customImage = component.customImage { icon = customImage }
            if let color = component.customColor {
                if let pair = StoryAudienceAppearance.palette.first(where: { UIColor(rgb: $0.0).isEqual(color) }) { colors = [UIColor(rgb: pair.0).cgColor, UIColor(rgb: pair.1).cgColor] }
                else { colors = [color.cgColor, color.cgColor] }
            }
            let unifiedCapsule = component.isEditable && usesAudienceStyle
            let size = unifiedCapsule ? CGSize(width:45,height:27) : CGSize(width:component.isEditable ? 40 : 24,height:24)
            let iconSide: CGFloat = usesAudienceStyle ? 20 : size.height
            let iconX: CGFloat = unifiedCapsule ? (component.customImage == nil ? 4.5 : 5) : (component.isEditable ? 1 : 0)
            let iconFrame = CGRect(x: iconX, y: (size.height-iconSide)/2, width:iconSide,height:iconSide)
            self.iconView.image = icon
            self.iconView.bounds = CGRect(origin: .zero, size: iconFrame.size)
            self.iconView.center = iconFrame.center
            
            self.image = generateImage(size, contextGenerator: { size, context in
                let bounds = CGRect(origin: .zero, size: size)
                context.clear(bounds)
                
                let path: CGPath
                if size.width == size.height {
                    path = CGPath(ellipseIn: bounds, transform: nil)
                } else {
                    path = CGPath(roundedRect: bounds, cornerWidth: size.height / 2.0, cornerHeight: size.height / 2.0, transform: nil)
                }
                
                context.addPath(path)
                context.clip()
                
                var locations: [CGFloat] = usesAudienceStyle ? [0.0, 1.0] : [1.0, 0.0]
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                
                if usesAudienceStyle {
                    context.setFillColor(UIColor.white.withAlphaComponent(0.02).cgColor)
                    context.fill(bounds)
                    context.saveGState()
                    context.addPath(path); context.setLineWidth(1.1); context.replacePathWithStrokedPath(); context.clip()
                    let rim = CGGradient(colorsSpace: colorSpace, colors: [UIColor.white.withAlphaComponent(0.45).cgColor, UIColor.white.withAlphaComponent(0.05).cgColor, UIColor.white.withAlphaComponent(0.3).cgColor] as CFArray, locations: [0, 0.5, 1])!
                    context.drawLinearGradient(rim, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                    context.restoreGState()
                }
                if component.isEditable {
                    if let arrowIcon = UIImage(bundleImageName: "Stories/PrivacyDownArrow"), let cgImage = arrowIcon.cgImage {
                        context.draw(cgImage, in: CGRect(origin: CGPoint(x: size.width - arrowIcon.size.width - 6.0, y: floorToScreenPixels((size.height - arrowIcon.size.height) / 2.0)), size: arrowIcon.size))
                    }
                }
            })
                
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
