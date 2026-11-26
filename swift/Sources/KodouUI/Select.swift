import AppKit
import SwiftUI

/// セレクト・コンボボックスの候補。件数が少なくても見えている行だけを描く（NSTableView）。
/// フォーカスは呼び出し元（ボタンや入力欄）に置いたまま、選んでいる行は反転で示す
@MainActor
final class KodouOptions: ObservableObject, KodouRowsSource {
    struct Item { let text: String; let meta: String?; let mark: Range<Int>?; let disabled: Bool }
    private(set) var items: [Item] = []
    var current = -1
    let rows: KodouRowsController
    init(label: String) {
        rows = KodouRowsController(columns: [.init(.ch(2)), .init(.fill), .init(.ch(10))], rowHeight: 24, font: KodouFont.mono(13.5), label: label)
        rows.source = self
    }
    var rowCount: Int { items.count }
    var cursor: Int { rows.table.selectedRow }
    func cells(_ i: Int) -> [KodouCell] {
        let it = items[i]
        return [KodouCell(i == current ? "✓" : "", KodouColor.blue, bold: true),
                KodouCell(it.text, it.disabled ? KodouColor.faint : nil, mark: it.mark),
                KodouCell(it.meta ?? "", KodouColor.faint)]
    }
    func set(_ items: [Item], current: Int, cursor: Int) {
        self.items = items; self.current = current
        rows.reloadAll()
        if cursor >= 0, cursor < items.count { rows.select(cursor) } else { rows.table.deselectAll(nil) }
    }
    func move(_ d: Int) {
        let n = items.count; guard n > 0 else { return }
        var c = cursor < 0 ? (d > 0 ? -1 : n) : cursor
        for _ in 0..<n { c = min(n - 1, max(0, c + d)); if !items[c].disabled { break } }
        rows.select(c)
    }
    /// 候補の窓の高さ。窓は 10 行まで
    var height: CGFloat { CGFloat(min(max(items.count, 1), 10)) * 24 }
}

/// セレクト。開く（Space・↓）、選ぶ（↑↓）、決める（⏎）、閉じる（Esc）を全部キーでできる。
/// 閉じたまま頭の文字を打つと、その項目に切り替わる。候補は見えている分だけ描く
public struct KodouSelect: View {
    let label: String?
    let options: [String]
    @Binding var selection: Int
    let width: CGFloat
    @StateObject private var model: KodouOptions
    @StateObject private var open = KState(false)
    @StateObject private var hover = KState(false)
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled

