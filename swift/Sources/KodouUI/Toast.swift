import SwiftUI

/// トーストを出す係。取り消せる操作は確認を出さずにすぐ実行し、取り消しを付けてここで知らせる
@MainActor
public final class KodouToasts: ObservableObject {
    public struct Item: Identifiable {
        public let id = UUID()
        let message: String
        let undo: (() -> Void)?
        let duration: Double
        var remaining: Double      // 残りの秒（止めた時点）
        var resumedAt: Date?       // 動いている間だけ値がある
        var paused: Bool { resumedAt == nil }
    }
    @Published public private(set) var items: [Item] = []
    private var timers: [UUID: Timer] = [:]
    private var hovering = Set<UUID>(), focusedIds = Set<UUID>()
    public init() {}

    /// ポインタが乗っている間とフォーカスがある間は止め、両方離れたら残りから続ける（WCAG 2.2.1）
    func setHover(_ id: UUID, _ on: Bool) { if on { hovering.insert(id) } else { hovering.remove(id) }; sync(id) }
    func setFocus(_ id: UUID, _ on: Bool) { if on { focusedIds.insert(id) } else { focusedIds.remove(id) }; sync(id) }
    private func sync(_ id: UUID) { hovering.contains(id) || focusedIds.contains(id) ? pause(id) : resume(id) }

    /// 知らせる。duration 秒で消える（ポインタやフォーカスが乗っている間は止まる）
    public func show(_ message: String, duration: Double = 5, undo: (() -> Void)? = nil) {
        let it = Item(message: message, undo: undo, duration: duration, remaining: duration, resumedAt: Date())
        items.append(it); schedule(it)
        AccessibilityNotification.Announcement(message + (undo == nil ? "" : "。u で取り消せます")).post()
    }
    func pause(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }), let t0 = items[i].resumedAt else { return }
        items[i].remaining = max(0, items[i].remaining - Date().timeIntervalSince(t0)); items[i].resumedAt = nil
        timers[id]?.invalidate(); timers[id] = nil
    }
    func resume(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }), items[i].paused else { return }
        items[i].resumedAt = Date(); schedule(items[i])
    }
    public func dismiss(_ id: UUID) { timers[id]?.invalidate(); timers[id] = nil; hovering.remove(id); focusedIds.remove(id); items.removeAll { $0.id == id } }
    func undo(_ id: UUID) { items.first { $0.id == id }?.undo?(); dismiss(id) }
    private func schedule(_ it: Item) {
        let id = it.id
        let t = Timer(timeInterval: it.remaining, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.dismiss(id) } }
        RunLoop.main.add(t, forMode: .common); timers[it.id] = t
    }
}

/// 画面の右下にトーストを重ねる。消えるまでの残りは下の線で見せる
public struct KodouToastHost: View {
    @ObservedObject var toasts: KodouToasts
    let bottomInset: CGFloat
    /// bottomInset: ステータスラインなど、下に重ねたくない帯の高さ
    public init(_ toasts: KodouToasts, bottomInset: CGFloat = 0) { self.toasts = toasts; self.bottomInset = bottomInset }
    public var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(toasts.items) { it in KodouToastView(item: it, toasts: toasts) }
        }
        .padding(16).padding(.bottom, bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

struct KodouToastView: View {
    let item: KodouToasts.Item
    let toasts: KodouToasts
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(item.message).font(.kdRead(14)).foregroundStyle(KD.fg).frame(maxWidth: .infinity, alignment: .leading)
                if item.undo != nil {
                    Button { toasts.undo(item.id) } label: {
                        Text("[取り消す u]").font(.kdMono(12)).foregroundStyle(KD.accent).frame(minHeight: 24)
                    }
                    .buttonStyle(.plain).keyboardShortcut("u", modifiers: []).focused($focused)
                    .accessibilityLabel("取り消す")
                }
                Button { toasts.dismiss(item.id) } label: { Text("×").font(.kdMono(13)).foregroundStyle(KD.dim).frame(width: 24, height: 24) }
                    .buttonStyle(.plain).accessibilityLabel("閉じる")
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            // 残り。止まっている間は今の長さのまま、動いている間は残りの秒で 0 へ縮める
            TimelineView(.animation(minimumInterval: 0.1, paused: item.paused || reduceMotion)) { ctx in
                let left = item.resumedAt.map { item.remaining - ctx.date.timeIntervalSince($0) } ?? item.remaining
                GeometryReader { g in
                    Rectangle().fill(KD.fg).frame(width: g.size.width * CGFloat(max(0, left / item.duration)))
                }.frame(height: 2)
            }
        }
        .frame(width: 360)
        .background(KD.panel)
        .overlay(Rectangle().strokeBorder(KD.fg, lineWidth: 1))
        .background(Rectangle().fill(KD.ruleSoft).offset(x: 4, y: 4))
        .onHover { toasts.setHover(item.id, $0) }
        .onChange(of: focused) { _, f in toasts.setFocus(item.id, f) }
        .accessibilityElement(children: .contain)
    }
}
