import AppKit

/// 行を部品なしで描く部品（一覧・ログ・表・ツリー）が共有する、文字の組み置き。
/// 文字と色ごとに組んだ CTLine を使い回し、毎回組み直さない。外観が変わったら捨てる
@MainActor
public final class KodouLineCache {
    public var font: NSFont { didSet { lines = [:]; charWidth = Self.width(font) } }
    public private(set) var charWidth: CGFloat
    private var lines: [Key: CTLine] = [:]
    private var appearance: NSAppearance.Name?
    private struct Key: Hashable { let text: String; let color: ObjectIdentifier; let bold: Bool; let mark: Range<Int>?; let markColor: ObjectIdentifier? }

    public init(font: NSFont) { self.font = font; charWidth = Self.width(font) }
    private static func width(_ f: NSFont) -> CGFloat { ("0" as NSString).size(withAttributes: [.font: f]).width }

    /// 文字を 1 行に組む。色は ap の外観で解いてから使う
    public func line(_ text: String, _ color: NSColor, bold: Bool = false, mark: Range<Int>? = nil, markColor: NSColor? = nil, appearance ap: NSAppearance) -> CTLine {
        if ap.name != appearance { lines = [:]; appearance = ap.name }
        let key = Key(text: text, color: ObjectIdentifier(color), bold: bold, mark: mark, markColor: markColor.map(ObjectIdentifier.init))
        if let l = lines[key] { return l }
        if lines.count > 4096 { lines = [:] }
        var cg = color.cgColor
        ap.performAsCurrentDrawingAppearance { cg = color.cgColor }
        let f = bold ? (NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)) : font
        let fgKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
        let attr = NSMutableAttributedString(string: text, attributes: [.font: f, fgKey: cg])
        if let m = mark, m.lowerBound >= 0, m.upperBound <= (text as NSString).length {
            let r = NSRange(location: m.lowerBound, length: m.count)
            var mc = cg
            if let markColor { ap.performAsCurrentDrawingAppearance { mc = markColor.cgColor } }
            attr.addAttributes([.font: NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask), fgKey: mc,
                                NSAttributedString.Key(kCTUnderlineStyleAttributeName as String): CTUnderlineStyle.single.rawValue], range: r)
        }
        let l = CTLineCreateWithAttributedString(attr)
        lines[key] = l
        return l
    }

    public enum Align { case left, right }

    /// rect（isFlipped の座標）の中に 1 行を描く。はみ出た分は切る
    public func draw(_ text: String, _ color: NSColor, in rect: CGRect, align: Align = .left, bold: Bool = false,
                     mark: Range<Int>? = nil, markColor: NSColor? = nil, appearance ap: NSAppearance, ctx: CGContext) {
        let l = line(text, color, bold: bold, mark: mark, markColor: markColor, appearance: ap)
        let baseline = (rect.minY + (rect.height - (font.ascender - font.descender)) / 2 + font.ascender).rounded()
        var x = rect.minX
        if align == .right { x = rect.maxX - CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil)) }
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(l, ctx)
        ctx.restoreGState()
    }
}
