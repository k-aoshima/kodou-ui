import SwiftUI

/// スライダー。溝は LED の目盛りのようなドット絵（埋まった所はアクセント色の 8pt の四角を 4pt あけて並べ、
/// 空いた所は 2pt の細い線）、つまみもドット絵。溝の幅 192pt、つまみの中心は 6 + 12i pt。
/// ←→（1 つ）、PageUp/PageDown（4 つ）、Home/End で動かせる。動かすと同時に値と何が変わるかを出す
public struct KodouSlider: View {
    let label: String
    @Binding var index: Int
    let steps: [String]
    let ticks: [Int]
    let note: (Int) -> String
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled
    public init(_ label: String, index: Binding<Int>, steps: [String], ticks: [Int] = [], note: @escaping (Int) -> String = { _ in "" }) {
        self.label = label; _index = index; self.steps = steps; self.ticks = ticks; self.note = note
    }
    private var n: Int { steps.count }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.kdRead(13, weight: .bold)).foregroundStyle(enabled ? KD.fg : KD.faint)
            HStack(spacing: 12) {
                rail
                Text(steps[index]).font(.kdMono(13.5, weight: .bold)).foregroundStyle(enabled ? KD.fg : KD.faint).frame(minWidth: 32, alignment: .leading)
            }
            if !ticks.isEmpty {
                ZStack(alignment: .topLeading) {
                    ForEach(ticks, id: \.self) { t in
                        Text(steps[t]).font(.kdMono(12)).foregroundStyle(KD.faint).fixedSize()
                            .alignmentGuide(.leading) { d in d.width / 2 - CGFloat(6 + 12 * t) * 192 / CGFloat(12 * n) }
                    }
                }.frame(width: 192, height: 18, alignment: .topLeading)
            }
            let t = note(index)
            if !t.isEmpty { Text(t).font(.kdRead(12.5)).foregroundStyle(KD.dim) }
        }
    }
    private var cell: CGFloat { 192 / CGFloat(n) }
    private var rail: some View {
        let accent = enabled ? KD.accent : KD.accent.opacity(0.45)
        return ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                for i in 0..<n {
                    let cx = cell * (CGFloat(i) + 0.5)
                    if i < index { ctx.fill(Path(CGRect(x: cx - 4, y: 8, width: 8, height: 8)), with: .color(accent)) }
                }
                let kx = cell * (CGFloat(index) + 0.5)
                ctx.fill(Path(CGRect(x: kx + 6, y: 11, width: max(0, size.width - kx - 6), height: 2)), with: .color(KD.ui))
            }
            KodouIcon("knob", cell: 2, small: true)
                .foregroundStyle(!enabled ? KD.faint : focused ? KD.accent : KD.fg)
                .kodouFocusRing(focused)
                .offset(x: cell * (CGFloat(index) + 0.5) - 6)
        }
        .frame(width: 192, height: 24)
        .opacity(enabled ? 1 : 0.45)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { g in
            guard enabled else { return }
            index = min(n - 1, max(0, Int(g.location.x / cell)))
        })
        .onHover { h in if enabled { (h ? NSCursor.openHand : NSCursor.arrow).set() } }
        .focusable(enabled).focused($focused).focusEffectDisabled()
        .onKeyPress(.rightArrow) { set(index + 1) }
        .onKeyPress(.leftArrow) { set(index - 1) }
        .onKeyPress(.pageUp) { set(index + 4) }
        .onKeyPress(.pageDown) { set(index - 4) }
        .onKeyPress(.home) { set(0) }
        .onKeyPress(.end) { set(n - 1) }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(steps[index])
        .accessibilityAdjustableAction { d in _ = set(d == .increment ? index + 1 : index - 1) }
    }
    private func set(_ i: Int) -> KeyPress.Result { index = min(n - 1, max(0, i)); return .handled }
}

