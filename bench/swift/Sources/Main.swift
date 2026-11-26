// 4 つの版を 1 つずつ開いて測る。run.py が 1 回ずつ起動し、最後に JSON を書いて終わる。
//   KodouBench --variant kodou|lazy|tuned|plain|web|empty [--stream 60] [--warm 5] [--hidden 10] [--html path] --out file.json
import AppKit
import SwiftUI
import WebKit
import KodouUI

// MARK: 外から測る（footprint と ps）

enum Probe {
    static func run(_ exe: String, _ args: [String]) -> String {
        let p = Process(); p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return String(decoding: d, as: UTF8.self)
    }
    /// phys_footprint（MB）。Web ベンチと同じく footprint コマンドで取る
    static func footprintMB(_ pid: Int32) -> Double {
        let out = run("/usr/bin/footprint", ["-p", String(pid)])
        guard let r = out.range(of: #"Footprint: ([\d.]+) (KB|MB|GB)"#, options: .regularExpression) else { return 0 }
        let parts = out[r].split(separator: " "); let v = Double(parts[1]) ?? 0
        return v * (parts[2] == "KB" ? 1.0 / 1024 : parts[2] == "GB" ? 1024 : 1)
    }
    /// 使った CPU の時間（秒）の合計
    static func cpuSec(_ pids: [Int32]) -> Double {
        let out = run("/bin/ps", ["-o", "time=", "-p", pids.map(String.init).joined(separator: ",")])
        return out.split(separator: "\n").reduce(0) { s, line in
            let f = line.trimmingCharacters(in: .whitespaces).split(separator: ":").compactMap { Double($0) }
            return s + f.reduce(0) { $0 * 60 + $1 }
        }
    }
    static func webkitPids() -> Set<Int32> {
        Set(run("/usr/bin/pgrep", ["-f", "com.apple.WebKit"]).split(separator: "\n").compactMap { Int32($0) })
    }
    static func webkitKind(_ pid: Int32) -> String {
        let c = run("/bin/ps", ["-o", "comm=", "-p", String(pid)])
        return c.contains("WebContent") ? "content" : c.contains("GPU") ? "gpu" : c.contains("Networking") ? "net" : "other"
    }
    static func processStart() -> Double {
        var kp = kinfo_proc(); var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, 4, &kp, &size, nil, 0)
        let tv = kp.kp_proc.p_un.__p_starttime
        return Double(tv.tv_sec) + Double(tv.tv_usec) / 1e6
    }
}

func off<T: Sendable>(_ f: @escaping @Sendable () -> T) async -> T { await Task.detached { f() }.value }
func median(_ a: [Double]) -> Double { let s = a.sorted(); return s.isEmpty ? 0 : s[s.count / 2] }

// MARK: 測る係

@MainActor
final class Harness: NSObject {
    let variant: String, stream: Double, warm: Double, hiddenSec: Double, out: String, html: String
    let start = Probe.processStart()
    var window: NSWindow!
    var select: (Int) -> Void = { _ in }
    var web: WKWebView?
    var webPids: [Int32] = []
    private var link: CADisplayLink?
    private var stamps: [Double] = [], recording = false
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var keep: [AnyObject] = []

