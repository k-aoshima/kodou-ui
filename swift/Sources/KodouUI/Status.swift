import SwiftUI

public enum KodouTone: Sendable { case info, ok, warn, err, neutral
    var color: Color { switch self { case .info: KD.blue; case .ok: KD.green; case .warn: KD.yellow; case .err: KD.red; case .neutral: KD.dim } }
    var bg: Color { switch self { case .info: KD.blueBg; case .ok: KD.greenBg; case .warn: KD.yellowBg; case .err: KD.redBg; case .neutral: KD.ruleSoft } }
    var tag: String { switch self { case .info: "[INFO]"; case .ok: "[ OK ]"; case .warn: "[WARN]"; case .err: "[FAIL]"; case .neutral: "[NOTE]" } }
}

/// 通知の帯。何が起きたかと、どう直すかを文で書く。種類は色だけでなく [FAIL] のような文字でも示す。
/// エラーコードや生のログは消さずに、折りたたんで残す
public struct KodouAlert<Actions: View>: View {
    let tone: KodouTone
    let message: String
    let detailTitle: String?
    let detail: String?
    let actions: Actions
    let onClose: (() -> Void)?
    @StateObject private var open = KState(false)
    public init(_ tone: KodouTone, _ message: String, detailTitle: String? = nil, detail: String? = nil, onClose: (() -> Void)? = nil, @ViewBuilder actions: () -> Actions) {
        self.tone = tone; self.message = message; self.detailTitle = detailTitle; self.detail = detail; self.onClose = onClose; self.actions = actions()
    }
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(tone.tag).font(.kdMono(12.5, weight: .bold)).foregroundStyle(tone.color).padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(message).font(.kdRead(14)).foregroundStyle(KD.fg).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) { actions }
                if let detail {
                    Button { open.v.toggle() } label: {
                        Text("\(open.v ? "▾" : "▸") \(detailTitle ?? "詳しい内容")").font(.kdMono(12.5)).foregroundStyle(KD.dim).kodouHitTarget()
                    }.buttonStyle(.plain).accessibilityValue(open.v ? "開いています" : "閉じています")
                    if open.v {
                        Text(detail).font(.kdMono(12)).foregroundStyle(KD.fg).textSelection(.enabled)
                            .padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading).background(KD.ruleSoft)
                    }
                }
            }
            Spacer(minLength: 0)
            if let onClose {
                Button(action: onClose) { Text("×").font(.kdMono(13)).foregroundStyle(KD.dim).frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("閉じる")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(tone.bg)
        .overlay(Rectangle().strokeBorder(tone.color, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tone.tag)
    }
}

public extension KodouAlert where Actions == EmptyView {
    init(_ tone: KodouTone, _ message: String, detailTitle: String? = nil, detail: String? = nil, onClose: (() -> Void)? = nil) {
        self.init(tone, message, detailTitle: detailTitle, detail: detail, onClose: onClose) { EmptyView() }
    }
}

/// バッジ。塗り（solid）と枠（outline）。状態は色だけでなく記号や文字でも分かるようにする
public struct KodouBadge: View {
    let text: String
    let tone: KodouTone
    let solid: Bool
    public init(_ text: String, tone: KodouTone = .neutral, solid: Bool = true) { self.text = text; self.tone = tone; self.solid = solid }
    public var body: some View {
        let c: Color = tone == .neutral ? KD.selBg : tone.color
        Text(text).font(.kdMono(12)).lineLimit(1)
            .padding(.horizontal, 6).frame(height: 20)
            .foregroundStyle(solid ? (tone == .neutral ? KD.selFg : KD.on) : (tone == .neutral ? KD.dim : tone.color))
            .background(solid ? c : .clear)
            .overlay { if !solid { Rectangle().strokeBorder(tone == .neutral ? KD.rule : tone.color, lineWidth: 1) } }
    }
}

/// 件数の小さな札（赤）
public struct KodouCount: View {
    let n: Int
    public init(_ n: Int) { self.n = n }
    public var body: some View {
        Text("\(n)").font(.kdMono(12)).foregroundStyle(KD.on).padding(.horizontal, 4).frame(minWidth: 22, minHeight: 18).background(KD.red)
            .accessibilityLabel("\(n) 件")
    }
}

/// 点と文字の状態。● 動いている、◐ 起動中、■ 止まっている、○ 未設定
public struct KodouStatusDot: View {
    public enum State: Sendable { case running, starting, stopped, unset }
    let text: String
    let state: State
    public init(_ text: String, _ state: State) { self.text = text; self.state = state }
    public var body: some View {
        let (m, c): (String, Color) = switch state { case .running: ("●", KD.green); case .starting: ("◐", KD.yellow); case .stopped: ("■", KD.red); case .unset: ("○", KD.faint) }
        HStack(spacing: 6) { Text(m).font(.kdMono(13.5)).foregroundStyle(c); Text(text).font(.kdRead(13.5)).foregroundStyle(KD.fg) }
            .accessibilityElement(children: .combine)
    }
}

/// 起動ログの 1 行（[  OK  ] [ WARN ] [FAILED]）
public struct KodouBootLine: View {
    let tone: KodouTone
    let text: String
    public init(_ tone: KodouTone, _ text: String) { self.tone = tone; self.text = text }
    public var body: some View {
        let s: String = switch tone { case .ok: "  OK  "; case .warn: " WARN "; case .err: "FAILED"; default: "  ⠿   " }
        HStack(spacing: 0) {
            Text("[").foregroundStyle(KD.fg); Text(s).fontWeight(.bold).foregroundStyle(tone.color); Text("] ").foregroundStyle(KD.fg)
            Text(text).foregroundStyle(KD.fg)
        }
        .font(.kdMono(13)).lineSpacing(4)
    }
}

/// 空の状態。なぜ空なのかと、最初の 1 件を作る方法を書く
public struct KodouEmpty<Actions: View>: View {
    let icon: String
    let title: String
    let message: String
    let actions: Actions
    public init(icon: String = "box", title: String, message: String, @ViewBuilder actions: () -> Actions) {
        self.icon = icon; self.title = title; self.message = message; self.actions = actions()
    }
    public var body: some View {
        VStack(spacing: 8) {
            KodouIcon(icon, cell: 4, small: true, tone: true).foregroundStyle(KD.faint)
            Text(title).font(.kdRead(15, weight: .bold)).foregroundStyle(KD.fg)
            Text(message).font(.kdRead(14)).foregroundStyle(KD.dim).multilineTextAlignment(.center)
            HStack(spacing: 8) { actions }
        }
        .padding(.vertical, 28).padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

/// LED の帯。埋まった分は細い縦の目盛りを並べ、空いた分は薄い目盛りにする（進捗バーとメーターが使う）
struct KodouLedBar: View {
    let fraction: Double
    var color: Color = KD.blue
    var height: CGFloat = 8
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 4, n = Int(size.width / step)
            let on = Int((Double(n) * min(1, max(0, fraction))).rounded())
            var a = Path(), b = Path()
            for i in 0..<n {
                let r = CGRect(x: CGFloat(i) * step, y: 0, width: 2, height: size.height)
                if i < on { a.addRect(r) } else { b.addRect(r) }
            }
            ctx.fill(a, with: .color(color)); ctx.fill(b, with: .color(KD.deco.opacity(0.6)))
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// 進捗バー。割合だけでなく、件数・かかった時間・今の対象を出す。手順があるものは今どこかを並べる
public struct KodouProgress: View {
    let label: String
    let done: Int, total: Int
    let meta: String
    let steps: [String]
    let current: Int
    public init(_ label: String, done: Int, total: Int, meta: String = "", steps: [String] = [], current: Int = 0) {
        self.label = label; self.done = done; self.total = total; self.meta = meta; self.steps = steps; self.current = current
    }
    public var body: some View {
        let f = total == 0 ? 0 : Double(done) / Double(total)
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(label).foregroundStyle(KD.dim); Spacer(); Text("\(Int(f * 100))%").fontWeight(.bold) }.font(.kdMono(13))
            KodouLedBar(fraction: f)
            if !meta.isEmpty { Text(meta).font(.kdMono(12.5)).foregroundStyle(KD.dim).lineLimit(1) }
            if !steps.isEmpty {
                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { i in
                        if i > 0 { Text("—").foregroundStyle(KD.faint) }
                        Text(i < current ? "✓ \(steps[i])" : i == current ? "▸ \(steps[i])" : steps[i])
                            .fontWeight(i == current ? .bold : .regular)
                            .foregroundStyle(i < current ? KD.green : i == current ? KD.blue : KD.faint)
                    }
                }.font(.kdMono(13)).padding(.top, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(done) / \(total)、\(Int(f * 100))%。\(meta)" + (steps.isEmpty ? "" : "。今は \(steps[min(current, steps.count - 1)])"))
    }
}

/// スピナー。1 秒未満で終わる処理には出さない（delay）。1 秒を超えたら、何をしているかと件数か経過時間を添える。
/// 窓が見えていないあいだと、動きを減らす設定のときは回さない
public struct KodouSpinner: View {
    let text: String
    let detail: (TimeInterval) -> String
    let delay: TimeInterval
    @StateObject private var watch = KodouWindowWatch()
    @StateObject private var start = KState(Date())
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let frames = Array("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")
    public init(_ text: String, delay: TimeInterval = 1, detail: @escaping (TimeInterval) -> String = { String(format: "%.1f秒", $0) }) {
        self.text = text; self.delay = delay; self.detail = detail
    }
    public var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 0.1, paused: !watch.visible)) { ctx in
            let t = max(0, ctx.date.timeIntervalSince(start.v))
            if delay <= 0 || t >= delay {
                HStack(spacing: 8) {
                    Text(reduceMotion || !watch.visible ? "⠿" : String(Self.frames[Int(t * 10) % Self.frames.count])).foregroundStyle(KD.blue).frame(width: 10)
                    Text(text).foregroundStyle(KD.fg)
                    Text(detail(t)).foregroundStyle(KD.fg)
                }
                .font(.kdMono(13))
            }
        }
        .background(KodouWindowReader { watch.attach($0) })
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .onAppear { start.v = Date() }
    }
}

/// メーター。使った量を LED の帯で見せ、数字は実際の値で書く。境目を超えたことは色に加えて「注意」「危険」の文字でも出す
public struct KodouMeter: View {
    let label: String
    let value: Double, max: Double
    let text: String
    let warn: Double, danger: Double
    let note: String?
    public init(_ label: String, value: Double, max: Double, text: String, warn: Double = 0.8, danger: Double = 0.85, note: String? = nil) {
        self.label = label; self.value = value; self.max = max; self.text = text; self.warn = warn; self.danger = danger; self.note = note
    }
    public var body: some View {
        let f = max == 0 ? 0 : value / max
        let state: (String, Color)? = f >= danger ? ("危険", KD.red) : f >= warn ? ("注意", KD.yellow) : nil
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(label).font(.kdMono(13, weight: .bold)).foregroundStyle(KD.cyan).frame(width: 36, alignment: .leading)
                KodouLedBar(fraction: f, color: state?.1 ?? KD.blue, height: 10)
                Text(text).font(.kdMono(13)).foregroundStyle(KD.fg).frame(minWidth: 72, alignment: .trailing)
                Text(state?.0 ?? "").font(.kdMono(13, weight: .bold)).foregroundStyle(state?.1 ?? .clear).frame(width: 30, alignment: .leading)
            }
            if let note { Text(note).font(.kdRead(12)).foregroundStyle(KD.dim).padding(.leading, 44) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(text)、\(Int(f * 100))%" + (state.map { "、\($0.0)" } ?? ""))
    }
}
