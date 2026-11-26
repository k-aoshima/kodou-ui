// Kodou-ui のトークン。tools/build-assets.py が catalog/index.html の :root から書き出す（手で直さない）
// 明・暗・高いコントラスト（明と暗）の値を持つ動的な色で、外観が変わると自動で替わる
import AppKit
import SwiftUI

/// AppKit で使う色（NSColor）
public enum KodouColor {
    public static let bg = KodouDynamic.color(.init(0xF4F4EF), .init(0x15171C))
    public static let panel = KodouDynamic.color(.init(0xFBFBF8), .init(0x1A1D23))
    public static let fg = KodouDynamic.color(.init(0x20242B), .init(0xD9DCE3))
    public static let dim = KodouDynamic.color(.init(0x575B63), .init(0xA7ACB6), hcLight: .init(0x3A3E45), hcDark: .init(0xC6CAD2))
    public static let faint = KodouDynamic.color(.init(0x666A72), .init(0x9196A1), hcLight: .init(0x464A52), hcDark: .init(0xB8BDC7))
    public static let deco = KodouDynamic.color(.init(0xA7AAAF), .init(0x4B505B), hcLight: .init(0x84878D), hcDark: .init(0x707684))
    public static let ui = KodouDynamic.color(.init(0x84878D), .init(0x707684), hcLight: .init(0x5C5F65), hcDark: .init(0x8D93A0))
    public static let rule = KodouDynamic.color(.init(0x20242B, 0.3), .init(0xD9DCE3, 0.28), hcLight: .init(0x20242B, 0.55), hcDark: .init(0xD9DCE3, 0.5))
    public static let ruleSoft = KodouDynamic.color(.init(0x20242B, 0.12), .init(0xD9DCE3, 0.1), hcLight: .init(0x20242B, 0.25), hcDark: .init(0xD9DCE3, 0.22))
    public static let selBg = KodouDynamic.color(.init(0x20242B), .init(0xD9DCE3))
    public static let selFg = KodouDynamic.color(.init(0xF4F4EF), .init(0x15171C))
    public static let on = KodouDynamic.color(.init(0xFBFBF8), .init(0x1A1D23))
    public static let red = KodouDynamic.color(.init(0xBE3F0E), .init(0xFF9670))
    public static let green = KodouDynamic.color(.init(0x00654A), .init(0x2FAA80))
    public static let yellow = KodouDynamic.color(.init(0x8A5800), .init(0xEDBE4F))
    public static let blue = KodouDynamic.color(.init(0x0058A0), .init(0x72B2FF))
    public static let magenta = KodouDynamic.color(.init(0x9A3C78), .init(0xE58EC6))
    public static let cyan = KodouDynamic.color(.init(0x006A8C), .init(0x5CC6EE))
    public static let accent = KodouDynamic.color(.init(0x0058A0), .init(0x72B2FF))
    public static let blueHover = KodouDynamic.color(.init(0x00477F), .init(0x9CC8FF))
    public static let redBg = KodouDynamic.color(.init(0xBE3F0E, 0.1), .init(0xFF9670, 0.13))
    public static let greenBg = KodouDynamic.color(.init(0x00654A, 0.1), .init(0x2FAA80, 0.13))
    public static let yellowBg = KodouDynamic.color(.init(0x8A5800, 0.11), .init(0xEDBE4F, 0.12))
    public static let blueBg = KodouDynamic.color(.init(0x0058A0, 0.1), .init(0x72B2FF, 0.13))
}

/// SwiftUI で使う色（KD.fg のように書く）
public enum KD {
    public static let bg = Color(nsColor: KodouColor.bg)
    public static let panel = Color(nsColor: KodouColor.panel)
    public static let fg = Color(nsColor: KodouColor.fg)
    public static let dim = Color(nsColor: KodouColor.dim)
    public static let faint = Color(nsColor: KodouColor.faint)
    public static let deco = Color(nsColor: KodouColor.deco)
    public static let ui = Color(nsColor: KodouColor.ui)
    public static let rule = Color(nsColor: KodouColor.rule)
    public static let ruleSoft = Color(nsColor: KodouColor.ruleSoft)
    public static let selBg = Color(nsColor: KodouColor.selBg)
    public static let selFg = Color(nsColor: KodouColor.selFg)
    public static let on = Color(nsColor: KodouColor.on)
    public static let red = Color(nsColor: KodouColor.red)
    public static let green = Color(nsColor: KodouColor.green)
    public static let yellow = Color(nsColor: KodouColor.yellow)
    public static let blue = Color(nsColor: KodouColor.blue)
    public static let magenta = Color(nsColor: KodouColor.magenta)
    public static let cyan = Color(nsColor: KodouColor.cyan)
    public static let accent = Color(nsColor: KodouColor.accent)
    public static let blueHover = Color(nsColor: KodouColor.blueHover)
    public static let redBg = Color(nsColor: KodouColor.redBg)
    public static let greenBg = Color(nsColor: KodouColor.greenBg)
    public static let yellowBg = Color(nsColor: KodouColor.yellowBg)
    public static let blueBg = Color(nsColor: KodouColor.blueBg)
}

/// 間隔（pt）。Web の px と同じ数
public enum KodouSpace {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 24
    public static let s6: CGFloat = 32
}

/// 動きの長さ（秒）
public enum KodouMotion {
    public static let fast: Double = 0.08
    public static let base: Double = 0.14
}