    init(args: [String]) {
        func opt(_ k: String) -> String? { args.firstIndex(of: k).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        variant = opt("--variant") ?? "kodou"; stream = Double(opt("--stream") ?? "60")!; warm = Double(opt("--warm") ?? "5")!
        hiddenSec = Double(opt("--hidden") ?? "10")!; out = opt("--out") ?? "out.json"; html = opt("--html") ?? ""
    }

    func launch() {
        NSApp.appearance = NSAppearance(named: .aqua)   // Web のベンチと同じ明るい地
        window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 1280, height: 800), styleMask: [.titled, .miniaturizable, .closable], backing: .buffered, defer: false)
        window.title = "KodouBench — \(variant)"
        window.level = .floating            // ほかの窓の下に隠れて止まらないように
        window.isReleasedWhenClosed = false
        var before = Set<Int32>()
        switch variant {
        case "kodou":
            let m = KodouModel(); keep.append(m)
            window.contentView = NSHostingView(rootView: KodouRoot(m: m))
            m.ticker.watch(window)
            select = { m.sessions.rows.select($0) }
        case "lazy":
            let m = LazyModel(); keep.append(m)
            window.contentView = NSHostingView(rootView: LazyRoot(m: m))
            m.ticker.watch(window)
            select = { m.act = $0 }
        case "tuned":
            let m = TunedModel(); keep.append(m)
            window.contentView = NSHostingView(rootView: TunedRoot(m: m))
            select = { m.selection = $0 }
        case "plain":
            let m = PlainModel(); keep.append(m)
            window.contentView = NSHostingView(rootView: PlainRoot(m: m))
            select = { m.selection = $0 }
        case "empty":   // 測る仕組みだけの重さ（表示更新を数える CADisplayLink と、地の色だけの窓）
            window.contentView = NSHostingView(rootView: Color(nsColor: KodouColor.bg))
        case "web":
            before = Probe.webkitPids()
            let w = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800)); web = w
            window.contentView = w
            let url = URL(fileURLWithPath: html)
            w.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent().deletingLastPathComponent())
        default: fatalError("unknown variant \(variant)")
        }
        window.orderFrontRegardless()
        let l = window.contentView!.displayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common); link = l
        Task { await self.measure(before: before) }
    }

    @objc private func tick(_ l: CADisplayLink) {
        if recording { stamps.append(l.timestamp * 1000) }
        var rest: [(Int, CheckedContinuation<Void, Never>)] = []
        for (n, c) in waiters { if n <= 1 { c.resume() } else { rest.append((n - 1, c)) } }
        waiters = rest
    }
    private func ticks(_ n: Int) async { await withCheckedContinuation { waiters.append((n, $0)) } }
    private func sleep(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1e9)) }
    private func js(_ s: String) async -> Any? { try? await web?.callAsyncJavaScript(s, contentWorld: .page) }

    private func measure(before: Set<Int32>) async {
        // 起動から最初の描画まで（Web は頁の __ready の時刻）
        var readyMs: Double
        if web != nil {
            while (await js("return window.__ready ?? null") as? Double) == nil { await sleep(0.05) }
            let abs = (await js("return performance.timeOrigin + window.__ready") as? Double) ?? 0
            readyMs = abs - start * 1000
            webPids = Array(Probe.webkitPids().subtracting(before)).sorted()
        } else {
            await ticks(2); readyMs = (Date().timeIntervalSince1970 - start) * 1000
        }
        let me = getpid(), pids = [me] + webPids
        await sleep(warm)

        // 流しているあいだ
        if web != nil {
            _ = await js("const iv = []; let last = performance.now(); window.__iv = iv; const f = t => { iv.push(t - last); last = t; if (window.__iv === iv) requestAnimationFrame(f) }; requestAnimationFrame(f); return 0")
        }
        let fp0 = await off { pids.reduce(0) { $0 + Probe.footprintMB($1) } }
        let c0 = await off { Probe.cpuSec(pids) }; let t0 = CACurrentMediaTime()
        stamps = []; recording = true
        await sleep(stream)
        recording = false
        let c1 = await off { Probe.cpuSec(pids) }; let t1 = CACurrentMediaTime()
        let fp1 = await off { pids.reduce(0) { $0 + Probe.footprintMB($1) } }
        var iv: [Double]
        if web != nil {
            iv = (await js("const a = window.__iv; window.__iv = null; return a") as? [Double]) ?? []
        } else {
            iv = zip(stamps.dropFirst(), stamps).map { $0 - $1 }
        }

        // 選ぶ操作: 選んでから 2 コマ目の表示更新まで
        var sel: [Double] = []
        if web != nil {
            sel = (await js("const out = []; for (let n = 0; n < 20; n++) { const i = (n * 997) % 10000; const t0 = performance.now(); window.__select(i); await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))); out.push(performance.now() - t0) } return out") as? [Double]) ?? []
        } else {
            for n in 0..<20 {
                let i = (n * 997) % 10000, s = CACurrentMediaTime()
                select(i); await ticks(2)
                sel.append((CACurrentMediaTime() - s) * 1000)
            }
        }
        await sleep(1)
        var mem: [String: Double] = ["app": await off { Probe.footprintMB(me) }]
        for p in webPids { let k = await off { Probe.webkitKind(p) }; mem[k, default: 0] += await off { Probe.footprintMB(p) } }

        // 隠れているあいだ（窓を画面から外す）
        window.orderOut(nil)
        await sleep(0.8)
        let h0 = await off { Probe.cpuSec(pids) }, ht0 = CACurrentMediaTime()
        await sleep(hiddenSec)
        let h1 = await off { Probe.cpuSec(pids) }, ht1 = CACurrentMediaTime()

        let sorted = iv.sorted()
        let res: [String: Any] = [
            "variant": variant, "readyMs": readyMs,
            "memMB": mem.values.reduce(0, +), "memParts": mem,
            "memStreamStartMB": fp0, "memStreamEndMB": fp1,
            "busyPct": (c1 - c0) / (t1 - t0) * 100,
            "frames": iv.count, "frameP95": median(Array(sorted.suffix(max(1, sorted.count / 20)))), "frameMax": sorted.last ?? 0,
            "longFrames": iv.filter { $0 > 50 }.count,
            "selectMs": median(sel),
            "hiddenBusyPct": (h1 - h0) / (ht1 - ht0) * 100,
            "pids": pids.count,
        ]
        let data = try! JSONSerialization.data(withJSONObject: res, options: [.prettyPrinted, .sortedKeys])
        try! data.write(to: URL(fileURLWithPath: out))
        NSApp.terminate(nil)
    }
}

@main
enum BenchMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)   // Dock に出さず、前面のアプリも奪わない
        let h = MainActor.assumeIsolated { Harness(args: CommandLine.arguments) }
        DispatchQueue.main.async { MainActor.assumeIsolated { h.launch() } }
        withExtendedLifetime(h) { app.run() }
    }
}
