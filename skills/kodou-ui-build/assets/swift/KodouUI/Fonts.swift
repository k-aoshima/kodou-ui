import AppKit
import SwiftUI

/// 書体。桁をそろえる所は等幅（JetBrains Mono → SF Mono → Menlo）、文として読む所は OS の和文ゴシック。
/// 和文は等幅の書体に無いので、OS の代わりの書体（ヒラギノ角ゴ）で出る
public enum KodouFont {
    /// 等幅。size は Web の px と同じ数（13 が本文）
    public static func mono(_ size: CGFloat = 13, weight: NSFont.Weight = .regular) -> NSFont {
        if let f = NSFont(name: weight == .regular ? "JetBrainsMono-Regular" : "JetBrainsMono-SemiBold", size: size) { return f }
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)   // SF Mono
    }
    /// 文として読む所。システムの書体（和文はヒラギノ角ゴ）
    public static func read(_ size: CGFloat = 14, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }
}

public extension Font {
    static func kdMono(_ size: CGFloat = 13, weight: NSFont.Weight = .regular) -> Font { Font(KodouFont.mono(size, weight: weight)) }
    static func kdRead(_ size: CGFloat = 14, weight: NSFont.Weight = .regular) -> Font { Font(KodouFont.read(size, weight: weight)) }
}