    public init(_ label: String?, options: [String], selection: Binding<Int>, width: CGFloat = 200) {
        self.label = label; self.options = options; _selection = selection; self.width = width
        _model = StateObject(wrappedValue: KodouOptions(label: label ?? "候補"))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label { Text(label).font(.kdRead(13, weight: .bold)).foregroundStyle(enabled ? KD.fg : KD.faint) }
            Button { open.v ? close() : show() } label: {
                HStack {
                    Text(options.indices.contains(selection) ? options[selection] : "").lineLimit(1)
                    Spacer(minLength: 16)
                    Text("▾").foregroundStyle(KD.dim)
                }
                .font(.kdMono(13.5)).foregroundStyle(enabled ? KD.fg : KD.faint)
                .padding(.horizontal, 8).padding(.vertical, 3).frame(width: width)
                .background(KD.panel)
                .overlay {
                    if enabled { Rectangle().strokeBorder(open.v || hover.v ? KD.fg : KD.ui, lineWidth: 1) }
                    else { Rectangle().strokeBorder(KD.ui, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($focused)
            .focusEffectDisabled()
            .kodouFocusRing(focused && !open.v)
            .onHover { hover.v = $0 }
            .onKeyPress(.space) { open.v ? choose() : show(); return .handled }
            .onKeyPress(.downArrow) { open.v ? model.move(1) : show(); return .handled }
            .onKeyPress(.upArrow) { if open.v { model.move(-1) }; return .handled }
            .onKeyPress(.return) { if open.v { choose(); return .handled }; return .ignored }
            .onKeyPress(.escape) { if open.v { close(); return .handled }; return .ignored }
            .onKeyPress(characters: .alphanumerics) { k in typeAhead(k.characters); return .handled }
            .overlay(alignment: .topLeading) {
                if open.v {
                    KodouRows(model.rows).frame(width: width, height: model.height).kodouPopStyle()
                        .offset(y: 30)
                }
            }
            .accessibilityLabel(label ?? "")
            .accessibilityValue(options.indices.contains(selection) ? options[selection] : "")
            .accessibilityHint("Space で開き、↑↓ で選び、⏎ で決めます")
        }
        .zIndex(open.v ? 10 : 0)
        .onAppear { model.rows.onClick = { i in model.rows.select(i); choose() } }
    }

    private func show() {
        model.set(options.map { .init(text: $0, meta: nil, mark: nil, disabled: false) }, current: selection, cursor: selection)
        open.v = true
    }
    private func close() { open.v = false; focused = true }
    private func choose() {
        let c = model.cursor
        if c >= 0 { selection = c; kodouAnnounce(options[c]) }
        close()
    }
    private func typeAhead(_ s: String) {
        guard let ch = s.lowercased().first, !open.v else { return }
        let n = options.count
        for d in 1...max(1, n) {
            let i = (selection + d) % n
            if options[i].lowercased().first == ch { selection = i; kodouAnnounce(options[i]); return }
        }
    }
}

/// コンボボックス。打った分だけ候補を絞り、一致した文字に下線を引く。何件中何件かを出す。
/// 候補の並びは渡された順（使った回数の順）に固定し、打つたびに入れ替えない
public struct KodouCombo: View {
    let label: String
    let prefix: String?
    let placeholder: String
    let items: [String]
    let help: String
    let onPick: (String) -> Void
    @StateObject private var model: KodouOptions
    @StateObject private var query = KState("")
    @StateObject private var open = KState(false)
    @StateObject private var hits = KState<[Int]>([])
    @FocusState private var focused: Bool

    public init(_ label: String, prefix: String? = nil, placeholder: String = "", items: [String], help: String = "", onPick: @escaping (String) -> Void) {
        self.label = label; self.prefix = prefix; self.placeholder = placeholder; self.items = items; self.help = help; self.onPick = onPick
        _model = StateObject(wrappedValue: KodouOptions(label: label))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.kdRead(13, weight: .bold)).foregroundStyle(KD.fg)
            HStack(spacing: 0) {
                if let prefix {
                    Text(prefix).font(.kdMono(12.5)).foregroundStyle(KD.dim).padding(.horizontal, 8).frame(maxHeight: .infinity).background(KD.ruleSoft)
                }
                TextField(placeholder, text: $query.v)
                    .textFieldStyle(.plain).font(.kdMono(13.5)).padding(.horizontal, 8)
                    .focused($focused)
                    .onKeyPress(.downArrow) { if !open.v { refilter(); open.v = true } else { model.move(1) }; return .handled }
                    .onKeyPress(.upArrow) { model.move(-1); return .handled }
                    .onKeyPress(.escape) { if open.v { open.v = false; return .handled }; return .ignored }
                    .onSubmit { choose() }
                    .accessibilityLabel(label)
                    .accessibilityValue(open.v ? "\(hits.v.count) 件の候補" : "")
            }
            .frame(height: 28)
            .background(KD.panel)
            .overlay(Rectangle().strokeBorder(focused ? KD.fg : KD.ui, lineWidth: 1))
            .overlay(alignment: .bottom) { if focused { Rectangle().fill(KD.fg).frame(height: 2) } }
            if !help.isEmpty { Text(help).font(.kdRead(12.5)).foregroundStyle(KD.dim) }
        }
        // 候補は欄の下に重ねる（ヘルプの文より上に描くため、全体に重ねる）
        .overlay(alignment: .topLeading) { if open.v { pop.offset(y: 52) } }
        .zIndex(open.v ? 10 : 0)
        .onChange(of: query.v) { _, q in refilter(); open.v = !q.isEmpty; announce() }
        .onChange(of: focused) { _, f in if !f { open.v = false } }
        .onAppear { model.rows.onClick = { i in model.rows.select(i); choose() } }
    }

    private var pop: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(hits.v.count) / \(items.count) 件").font(.kdMono(12)).foregroundStyle(KD.faint).padding(.horizontal, 10).frame(height: 20)
            if hits.v.isEmpty {
                Text("「\(query.v)」に当たる候補はありません").font(.kdRead(13)).foregroundStyle(KD.dim).padding(.horizontal, 10).padding(.vertical, 4)
            } else {
                KodouRows(model.rows).frame(height: model.height)
            }
        }
        .frame(width: 420, alignment: .leading)
        .kodouPopStyle()
    }

    private func refilter() {
        let q = query.v.lowercased()
        var out: [KodouOptions.Item] = [], idx: [Int] = []
        for (i, it) in items.enumerated() {
            if q.isEmpty { out.append(.init(text: it, meta: nil, mark: nil, disabled: false)); idx.append(i); continue }
            if let r = it.lowercased().range(of: q) {
                let a = it.distance(from: it.startIndex, to: r.lowerBound)
                out.append(.init(text: it, meta: nil, mark: a..<(a + q.count), disabled: false)); idx.append(i)
            }
        }
        hits.v = idx
        model.set(out, current: -1, cursor: out.isEmpty ? -1 : 0)
    }
    private func choose() {
        let c = model.cursor
        guard open.v, c >= 0, c < hits.v.count else { return }
        let picked = items[hits.v[c]]
        onPick(picked); kodouAnnounce("\(picked) を選びました")
        query.v = ""; open.v = false
    }
    private func announce() { if open.v { kodouAnnounce("\(hits.v.count) 件") } }
}

