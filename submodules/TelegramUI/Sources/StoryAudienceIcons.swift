// Shared SVG geometry across audience rows, hero, cloud and published badges.
import UIKit
import ShareWithPeersScreen
enum StoryAudienceIcons {
    static func image(_ name: String, size: CGFloat, color: UIColor = .white) -> UIImage {
        StoryAudienceGlyphs.image(name, size: size, color: color)
    }
}
