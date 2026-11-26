import AppKit
import SwiftUI

/// 入力の確かめの結果
public enum KodouCheck: Equatable {
    case none
    /// 合っている・直った。打つたびにすぐ出す
    case ok(String)
    /// 誤り。形の誤りは欄を離れてから出す。now: true（名前の重なりのように打ちながら知りたいもの）はすぐ出す
    case error(String, now: Bool = false)
}

final class KodouFieldState: ObservableObject {
    @Published var shown: KodouCheck = .none
}

/// 1 行のテキスト入力。
/// - 合っていることはすぐ出し、形の誤りは欄を離れたときに、何が駄目でどう直すかを出す（打っている途中に責めない）
/// - 誤りを出している間は、直るまで打つたびに出し直す
/// - 誤りを出したら VoiceOver に読み上げ、欄の説明（hint）にも誤りを入れる
public struct KodouTextField: View {
    let label: String
    @Binding var text: String
    let prefix: String?
    let help: String
    let optional: Bool
    let check: (String) -> KodouCheck
    // @State は Command Line Tools だけの環境ではマクロが無くて使えないため、@StateObject で持つ
    @StateObject private var st = KodouFieldState()
    @FocusState private var focused: Bool

    public init(_ label: String, text: Binding<String>, prefix: String? = nil, help: String = "", optional: Bool = false,
                check: @escaping (String) -> KodouCheck = { _ in .none }) {
        self.label = label; _text = text; self.prefix = prefix; self.help = help; self.optional = optional; self.check = check
    }

    private var errorText: String? { if case .error(let m, _) = st.shown { return m } else { return nil } }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label).font(.kdRead(13, weight: .bold)).foregroundStyle(KD.fg)
                if optional { Text("任意").font(.kdMono(12)).foregroundStyle(KD.dim) }
            }
            HStack(spacing: 0) {
                if let p = prefix { Text(p).font(.kdMono(12.5)).foregroundStyle(KD.dim).padding(.horizontal, 8).frame(maxHeight: .infinity).background(KD.ruleSoft) }
                TextField("", text: $text)
                    .textFieldStyle(.plain).font(.kdMono(13.5)).foregroundStyle(KD.fg)
                    .padding(.horizontal, 8).frame(height: 28)
                    .focused($focused)
                    .accessibilityLabel(label)
                    .accessibilityHint(errorText.map { "誤り。\($0)" } ?? help)
            }
            .background(KD.panel)
            .overlay(Rectangle().strokeBorder(errorText != nil ? KD.red : focused ? KD.fg : KD.ui, lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .bottom) { if focused { Rectangle().fill(errorText != nil ? KD.red : KD.fg).frame(height: 2) } }
            message.font(.kdRead(12.5)).fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: text) { _, v in typed(v) }
        .onChange(of: focused) { _, f in if !f { left() } }
    }

    @ViewBuilder private var message: some View {
        switch st.shown {
        case .error(let m, _): Text(m).foregroundStyle(KD.red)
        case .ok(let m): Text(m).foregroundStyle(KD.green)
        case .none: if !help.isEmpty { Text(help).foregroundStyle(KD.dim) }
        }
    }

    private func typed(_ v: String) {
        let c = check(v)
        switch c {
        case .ok, .none: st.shown = c
        case .error(_, let now):
            if now || errorText != nil { show(c) }          // すぐ知りたい誤りと、出している誤りの出し直し
            else if case .ok = st.shown { st.shown = .none } // 合っていた印は下げるが、まだ責めない
        }
    }
    private func left() {
        let c = check(text)
        if case .error = c { show(c) }
    }
    private func show(_ c: KodouCheck) {
        let changed = c != st.shown
        st.shown = c
        if changed, case .error(let m, _) = c {
            AccessibilityNotification.Announcement("\(label)。\(m)").post()
        }
    }
}