/// メニューの 1 項目
public struct KodouMenuItem {
    let title: String, key: String?, danger: Bool, disabled: Bool, separatorBefore: Bool, action: () -> Void
    public init(_ title: String, key: String? = nil, danger: Bool = false, disabled: Bool = false, separatorBefore: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title; self.key = key; self.danger = danger; self.disabled = disabled; self.separatorBefore = separatorBefore; self.action = action
    }
}

/// メニュー。項目の横にキーを書き、開いている間はそのキーでも選べる。壊す操作は区切って最後に置く
public struct KodouMenu: View {
    let title: String
    let items: [KodouMenuItem]
    @StateObject private var open = KState(false)
    @StateObject private var cursor = KState(0)
    @FocusState private var focused: Bool
    public init(_ title: String, items: [KodouMenuItem]) { self.title = title; self.items = items }

    public var body: some View {
        Button { open.v.toggle(); cursor.v = items.firstIndex { !$0.disabled } ?? 0 } label: {
            HStack(spacing: 8) { Text(title); Text("▾").foregroundStyle(KD.dim) }
        }
        .buttonStyle(KodouButtonStyle())
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.downArrow) { if !open.v { open.v = true } else { move(1) }; return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.return) { if open.v { run(cursor.v); return .handled }; return .ignored }
        .onKeyPress(.escape) { if open.v { open.v = false; return .handled }; return .ignored }
        .onKeyPress(characters: .alphanumerics) { k in
            guard open.v, let i = items.firstIndex(where: { $0.key?.lowercased() == k.characters.lowercased() }) else { return .ignored }
            run(i); return .handled
        }
        .overlay(alignment: .topLeading) { if open.v { list.offset(y: 30) } }
        .zIndex(open.v ? 10 : 0)
        .accessibilityHint("↓ で開き、⏎ で選びます")
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let it = items[i], on = i == cursor.v && !it.disabled
                if it.separatorBefore { Rectangle().fill(KD.ruleSoft).frame(height: 1).padding(.vertical, 4) }
                HStack {
                    Text(it.title).font(.kdMono(13.5))
                    Spacer(minLength: 24)
                    if let k = it.key { Text(k).font(.kdMono(12)).foregroundStyle(on ? (it.danger ? KD.panel : KD.selFg) : KD.faint) }
                }
                .foregroundStyle(it.disabled ? KD.faint : on ? (it.danger ? KD.panel : KD.selFg) : it.danger ? KD.red : KD.fg)
                .padding(.horizontal, 10).frame(height: 24)
                .background(on ? (it.danger ? KD.red : KD.selBg) : .clear)
                .contentShape(Rectangle())
                .onHover { if $0 && !it.disabled { cursor.v = i } }
                .onTapGesture { run(i) }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { run(i) }
            }
        }
        .frame(width: 240)
        .kodouPopStyle()
    }
    private func move(_ d: Int) {
        var c = cursor.v
        for _ in 0..<items.count { c = (c + d + items.count) % items.count; if !items[c].disabled { break } }
        cursor.v = c
    }
    private func run(_ i: Int) {
        guard items.indices.contains(i), !items[i].disabled else { return }
        open.v = false; focused = true
        items[i].action()
    }
}
