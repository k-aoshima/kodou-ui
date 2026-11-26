import AppKit

/// 流れ続けるログ。上限つきのリングバッファに溜め、見えている行だけを描く。
/// 末尾を追いかけ、利用者が上へ戻すと止まる。append はいくら呼んでも、描き直しは batchMs ごとに 1 回。
/// 上限に達したあとは、先頭の行を消して末尾に足す形で NSTableView に伝えるので、見えている行を描き直さずに済む
@MainActor
public final class KodouLog<Line>: KodouRowsSource {
    public let rows: KodouRowsController
    private var ring: KodouRing<Line>
    private let cellsFor: (Line) -> [KodouCell]
    private let ticker: KodouTicker
    private var added = 0, removed = 0
    /// 描き直しをまとめる間隔（ms）。人が読める速さより速く流れるログでも、画面を変えるのはこの間隔に 1 回
    public var batchMs: Double = 50

    public init(capacity: Int, columns: [KodouColumn], rowHeight: CGFloat = 19, font: NSFont = KodouFont.mono(12),
                label: String = "ログ", ticker: KodouTicker, cells: @escaping (Line) -> [KodouCell]) {
        ring = KodouRing(capacity: capacity); cellsFor = cells; self.ticker = ticker
        rows = KodouRowsController(columns: columns, rowHeight: rowHeight, font: font, label: label)
        rows.followsTail = true
        rows.table.selectionHighlightStyle = .none
        rows.source = self
    }

    public var rowCount: Int { ring.count }
    public func cells(_ row: Int) -> [KodouCell] { cellsFor(ring[row]) }

    public func append(_ line: Line) {
        if ring.count == ring.capacity { removed += 1 }
        ring.append(line); added += 1
        ticker.frame("kodou-log-\(ObjectIdentifier(self).hashValue)", after: batchMs) { [weak self] in self?.flush() }
    }

    private func flush() {
        let n = ring.count, a = min(added, n), r = min(removed, n)
        added = 0; removed = 0
        if r >= n || a >= n { rows.reloadAll(); return }   // 1 回で全部入れ替わったとき
        rows.shift(removedFromTop: r, appended: a)
    }
}
