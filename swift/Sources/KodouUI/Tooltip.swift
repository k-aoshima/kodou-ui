import SwiftUI

@MainActor
final class KodouTipState: ObservableObject {
    @Published var hover = false
    @Published var focus = false
    @Published var closed = false   // Esc で閉じた。ポインタが離れるかフォーカスが外れたら戻す
    let esc = KodouEscWatch()
    var shown: Bool { (hover || focus) && !closed }
    func sync() {
        if !hover && !focus { closed = false }
        if shown { esc.start { [weak self] in self?.closed = true; self?.esc.stop() } } else { esc.stop() }
    }
}

/// 見本や画面の確認のために、ツールチップを出したままにする（.environment(\.kodouShowTooltips, true)）
public struct KodouShowTooltipsKey: EnvironmentKey { public static let defaultValue = false }
public extension EnvironmentValues {
    var kodouShowTooltips: Bool { get { self[KodouShowTooltipsKey.self] } set { self[KodouShowTooltipsKey.self] = newValue } }
}

struct KodouTooltipModifier: ViewModifier {
    let text: String
    let key: String?
    @Environment(\.kodouShowTooltips) private var always
    @StateObject private var st = KodouTipState()
    @FocusState private var focused: Bool
    func body(content: Content) -> some View {
        content
            .focused($focused)
            .overlay(alignment: .top) {
                if st.shown || always {
                    HStack(spacing: 6) {
                        Text(text).font(.kdRead(12.5))
                        if let key { Text(key).font(.kdMono(12, weight: .bold)).foregroundStyle(KD.selBg).padding(.horizontal, 4).background(KD.selFg) }
                    }
                    .foregroundStyle(KD.selFg).padding(.horizontal, 8).padding(.vertical, 2).background(KD.selBg)
                    .fixedSize()
                    // 部品との 6pt の隙間も、乗っている扱いにする（ポインタを上へ動かしても消えない）
                    .padding(.bottom, 6).contentShape(Rectangle())
                    .offset(y: -28)
                    .accessibilityHidden(true)
                }
            }
            .onHover { st.hover = $0; st.sync() }
            .onChange(of: focused) { _, f in st.focus = f; st.sync() }
            .accessibilityHint(key.map { "\(text)。\($0)" } ?? text)
            .zIndex(st.shown || always ? 5 : 0)
    }
}

public extension View {
    /// ツールチップ。キーを教えるため、またはアイコンだけの所で名前を出すために使う。
    /// ポインタが乗っている間とフォーカスがある間は消えず（ツールチップの上に乗っても消えない）、Esc で閉じられる（WCAG 1.4.13）
    func kodouTooltip(_ text: String, key: String? = nil) -> some View { modifier(KodouTooltipModifier(text: text, key: key)) }
}
