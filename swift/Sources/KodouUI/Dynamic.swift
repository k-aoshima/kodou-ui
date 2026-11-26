import AppKit

/// 0xRRGGBB と不透明度。Tokens.swift が使う
public struct KodouRGBA: Sendable {
    public let rgb: UInt32, alpha: CGFloat
    public init(_ rgb: UInt32, _ alpha: CGFloat = 1) { self.rgb = rgb; self.alpha = alpha }
    var ns: NSColor {
        // kodou-lint: ignore swift-fixed-color（トークンの値から色を作る所）
        NSColor(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}

public enum KodouDynamic {
    /// 外観（明・暗・高いコントラスト）に合わせて替わる色
    public static func color(_ light: KodouRGBA, _ dark: KodouRGBA, hcLight: KodouRGBA? = nil, hcDark: KodouRGBA? = nil) -> NSColor {
        let l = light.ns, d = dark.ns, hl = (hcLight ?? light).ns, hd = (hcDark ?? dark).ns
        return NSColor(name: nil) { ap in
            switch ap.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]) {
            case .darkAqua?: return d
            case .accessibilityHighContrastAqua?: return hl
            case .accessibilityHighContrastDarkAqua?: return hd
            default: return l
            }
        }
    }
}
