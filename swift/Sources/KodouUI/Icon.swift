import SwiftUI

/// ドット絵のアイコン。マス目は IconData.swift（icons.js から書き出したもの）。
/// 標準は 12×12 を 1 マス 1.5pt、small は 8×8 を 1 マス 2pt。tone は内側をアクセント色で薄く塗る。
/// アイコンだけにせず、文字ラベルを添える（幅が足りない所だけ、accessibilityLabel を付けて単独で使う）
public struct KodouIcon: View {
    let name: String
    let cell: CGFloat?
    let small: Bool
    let tone: Bool
    var toneColor: Color = KD.accent
    public init(_ name: String, cell: CGFloat? = nil, small: Bool = false, tone: Bool = false, toneColor: Color = KD.accent) {
        self.name = name; self.cell = cell; self.small = small; self.tone = tone; self.toneColor = toneColor
    }
    private var rows: [String] {
        if !small, let r = kodouIcon12[name] { return r }
        return kodouIcon8[name] ?? kodouIcon12[name] ?? []
    }
    private var big: Bool { !small && kodouIcon12[name] != nil }
    public var body: some View {
        let rows = rows, c = cell ?? (big ? 1.5 : 2)
        let w = rows.first?.count ?? 0, h = rows.count
        Canvas { ctx, _ in
            let grid = rows.map { Array($0) }
            if tone {
                let inside = Self.inside(grid)
                var p = Path()
                for y in 0..<h { for x in 0..<w where inside[y][x] { p.addRect(CGRect(x: CGFloat(x) * c, y: CGFloat(y) * c, width: c, height: c)) } }
                ctx.fill(p, with: .color(toneColor.opacity(0.3)))
            }
            var p = Path()
            for y in 0..<h { for x in 0..<w where grid[y][x] == "#" { p.addRect(CGRect(x: CGFloat(x) * c, y: CGFloat(y) * c, width: c, height: c)) } }
            ctx.fill(p, with: .foreground)
        }
        .frame(width: CGFloat(w) * c, height: CGFloat(h) * c)
        .accessibilityHidden(true)
    }

    /// 外から塗りつぶして届かなかった「.」のマスが内側
    static func inside(_ g: [[Character]]) -> [[Bool]] {
        let h = g.count, w = g.first?.count ?? 0
        var out = Array(repeating: Array(repeating: false, count: w), count: h)
        var st: [(Int, Int)] = []
        for x in 0..<w { st.append((x, 0)); st.append((x, h - 1)) }
        for y in 0..<h { st.append((0, y)); st.append((w - 1, y)) }
        while let (x, y) = st.popLast() {
            if x < 0 || y < 0 || x >= w || y >= h || out[y][x] || g[y][x] == "#" { continue }
            out[y][x] = true
            st += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        }
        return (0..<h).map { y in (0..<w).map { x in g[y][x] != "#" && !out[y][x] } }
    }
}
