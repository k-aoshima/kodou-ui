import SwiftUI

/// チェック。印は [x] [ ] [-]（等幅、青の太字）。右に、入れたときに何が起きるかを書ける。
/// 自動で何かをする設定は既定を「切」にする
public struct KodouCheckStyle: ToggleStyle {
    let mixed: Bool
    let note: String?
    public init(mixed: Bool = false, note: String? = nil) { self.mixed = mixed; self.note = note }
    public func makeBody(configuration: Configuration) -> some View {
        KodouCheckBody(c: configuration, mark: mixed ? "[-]" : configuration.isOn ? "[x]" : "[ ]", note: note, sw: false)
    }
}

/// スイッチ。ON は緑の面、OFF は枠だけ。文字で ON / OFF も出す（色だけで伝えない）
public struct KodouSwitchStyle: ToggleStyle {
    let note: String?
    public init(note: String? = nil) { self.note = note }
    public func makeBody(configuration: Configuration) -> some View {
        KodouCheckBody(c: configuration, mark: configuration.isOn ? "ON" : "OFF", note: note, sw: true)
    }
}

struct KodouCheckBody: View {
    let c: ToggleStyleConfiguration
    let mark: String
    let note: String?
    let sw: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    var body: some View {
        Button { c.isOn.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                markView.kodouFocusRing(focused)
                c.label.font(.kdRead(13.5)).foregroundStyle(enabled ? KD.fg : KD.faint)
                if let note {
                    Spacer(minLength: 16)
                    Text(note).font(.kdMono(12.5)).foregroundStyle(KD.faint)
                }
            }
            .kodouHitTarget()
        }
        .buttonStyle(.plain)
        .accessibilityValue(sw ? (c.isOn ? "オン" : "オフ") : mark == "[-]" ? "一部" : c.isOn ? "チェックあり" : "チェックなし")
        .accessibilityAddTraits(.isToggle)
    }
    @ViewBuilder private var markView: some View {
        if sw {
            Text(mark).font(.kdMono(12)).frame(width: 6 * 7.5, height: 18)
                .foregroundStyle(!enabled ? KD.faint : c.isOn ? KD.on : KD.dim)
                .background(c.isOn && enabled ? KD.green : .clear)
                .overlay(Rectangle().strokeBorder(c.isOn && enabled ? KD.green : KD.ui, lineWidth: 1))
        } else {
            Text(mark).font(.kdMono(13.5, weight: .bold)).foregroundStyle(enabled ? KD.blue : KD.faint)
        }
    }
}

/// ラジオ。印は (•) ( )。↑↓ で選びなおせる
public struct KodouRadioGroup<T: Hashable>: View {
    public struct Option { let value: T; let label: String; let note: String?
        public init(_ value: T, _ label: String, note: String? = nil) { self.value = value; self.label = label; self.note = note } }
    let label: String
    let options: [Option]
    @Binding var selection: T
    @FocusState private var focused: Bool
    public init(_ label: String, selection: Binding<T>, options: [Option]) { self.label = label; _selection = selection; self.options = options }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                let o = options[i], on = o.value == selection
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(on ? "(•)" : "( )").font(.kdMono(13.5, weight: .bold)).foregroundStyle(KD.blue)
                        .kodouFocusRing(focused && on)
                    Text(o.label).font(.kdRead(13.5)).foregroundStyle(KD.fg)
                    if let n = o.note { Spacer(minLength: 16); Text(n).font(.kdRead(12.5)).foregroundStyle(KD.faint) }
                }
                .kodouHitTarget()
                .onTapGesture { selection = o.value }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { selection = o.value }
            }
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
    private func move(_ d: Int) {
        guard let i = options.firstIndex(where: { $0.value == selection }) else { return }
        selection = options[(i + d + options.count) % options.count].value
    }
}