/// 数値。- と + のボタン、↑↓（1 つ）、⇧＋↑↓（最大・最小）、直接の入力のどれでも変えられる。
/// 範囲の端で止まったら、なぜ止まったかを出す
public struct KodouStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let help: String
    let why: (Int) -> String
    @StateObject private var text = KState("")
    @StateObject private var msg = KState<String?>(nil)
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled
    public init(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, help: String = "", why: @escaping (Int) -> String = { _ in "" }) {
        self.label = label; _value = value; self.range = range; self.help = help; self.why = why
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.kdRead(13, weight: .bold)).foregroundStyle(enabled ? KD.fg : KD.faint)
            HStack(spacing: 0) {
                stepButton("-", value > range.lowerBound) { set(value - 1) }
                TextField("", text: $text.v)
                    .textFieldStyle(.plain).multilineTextAlignment(.center).font(.kdMono(13.5)).frame(width: 48).padding(.vertical, 3)
                    .focused($focused)
                    .onSubmit { if let v = Int(text.v) { set(v) } else { text.v = "\(value)" } }
                    .onKeyPress(keys: [.upArrow, .downArrow]) { k in
                        let up = k.key == .upArrow
                        set(k.modifiers.contains(.shift) ? (up ? range.upperBound : range.lowerBound) : value + (up ? 1 : -1)); return .handled
                    }
                    .overlay(alignment: .leading) { Rectangle().fill(KD.ruleSoft).frame(width: 1) }
                    .overlay(alignment: .trailing) { Rectangle().fill(KD.ruleSoft).frame(width: 1) }
                    .accessibilityLabel(label)
                    .accessibilityValue("\(value)")
                stepButton("+", value < range.upperBound) { set(value + 1) }
            }
            .fixedSize()
            .overlay(Rectangle().strokeBorder(focused ? KD.fg : KD.ui, lineWidth: 1))
            Text(msg.v ?? help).font(.kdRead(12.5)).foregroundStyle(msg.v == nil ? KD.dim : KD.yellow)
        }
        .onAppear { text.v = "\(value)" }
        .onChange(of: value) { _, v in text.v = "\(v)" }
    }
    private func stepButton(_ t: String, _ ok: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Text(t).font(.kdMono(13.5, weight: .bold)).foregroundStyle(ok && enabled ? KD.fg : KD.faint).frame(width: 30, height: 26).contentShape(Rectangle()) }
            .buttonStyle(.plain).disabled(!ok).accessibilityLabel(t == "+" ? "増やす" : "減らす")
    }
    private func set(_ v: Int) {
        let c = min(range.upperBound, max(range.lowerBound, v))
        value = c; text.v = "\(c)"
        if c != v || c == range.upperBound || c == range.lowerBound {
            let w = why(c)
            msg.v = w.isEmpty ? nil : w
            if let m = msg.v { kodouAnnounce(m) }
        } else { msg.v = nil }
    }
}

