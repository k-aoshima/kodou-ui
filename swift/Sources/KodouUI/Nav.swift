import SwiftUI

/// タブ。選んだタブは反転で示し、件数を添える。←→ で移れる（使えないタブは飛ばす）
public struct KodouTabs: View {
    public struct Tab { let title: String; let count: Int?; let disabled: Bool
        public init(_ title: String, count: Int? = nil, disabled: Bool = false) { self.title = title; self.count = count; self.disabled = disabled } }
    let tabs: [Tab]
    @Binding var selection: Int
    @FocusState private var focused: Bool
    public init(_ tabs: [Tab], selection: Binding<Int>) { self.tabs = tabs; _selection = selection }
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                let t = tabs[i], on = i == selection
                HStack(spacing: 6) {
                    Text(t.title).strikethrough(t.disabled)
                    if let n = t.count { Text("\(n)").font(.kdMono(12)).opacity(0.75) }
                }
                .font(.kdMono(13.5, weight: on ? .bold : .regular))
                .foregroundStyle(t.disabled ? KD.faint : on ? KD.selFg : KD.dim)
                .padding(.horizontal, 12).frame(height: 24)
                .background(on ? KD.selBg : .clear)
                .contentShape(Rectangle())
                .kodouFocusRing(focused && on)
                .onTapGesture { if !t.disabled { selection = i } }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                .accessibilityValue(t.disabled ? "使えません" : "")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(KD.rule).frame(height: 1) }
        .focusable().focused($focused).focusEffectDisabled()
        .onKeyPress(.rightArrow) { move(1); return .handled }
        .onKeyPress(.leftArrow) { move(-1); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("タブ")
    }
    private func move(_ d: Int) {
        var i = selection
        for _ in 0..<tabs.count { i = (i + d + tabs.count) % tabs.count; if !tabs[i].disabled { selection = i; return } }
    }
}

/// パンくず。パスと同じ形で、今いる場所までの道を見せる。どこからでも戻れる
public struct KodouCrumbs: View {
    let path: [String]
    let onPick: (Int) -> Void
    public init(_ path: [String], onPick: @escaping (Int) -> Void = { _ in }) { self.path = path; self.onPick = onPick }
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(path.indices, id: \.self) { i in
                if i > 0 { Text("/").foregroundStyle(KD.deco).padding(.horizontal, 7) }
                if i == path.count - 1 {
                    Text(path[i]).fontWeight(.bold).padding(.horizontal, 2).accessibilityAddTraits(.isStaticText).accessibilityValue("今の場所")
                } else {
                    Button { onPick(i) } label: { Text(path[i]).padding(.horizontal, 2) }
                        .buttonStyle(KodouLinkStyle())
                }
            }
        }
        .font(.kdMono(13))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("場所")
    }
}

/// 文中のリンクの見た目（青、ホバーで下線と薄い面）
struct KodouLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { LinkBody(label: configuration.label) }
    struct LinkBody<L: View>: View {
        let label: L
        @StateObject private var hover = KState(false)
        @Environment(\.isFocused) private var focused
        var body: some View {
            label.foregroundStyle(KD.blue).underline(hover.v).background(hover.v ? KD.blueBg : .clear)
                .kodouFocusRing(focused).kodouHitTarget().onHover { hover.v = $0 }
        }
    }
}

/// ページ送り。今のページと全体の件数を一緒に出す。←→ で前後へ
public struct KodouPager: View {
    @Binding var page: Int
    let pages: Int
    let perPage: Int
    let total: Int
    @FocusState private var focused: Bool
    public init(page: Binding<Int>, pages: Int, perPage: Int, total: Int) { _page = page; self.pages = pages; self.perPage = perPage; self.total = total }
    private var shown: [Int?] {
        var s = Set([1, pages, page - 1, page, page + 1].filter { $0 >= 1 && $0 <= pages })
        if page <= 3 { s.formUnion(1...min(pages, 4)) }
        var out: [Int?] = [], last = 0
        for p in s.sorted() { if p > last + 1 { out.append(nil) }; out.append(p); last = p }
        return out
    }
    public var body: some View {
        HStack(spacing: 2) {
            pageButton("‹ 前", enabled: page > 1) { page -= 1 }
            ForEach(Array(shown.enumerated()), id: \.offset) { _, p in
                if let p {
                    let on = p == page
                    Button { page = p } label: {
                        Text("\(p)").fontWeight(on ? .bold : .regular).foregroundStyle(on ? KD.selFg : KD.fg)
                            .padding(.horizontal, 6).frame(minWidth: 24, minHeight: 24).background(on ? KD.selBg : .clear)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(p) ページ")
                    .accessibilityAddTraits(on ? .isSelected : [])
                } else {
                    Text("…").foregroundStyle(KD.faint).padding(.horizontal, 4)
                }
            }
            pageButton("次 ›", enabled: page < pages) { page += 1 }
            Spacer(minLength: 16)
            Text("\((page - 1) * perPage + 1)-\(min(total, page * perPage)) / \(total)件").font(.kdMono(12.5)).foregroundStyle(KD.dim)
        }
        .font(.kdMono(13))
        .focusable().focused($focused).focusEffectDisabled()
        .onKeyPress(.leftArrow) { if page > 1 { page -= 1 }; return .handled }
        .onKeyPress(.rightArrow) { if page < pages { page += 1 }; return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ページ送り、\(pages) ページ中 \(page) ページ")
    }
    private func pageButton(_ t: String, enabled: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Text(t).foregroundStyle(enabled ? KD.fg : KD.faint).padding(.horizontal, 6).frame(minHeight: 24) }
            .buttonStyle(.plain).disabled(!enabled)
    }
}
