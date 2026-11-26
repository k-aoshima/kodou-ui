import AppKit
import SwiftUI

/// 部品の中の状態。@State は Command Line Tools だけの環境ではマクロが無くて使えないため、@StateObject で持つ
final class KState<T>: ObservableObject {
    @Published var v: T
    init(_ v: T) { self.v = v }
}

/// 部品が載っている窓が見えているか。動き続ける部品（スピナーなど）は、見えていないあいだ止める
@MainActor
final class KodouWindowWatch: ObservableObject {
    @Published private(set) var visible = true
    private weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []

    func attach(_ w: NSWindow?) {
        guard w !== window else { return }
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        window = w
        guard let w else { return }
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: w, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sync() }
            })
        }
        sync()
    }
    private func sync() {
        guard let w = window else { return }
        let v = w.occlusionState.contains(.visible) && !w.isMiniaturized
        if v != visible { visible = v }
    }
}

/// 載っている窓を知らせる（見えない、大きさ 0 の部品）
struct KodouWindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void
    func makeNSView(context: Context) -> ReaderView { let v = ReaderView(); v.onWindow = onWindow; return v }
    func updateNSView(_ nsView: ReaderView, context: Context) {}
    final class ReaderView: NSView {
        var onWindow: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let w = window
            DispatchQueue.main.async { [weak self] in self?.onWindow?(w) }
        }
    }
}

extension View {
    /// フォーカスの枠。アクセント色の 2pt の実線を、2pt 離して囲む（点線にしない）
    func kodouFocusRing(_ on: Bool) -> some View {
        overlay { if on { Rectangle().stroke(KD.accent, lineWidth: 2).padding(-3) } }
    }
    /// 押せる範囲を高さ 24pt 以上にする（見た目は変えない）
    func kodouHitTarget(minHeight: CGFloat = 24) -> some View {
        frame(minHeight: minHeight).contentShape(Rectangle())
    }
    /// 重ねるもの（候補・メニュー）の見た目。前景色の枠と、右下にずらした影
    func kodouPopStyle() -> some View {
        padding(.vertical, 4)
            .background(KD.panel)
            .overlay(Rectangle().strokeBorder(KD.fg, lineWidth: 1))
            .background(Rectangle().fill(KD.ruleSoft).offset(x: 4, y: 4))
    }
}

/// VoiceOver に一言読み上げる
@MainActor
func kodouAnnounce(_ text: String) {
    AccessibilityNotification.Announcement(text).post()
}

/// 押している間だけ Esc を拾う（ツールチップなど、フォーカスを持たない部品が使う）
@MainActor
final class KodouEscWatch {
    private var monitor: Any?
    func start(_ onEsc: @escaping () -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 53 { onEsc(); return nil }
            return e
        }
    }
    func stop() { if let m = monitor { NSEvent.removeMonitor(m) }; monitor = nil }
}
