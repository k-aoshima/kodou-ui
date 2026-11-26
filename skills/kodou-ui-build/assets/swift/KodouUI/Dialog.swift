import SwiftUI

/// 取り消せない操作の確認。画面を止めるので最後の手段にし、ふつうの確認はその場の 1 行（y/N）で済ませる。
/// - 二重罫線の枠。何が消えて戻せないのかを具体的に書く
/// - 既定は安全な側（やめる）。⏎ と Esc と n はやめる、y で実行する。Tab でボタンを移れる
/// - 前景色の 1pt の線を 1pt あけて 2 本引き（Web の border: 3px double）、右下に影を付ける
public struct KodouConfirm: View {
    let title: String
    let message: String
    let confirm: String
    let cancel: String
    let danger: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(title: String, message: String, confirm: String, cancel: String = "やめる", danger: Bool = true,
                onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.title = title; self.message = message; self.confirm = confirm; self.cancel = cancel; self.danger = danger
        self.onConfirm = onConfirm; self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if danger { KodouIcon("alert", small: true, tone: true, toneColor: KD.red).foregroundStyle(KD.red) }
                Text(title).font(.kdRead(13.5, weight: .bold)).foregroundStyle(KD.fg).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button(action: onCancel) { Text("×").font(.kdMono(13)).foregroundStyle(KD.dim).frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("閉じる")
            }
            .padding(.horizontal, 12).padding(.vertical, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(KD.rule).frame(height: 1) }
            Text(message).font(.kdRead(14)).lineSpacing(6).foregroundStyle(KD.fg).fixedSize(horizontal: false, vertical: true)
                .padding(12)
            HStack(spacing: 8) {
                Spacer()
                KodouButton(cancel, key: "Esc") { onCancel() }
                    .keyboardShortcut(.defaultAction)
                KodouButton(confirm, kind: danger ? .danger : .primary) { onConfirm() }
                    .keyboardShortcut("y", modifiers: [])
                    .accessibilityHint("y のキーでも押せます")
                // n でもやめる（⏎ は上の既定の操作に付けた）
                Button("", action: onCancel).keyboardShortcut("n", modifiers: []).frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .overlay(alignment: .top) { Rectangle().fill(KD.ruleSoft).frame(height: 1) }
        }
        .frame(width: 452)
        .overlay(Rectangle().strokeBorder(KD.fg, lineWidth: 1))   // 二重罫線の内側（Web の 3px double と同じ 1・1・1）
        .padding(2)
        .background(KD.panel)
        .overlay(Rectangle().strokeBorder(KD.fg, lineWidth: 1))   // 外側
        .background(Rectangle().fill(KD.ruleSoft).offset(x: 6, y: 6))
        .onExitCommand(perform: onCancel)   // Esc
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

public extension View {
    /// 確認をシートで出す。閉じたら isPresented が false になる
    func kodouConfirm(isPresented: Binding<Bool>, title: String, message: String, confirm: String, danger: Bool = true, onConfirm: @escaping () -> Void) -> some View {
        sheet(isPresented: isPresented) {
            KodouConfirm(title: title, message: message, confirm: confirm, danger: danger,
                         onConfirm: { isPresented.wrappedValue = false; onConfirm() },
                         onCancel: { isPresented.wrappedValue = false })
        }
    }
}
