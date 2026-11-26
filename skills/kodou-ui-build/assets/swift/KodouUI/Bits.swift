import AppKit
import SwiftUI

/// キーと値。点線でキーと値をつなぐ。値はぼかさず、そのままコピーできる（コピーのボタンは押せる範囲 24pt）
public struct KodouKeyValue: View {
    let rows: [(String, String)]
    @StateObject private var copied = KState<Int?>(nil)
    public init(_ rows: [(String, String)]) { self.rows = rows }
    public var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 2) {
            ForEach(rows.indices, id: \.self) { i in
                let (k, v) = rows[i]
                GridRow {
                    HStack(spacing: 8) {
                        Text(k).foregroundStyle(KD.dim)
                        Rectangle().fill(.clear).frame(height: 1).frame(minWidth: 16)
                            .overlay(Rectangle().stroke(KD.rule, style: StrokeStyle(lineWidth: 1, dash: [1, 2])).frame(height: 1))
                            .padding(.trailing, 8).offset(y: 4)
                    }
                    Text(v).foregroundStyle(KD.fg).lineLimit(1).truncationMode(.tail).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(v, forType: .string)
                        copied.v = i; kodouAnnounce("\(k) をコピーしました")
                    } label: {
                        Group { if copied.v == i { Text("✓").foregroundStyle(KD.green) } else { KodouIcon("copy", small: true) } }
                            .frame(width: 24, height: 24).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(KD.dim)
                    .accessibilityLabel("\(k) をコピー")
                }
            }
        }
        .font(.kdMono(13))
    }
}

/// キーの表示。1 つのキーは塗り、同時に押すキーは枠、続けて押すキーは → でつなぐ
public struct KodouKey: View {
    public enum Style: Sendable { case single, chord, sequence }
    let keys: [String]
    let style: Style
    public init(_ keys: String..., style: Style = .single) { self.keys = keys; self.style = style }
    public var body: some View {
        HStack(spacing: style == .chord ? 2 : 4) {
            ForEach(keys.indices, id: \.self) { i in
                if style == .sequence && i > 0 { Text("→").font(.kdMono(12)).foregroundStyle(KD.faint) }
                if style == .single {
                    Text(keys[i]).font(.kdMono(12, weight: .bold)).foregroundStyle(KD.selFg).padding(.horizontal, 4).background(KD.selBg)
                } else {
                    Text(keys[i]).font(.kdMono(12, weight: .medium)).foregroundStyle(KD.fg).padding(.horizontal, 5).padding(.bottom, 1)
                        .overlay(Rectangle().strokeBorder(KD.rule, lineWidth: 1))
                        .overlay(alignment: .bottom) { Rectangle().fill(KD.rule).frame(height: 2) }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys.joined(separator: style == .chord ? "＋" : style == .sequence ? " のあと " : ""))
    }
}

/// 区切り線。実線は区切り、点線は同じまとまりの中の切れ目、二重線は大きな区切り。文字を載せることもできる
public struct KodouDivider: View {
    public enum Style: Sendable { case solid, dashed, double }
    let style: Style
    let label: String?
    public init(_ style: Style = .solid, label: String? = nil) { self.style = style; self.label = label }
    public var body: some View {
        if let label {
            HStack(spacing: 8) {
                Rectangle().fill(KD.ruleSoft).frame(width: 16, height: 1)
                Text(label).font(.kdMono(12)).foregroundStyle(KD.faint)
                Rectangle().fill(KD.ruleSoft).frame(height: 1)
            }
        } else {
            switch style {
            case .solid: Rectangle().fill(KD.rule).frame(height: 1)
            case .dashed: Line().stroke(KD.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
            case .double: VStack(spacing: 1) { Rectangle().fill(KD.rule).frame(height: 1); Rectangle().fill(KD.rule).frame(height: 1) }
            }
        }
    }
    struct Line: Shape { func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.width, y: r.midY)) } } }
}
