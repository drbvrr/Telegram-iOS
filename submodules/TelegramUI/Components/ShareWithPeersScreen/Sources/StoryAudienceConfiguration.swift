import UIKit
import Display
import TelegramCore
import AccountContext

/// Integration seam shared by the editor and viewer. Existing clients keep their
/// original privacy screen when no configuration is supplied.
public final class StoryAudienceConfiguration {
    public let headerBackground: ((CGSize, ContainedViewLayoutTransition) -> UIView)?
    public let store: StoryAudienceStore
    public let icon: (StoryAudience, CGFloat) -> UIImage?
    public var glyph: ((StoryAudience, CGFloat) -> UIImage?)?
    public let color: (StoryAudience) -> UIColor
    public let edit: (Int64?, ViewController) -> Void
    public init(store: StoryAudienceStore, icon: @escaping (StoryAudience, CGFloat) -> UIImage?, color: @escaping (StoryAudience) -> UIColor, edit: @escaping (Int64?, ViewController) -> Void, headerBackground: ((CGSize, ContainedViewLayoutTransition) -> UIView)? = nil) {
        self.store = store; self.icon = icon; self.color = color; self.edit = edit; self.headerBackground = headerBackground
    }
}

public enum StoryAudienceUIHooks {
    public static var configuration: ((AccountContext) -> StoryAudienceConfiguration?)?
}

/// Designer palette, in top-to-bottom order. Static lens coating over the gradient.
public enum StoryAudienceAppearance {
    public static let palette: [(UInt32, UInt32)] = [(0x827fff,0x605ee4),(0xf7b73d,0xf29800),(0xf96a5f,0xfd4643),(0x5fcef9,0x3ab3f3)]
    public static func image(size: CGSize, top: UInt32, bottom: UInt32, glyph: UIImage? = nil) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let c = renderer.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.35, dy: 0.35), cornerRadius: size.height / 2)
            c.saveGState(); path.addClip()
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(rgb: top).cgColor, UIColor(rgb: bottom).cgColor] as CFArray, locations: [0,1])!
            c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0,y: size.height), options: [])
            UIColor.white.withAlphaComponent(0.02).setFill(); path.fill()
            c.saveGState(); c.addPath(path.cgPath); c.setLineWidth(1.1); c.replacePathWithStrokedPath(); c.clip()
            let rim = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.white.withAlphaComponent(0.45).cgColor, UIColor.white.withAlphaComponent(0.05).cgColor, UIColor.white.withAlphaComponent(0.3).cgColor] as CFArray, locations: [0,0.5,1])!
            c.drawLinearGradient(rim, start: .zero, end: CGPoint(x: size.width,y:size.height), options: [])
            c.restoreGState(); c.restoreGState()
            glyph?.draw(in: bounds)
        }
    }
}
