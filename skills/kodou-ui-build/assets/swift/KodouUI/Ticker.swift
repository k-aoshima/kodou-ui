import AppKit

/// タイマーは 1 本（Web の every と同じ考え方）。
/// - 次に来る仕事の時刻まで眠り、間に合わなかった分は最大 10 回まで追いつく
/// - frame(key) で頼んだ描き直しは、仕事を回したあとに 1 回だけ行う。after を付けると、その時間はまとめて待つ
/// - 見ている窓が隠れている（ほかの窓の下、しまった、アプリを隠した）あいだは止まる
@MainActor
public final class KodouTicker {
    private struct Task { let ms: Double; let fn: () -> Void; var last: Double }
    private var tasks: [Task] = []
    private var jobs: [String: (due: Double, fn: () -> Void)] = [:], order: [String] = []
    private var timer: Timer?
    private weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []
    public private(set) var paused = false

    public init() {}

    private static func now() -> Double { CACurrentMediaTime() * 1000 }

    /// ms ごとに fn を呼ぶ
    public func every(_ ms: Double, _ fn: @escaping () -> Void) {
        tasks.append(Task(ms: ms, fn: fn, last: 0)); plan(0)
    }

    /// 描き直しを頼む。同じ key は 1 回にまとまる。
    /// after（ms）を付けると、最初に頼んでからその時間が経つまで待ち、そのあいだの頼みを 1 回にまとめる
    public func frame(_ key: String, after ms: Double = 0, _ fn: @escaping () -> Void) {
        if let j = jobs[key] { jobs[key] = (j.due, fn); return }
        let due = Self.now() + ms
        jobs[key] = (due, fn); order.append(key)
        plan(ms)
    }

    /// この窓が見えていないあいだは止める
    public func watch(_ w: NSWindow) {
        window = w
        let nc = NotificationCenter.default
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
            observers.append(nc.addObserver(forName: name, object: w, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.syncVisibility() } })
        }
        for name in [NSApplication.didHideNotification, NSApplication.didUnhideNotification] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.syncVisibility() } })
        }
        syncVisibility()
    }

    private func syncVisibility() {
        guard let w = window else { return }
        let hidden = !w.occlusionState.contains(.visible) || w.isMiniaturized || NSApp.isHidden
        if hidden == paused { return }
        paused = hidden
        if hidden { timer?.invalidate(); timer = nil; for i in tasks.indices { tasks[i].last = 0 } } else { plan(0) }
    }

    private func plan(_ ms: Double) {
        guard !paused else { return }
        let fire = Date(timeIntervalSinceNow: max(0, ms) / 1000)
        if let t = timer, t.isValid, t.fireDate <= fire { return }
        timer?.invalidate()
        let t = Timer(fire: fire, interval: 0, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        t.tolerance = 0.002
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        timer = nil
        let now = Self.now()
        var wait = Double.infinity
        for i in tasks.indices {
            if tasks[i].last == 0 { tasks[i].last = now; tasks[i].fn() }
            else if now - tasks[i].last >= tasks[i].ms {
                let n = Int((now - tasks[i].last) / tasks[i].ms)
                tasks[i].last += Double(n) * tasks[i].ms
                for _ in 0..<min(n, 10) { tasks[i].fn() }
            }
            wait = min(wait, tasks[i].last + tasks[i].ms - now)
        }
        let ks = order; order = []
        var run: [() -> Void] = []
        for k in ks {
            guard let j = jobs[k] else { continue }
            if j.due <= now + 1 { run.append(j.fn); jobs[k] = nil } else { order.append(k); wait = min(wait, j.due - now) }
        }
        for f in run { f() }
        if wait < .infinity { plan(wait) }
    }
}
