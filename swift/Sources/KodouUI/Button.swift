import SwiftUI

public enum KodouButtonKind: Sendable { case normal, primary, danger, ghost, link }
public enum KodouButtonSize: Sendable { case sm, md, lg }

/// ボタンの見た目。押すと起きることをそのまま名前にする。
/// - 枠のあるボタンに角かっこを付けない。角かっこは文中の小さな操作（.link）だけ
/// - ホバーはボタン自身の色を濃くする（黒で反転しない）。色の切り替えに動きは付けない
/// - 無効は文字を faint、枠を破線。押せる範囲は高さ 24pt 以上
public struct KodouButtonStyle: ButtonStyle {
    let kind: KodouButtonKind
    let size: KodouButtonSize
    public init(_ kind: KodouButtonKind = .normal, size: KodouButtonSize = .md) { self.kind = kind; self.size = size }
    public func makeBody(configuration: Configuration) -> some View {
        KodouButtonBody(label: configuration.label, pressed: configuration.isPressed, kind: kind, size: size)
    }
}

struct KodouButtonBody<L: View>: View {
    let label: L
    let pressed: Bool
    let kind: KodouButtonKind
    let size: KodouButtonSize
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @StateObject private var hover = KState(false)

    private var fontSize: CGFloat { size == .sm ? 12 : size == .lg ? 14.5 : 13 }
    private var pad: EdgeInsets {
        switch size {
        case .sm: return .init(top: 0, leading: 7, bottom: 0, trailing: 7)
        case .md: return .init(top: 2, leading: 10, bottom: 2, trailing: 10)
        case .lg: return .init(top: 5, leading: 14, bottom: 5, trailing: 14)
        }
    }
    private var fg: Color {
        if !enabled { return KD.faint }
        switch kind {
        case .primary: return KD.panel
        case .danger: return hover.v ? KD.on : KD.red
        case .link: return KD.blue
        default: return KD.fg
        }
    }
    private var bg: Color {
        if !enabled { return .clear }
        switch kind {
        case .primary: return hover.v ? KD.blueHover : KD.blue
        case .danger: return hover.v ? KD.red : KD.panel
        case .ghost: return hover.v ? KD.ruleSoft : .clear
        case .link: return hover.v ? KD.blueBg : .clear
        case .normal: return hover.v ? KD.ruleSoft : KD.panel
        }
    }
    private var border: Color {
        if !enabled { return KD.ui }
        switch kind {
        case .primary: return hover.v ? KD.blueHover : KD.blue
        case .danger: return KD.red
        case .ghost, .link: return .clear
        case .normal: return hover.v ? KD.fg : KD.ui
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if kind == .link { Text("[").foregroundStyle(KD.deco) }
            label.underline(kind == .link && hover.v)
            if kind == .link { Text("]").foregroundStyle(KD.deco) }
        }
        .font(.kdMono(fontSize, weight: kind == .primary && enabled ? .bold : .regular))
        .lineLimit(1)
        .foregroundStyle(fg)
        .padding(kind == .link ? .init(top: 0, leading: 1, bottom: 0, trailing: 1) : pad)
        .background(bg)
        .overlay {
            if enabled { Rectangle().strokeBorder(border, lineWidth: 1) }
            else if kind != .link { Rectangle().strokeBorder(KD.ui, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
        }
        .offset(y: pressed && enabled ? 1 : 0)
        .kodouFocusRing(focused)
        .kodouHitTarget()
        .onHover { hover.v = $0 }
    }
}

/// よく使う形のボタン。アイコンには文字を添え、キーがあれば右に薄く出す
public struct KodouButton: View {
    let title: String
    let icon: String?
    let key: String?
    let kind: KodouButtonKind
    let size: KodouButtonSize
    let action: () -> Void
    public init(_ title: String, icon: String? = nil, key: String? = nil, kind: KodouButtonKind = .normal, size: KodouButtonSize = .md, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.key = key; self.kind = kind; self.size = size; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { KodouIcon(icon) }
                Text(title)
                if let key { Text(key).fontWeight(.regular).opacity(0.7) }
            }
        }
        .buttonStyle(KodouButtonStyle(kind, size: size))
        .accessibilityLabel(title)
        .accessibilityHint(key.map { "\($0) でも押せます" } ?? "")
    }
}
