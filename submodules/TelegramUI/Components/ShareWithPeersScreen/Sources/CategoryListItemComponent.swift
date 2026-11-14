import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import MultilineTextComponent
import AvatarNode
import TelegramPresentationData
import CheckNode
import BundleIconComponent

final class CategoryListItemComponent: Component {
    enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool, isTinted: Bool)
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let title: String
    let color: ShareWithPeersScreenComponent.CategoryColor
    let iconName: String?
    let subtitle: String?
    let audienceLayout: Bool
    let customImage: UIImage?
    let isCreateList: Bool
    let selectionState: SelectionState
    let hasNext: Bool
    let action: () -> Void
    let secondaryAction: () -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        title: String,
        color: ShareWithPeersScreenComponent.CategoryColor,
        iconName: String?,
        subtitle: String?,
        audienceLayout: Bool = false,
        customImage: UIImage? = nil,
        isCreateList: Bool = false,
        selectionState: SelectionState,
        hasNext: Bool,
        action: @escaping () -> Void,
        secondaryAction: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.title = title
        self.color = color
        self.iconName = iconName
        self.subtitle = subtitle
        self.audienceLayout = audienceLayout
        self.customImage = customImage
        self.isCreateList = isCreateList
        self.selectionState = selectionState
        self.hasNext = hasNext
        self.action = action
        self.secondaryAction = secondaryAction
    }
    
    static func ==(lhs: CategoryListItemComponent, rhs: CategoryListItemComponent) -> Bool {
        if lhs.audienceLayout != rhs.audienceLayout || lhs.customImage != rhs.customImage || lhs.isCreateList != rhs.isCreateList { return false }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let selectionButton = HighlightTrackingButton()
        private let containerButton: HighlightTrackingButton
        
        private let title = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let labelArrow = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        private static let audienceCheckImage = UIImage(bundleImageName: "StoryAudiences/Check")
        private let audienceCheck = UIImageView()
        private let iconView: UIImageView
        
        private var checkLayer: CheckLayer?
        
        private var component: CategoryListItemComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            
            self.containerButton = HighlightTrackingButton()
            
            self.iconView = UIImageView()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            self.addSubview(self.containerButton)
            self.containerButton.addSubview(self.iconView)
            self.containerButton.addSubview(self.audienceCheck)
            
            self.addSubview(self.selectionButton)
            self.selectionButton.addTarget(self, action: #selector(self.selectionPressed), for: .touchUpInside)
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func selectionPressed() { self.component?.action() }

        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            if component.audienceLayout { component.secondaryAction(); return }
            if case .editing(true, _) = component.selectionState {
                component.secondaryAction()
            } else {
                component.action()
            }
        }
        
        func update(component: CategoryListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let iconUpdated = self.component?.iconName != component.iconName || self.component?.color != component.color
            let themeUpdated = self.component?.theme !== component.theme
            
            var hasSelectionUpdated = false
            if let previousComponent = self.component {
                switch previousComponent.selectionState {
                case .none:
                    if case .none = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                case .editing:
                    if case .editing = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                }
            }
            
            if (self.component?.iconName != component.iconName || self.component?.color != component.color), let iconName = component.iconName {
                let colors: [UIColor]
                var iconScale: CGFloat = 1.0
                switch component.color {
                case .blue:
                    colors = [UIColor(rgb: 0x4faaff), UIColor(rgb: 0x017aff)]
                case .yellow:
                    colors = [UIColor(rgb: 0xffb643), UIColor(rgb: 0xf69a36)]
                case .green:
                    colors = [UIColor(rgb: 0x87d93a), UIColor(rgb: 0x31b73b)]
                case .purple:
                    colors = [UIColor(rgb: 0xc36eff), UIColor(rgb: 0x8c61fa)]
                case .red:
                    colors = [UIColor(rgb: 0xc36eff), UIColor(rgb: 0x8c61fa)]
                case .violet:
                    colors = [UIColor(rgb: 0xc36eff), UIColor(rgb: 0x8c61fa)]
                }
                
                iconScale = 1.0
                
                self.iconView.image = generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: iconName), color: .white), iconScale: iconScale, cornerRadius: 20.0, color: .blue, customColors: colors.reversed())
            }
            
            if component.audienceLayout {
                if component.isCreateList {
                    self.iconView.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .regular))?.withTintColor(component.theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
                    self.iconView.contentMode = .center
                } else if let image = component.customImage {
                    self.iconView.image = image; self.iconView.contentMode = .scaleAspectFit
                }
            }
            self.component = component
            self.state = state
            
            let contextInset: CGFloat = 0.0
            
            let height: CGFloat = component.audienceLayout ? (component.isCreateList ? 62.0 : 68.0) : 64.0
            let verticalInset: CGFloat = 0.0
            var leftInset: CGFloat = component.audienceLayout ? 68.0 : 62.0
            let rightInset: CGFloat = contextInset * 2.0 + 8.0
            var avatarLeftInset: CGFloat = component.audienceLayout ? 16.0 : 10.0
            
            if case let .editing(isSelected, isTinted) = component.selectionState {
                if !component.audienceLayout { leftInset += 44.0; avatarLeftInset += 44.0 }
                let checkSize: CGFloat = 22.0
                
                let checkLayer: CheckLayer
                if let current = self.checkLayer {
                    checkLayer = current
                    if themeUpdated {
                        var theme = CheckNodeTheme(theme: component.theme, style: .plain)
                        if isTinted {
                            theme.backgroundColor = theme.backgroundColor.mixedWith(component.theme.list.itemBlocksBackgroundColor, alpha: 0.5)
                        }
                        checkLayer.theme = theme
                    }
                    checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
                } else {
                    var theme = CheckNodeTheme(theme: component.theme, style: .plain)
                    if isTinted {
                        theme.backgroundColor = theme.backgroundColor.mixedWith(component.theme.list.itemBlocksBackgroundColor, alpha: 0.5)
                    }
                    checkLayer = CheckLayer(theme: theme)
                    self.checkLayer = checkLayer
                    self.containerButton.layer.addSublayer(checkLayer)
                    checkLayer.frame = CGRect(origin: CGPoint(x: -checkSize, y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
                    checkLayer.setSelected(isSelected, animated: false)
                    checkLayer.setNeedsDisplay()
                }
                if component.audienceLayout {
                    checkLayer.theme = CheckNodeTheme(backgroundColor: .clear, strokeColor: component.theme.list.itemAccentColor, borderColor: .clear, overlayBorder: false, hasInset: false, hasShadow: false, checkmarkLineWidth: 2.0)
                }
                transition.setFrame(layer: checkLayer, frame: CGRect(origin: CGPoint(x: component.audienceLayout ? availableSize.width - 34.0 : floor((54.0 - checkSize) * 0.5), y: floor((height - verticalInset * 2.0 - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize)))
            } else {
                if let checkLayer = self.checkLayer {
                    self.checkLayer = nil
                    transition.setPosition(layer: checkLayer, position: CGPoint(x: -checkLayer.bounds.width * 0.5, y: checkLayer.position.y), completion: { [weak checkLayer] _ in
                        checkLayer?.removeFromSuperlayer()
                    })
                }
            }
            
            if component.audienceLayout {
                self.checkLayer?.isHidden = component.isCreateList
                self.checkLayer?.opacity = { if case .editing(true, _) = component.selectionState { return 1 }; return 0 }()
            }
            let avatarSize: CGFloat = 40.0
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarLeftInset, y: floor((height - verticalInset * 2.0 - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
            
            if themeUpdated {
            }
            
            transition.setFrame(view: self.iconView, frame: avatarFrame)
            
            let labelData: (String, Bool, Bool)
            if let subtitle = component.subtitle {
                labelData = (subtitle, true, true)
            } else {
                labelData = ("", false, false)
            }
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: labelData.0, font: Font.regular(15.0), textColor: labelData.1 && !component.audienceLayout ? component.theme.list.itemAccentColor : component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset - 14.0, height: 100.0)
            )
            
            let labelArrowSize = self.labelArrow.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(name: "Contact List/SubtitleArrow", tintColor: component.theme.list.itemAccentColor)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let previousTitleFrame = self.title.view?.frame
            var previousTitleContents: UIView?
            if hasSelectionUpdated && !"".isEmpty {
                previousTitleContents = self.title.view?.snapshotView(afterScreenUpdates: false)
            }
            
            if component.audienceLayout {
                self.checkLayer?.isHidden = true
                let selected: Bool
                if case .editing(true, _) = component.selectionState { selected = true } else { selected = false }
                self.audienceCheck.isHidden = !selected
                self.audienceCheck.image = Self.audienceCheckImage
                self.audienceCheck.frame = CGRect(x: availableSize.width - 46, y: 20, width: 30, height: 30)
                if !component.isCreateList, component.customImage == nil, iconUpdated || themeUpdated, component.iconName != nil {
                    let colors: (UInt32, UInt32)
                    switch component.color {
                    case .blue: colors = (0x45a7ff,0x1184ff)
                    case .green: colors = (0x57eb73,0x1ccb46)
                    default: colors = (0xcd7efe,0xae51dd)
                    }
                    let builtinName = component.color == .blue ? "Everyone" : component.color == .green ? "Close Friends" : "My Contacts"
                    let glyph: UIImage? = StoryAudienceGlyphs.image(builtinName, size: 28)
                    let art = UIGraphicsImageRenderer(size: CGSize(width:40,height:40)).image { _ in if let glyph { glyph.draw(at: CGPoint(x: (40 - glyph.size.width) / 2, y: (40 - glyph.size.height) / 2)) } }
                    self.iconView.image = StoryAudienceAppearance.image(size: CGSize(width:40,height:40), top: colors.0, bottom: colors.1, glyph: art)
                }
            }
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: component.audienceLayout ? Font.regular(17.0) : Font.semibold(17.0), textColor: component.isCreateList ? component.theme.list.itemAccentColor : component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let titleSpacing: CGFloat = 3.0
            var centralContentHeight: CGFloat = titleSize.height
            if !labelData.0.isEmpty {
                centralContentHeight += titleSpacing + labelSize.height
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - verticalInset * 2.0 - centralContentHeight) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
                if let previousTitleFrame, previousTitleFrame.origin.x != titleFrame.origin.x {
                    transition.animatePosition(view: titleView, from: CGPoint(x: previousTitleFrame.origin.x - titleFrame.origin.x, y: 0.0), to: CGPoint(), additive: true)
                }
                
                if let previousTitleFrame, let previousTitleContents, previousTitleFrame.size != titleSize {
                    previousTitleContents.frame = CGRect(origin: previousTitleFrame.origin, size: previousTitleFrame.size)
                    self.addSubview(previousTitleContents)
                    
                    transition.setFrame(view: previousTitleContents, frame: CGRect(origin: titleFrame.origin, size: previousTitleFrame.size))
                    transition.setAlpha(view: previousTitleContents, alpha: 0.0, completion: { [weak previousTitleContents] _ in
                        previousTitleContents?.removeFromSuperview()
                    })
                    transition.animateAlpha(view: titleView, from: 0.0, to: 1.0)
                }
            }
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY + titleSpacing), size: labelSize))
            }
            if let labelArrowView = self.labelArrow.view, !labelData.0.isEmpty {
                if labelArrowView.superview == nil {
                    labelArrowView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(labelArrowView)
                }
                transition.setFrame(view: labelArrowView, frame: CGRect(origin: CGPoint(x: titleFrame.minX + labelSize.width + 5.0, y: titleFrame.maxY + titleSpacing + floorToScreenPixels(labelSize.height / 2.0 - labelArrowSize.height / 2.0) + 1.0 ), size: labelArrowSize))
            }
            
            self.labelArrow.view?.isHidden = component.audienceLayout
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset - (component.audienceLayout ? 16 : 0), height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
            let containerFrame = CGRect(origin: CGPoint(x: contextInset, y: verticalInset), size: CGSize(width: availableSize.width - contextInset * 2.0, height: height - verticalInset * 2.0))
            transition.setFrame(view: self.containerButton, frame: containerFrame)
            
            self.selectionButton.isHidden = !component.audienceLayout || component.isCreateList
            self.selectionButton.frame = CGRect(x: availableSize.width - 52, y: 0, width: 52, height: height)
            self.selectionButton.accessibilityLabel = "Select " + component.title
            // VoiceOver: one button per audience, its name and the line under it ("exclude people", "John Telegram"),
            // `.selected` for the chosen one. Activation is the tap: choose it, or open its list once chosen.
            var isSelected = false
            if case .editing(true, _) = component.selectionState {
                isSelected = true
            }
            self.containerButton.isAccessibilityElement = true
            self.containerButton.accessibilityLabel = component.title
            self.containerButton.accessibilityValue = component.subtitle
            self.containerButton.accessibilityTraits = isSelected ? [.button, .selected] : .button
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