/// テキストエリア。行番号を付け、行ごとの決まりを守れていない行は番号に ! を付けて色も変える
public struct KodouTextArea: View {
    let label: String
    @Binding var text: String
    let help: String
    let limit: Int?
    let rule: (Int, String) -> Bool
    @FocusState private var focused: Bool
    public init(_ label: String, text: Binding<String>, help: String = "", firstLineLimit: Int? = nil, rule: @escaping (Int, String) -> Bool = { _, _ in true }) {
        self.label = label; _text = text; self.help = help; limit = firstLineLimit; self.rule = rule
    }
    public var body: some View {
        let lines = text.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(lines.indices, id: \.self) { i in
                        let ok = rule(i, lines[i])
                        Text(ok ? "\(i + 1)" : "!\(i + 1)").font(.kdMono(13.5, weight: ok ? .regular : .bold))
                            .foregroundStyle(ok ? KD.faint : KD.yellow).frame(height: lineH)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 4).padding(.trailing, 6).frame(width: 40, alignment: .trailing)
                .overlay(alignment: .trailing) { Rectangle().fill(KD.ruleSoft).frame(width: 1) }
                .accessibilityHidden(true)
                TextEditor(text: $text)
                    .font(.kdMono(13.5)).lineSpacing(lineH - 16)
                    .scrollContentBackground(.hidden).scrollIndicators(.never)
                    .focused($focused)
                    .padding(.top, 4)
                    .accessibilityLabel(label)
                    .accessibilityHint(warnings(lines).map { "守れていない行: \($0)" } ?? help)
            }
            .frame(minHeight: 6.5 * lineH)
            .background(KD.panel)
            .overlay(Rectangle().strokeBorder(focused ? KD.fg : KD.ui, lineWidth: 1))
            HStack {
                Text(help).font(.kdRead(12.5)).foregroundStyle(KD.dim)
                Spacer()
                if let limit { Text("\(lines.first?.count ?? 0)/\(limit)").font(.kdMono(12.5)).foregroundStyle((lines.first?.count ?? 0) > limit ? KD.yellow : KD.faint) }
            }
        }
    }
    private var lineH: CGFloat { 21.6 }
    private func warnings(_ lines: [String]) -> String? {
        let bad = lines.indices.filter { !rule($0, lines[$0]) }.map { "\($0 + 1) 行目" }
        return bad.isEmpty ? nil : bad.joined(separator: "、")
    }
}

/// タグ入力。⏎ か「,」で確定し、空欄で ⌫ を押すと最後の 1 つを外す。重なりはその場で知らせる
public struct KodouTagInput: View {
    let label: String
    @Binding var tags: [String]
    let max: Int
    let placeholder: String
    @StateObject private var draft = KState("")
    @StateObject private var warn = KState<String?>(nil)
    @FocusState private var focused: Bool
    public init(_ label: String, tags: Binding<[String]>, max: Int = 3, placeholder: String = "ラベルを足す") {
        self.label = label; _tags = tags; self.max = max; self.placeholder = placeholder
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.kdRead(13, weight: .bold)).foregroundStyle(KD.fg)
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { t in
                    HStack(spacing: 0) {
                        Text(t).font(.kdMono(12.5)).padding(.leading, 6)
                        Button { remove(t) } label: { Text("×").font(.kdMono(12.5)).opacity(0.7).frame(width: 24, height: 24).contentShape(Rectangle()) }
                            .buttonStyle(.plain).accessibilityLabel("\(t) を外す")
                    }
                    .foregroundStyle(KD.selFg).frame(height: 22).background(KD.selBg)
                }
                TextField(tags.count >= max ? "" : placeholder, text: $draft.v)
                    .textFieldStyle(.plain).font(.kdMono(13.5)).frame(minWidth: 96)
                    .focused($focused)
                    .disabled(tags.count >= max)
                    .onSubmit { commit() }
                    .onKeyPress(.delete) { if draft.v.isEmpty, let last = tags.last { remove(last); return .handled }; return .ignored }
                    .accessibilityLabel(label)
                    .accessibilityValue(tags.joined(separator: "、"))
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KD.panel)
            .overlay(Rectangle().strokeBorder(focused ? KD.fg : KD.ui, lineWidth: 1))
            Text(warn.v ?? (tags.count >= max ? "これ以上は付けられません" : "あと \(max - tags.count) 個付けられます"))
                .font(.kdRead(12.5)).foregroundStyle(warn.v == nil ? KD.dim : KD.yellow)
        }
        .onChange(of: draft.v) { _, v in if v.hasSuffix(",") || v.hasSuffix("、") { draft.v = String(v.dropLast()); commit() } }
    }
    private func commit() {
        let t = draft.v.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, tags.count < max else { return }
        if tags.contains(t) { warn.v = "\(t) はもう付いています"; kodouAnnounce(warn.v!); return }
        tags.append(t); draft.v = ""; warn.v = nil
    }
    private func remove(_ t: String) { tags.removeAll { $0 == t }; warn.v = nil; kodouAnnounce("\(t) を外しました") }
}
