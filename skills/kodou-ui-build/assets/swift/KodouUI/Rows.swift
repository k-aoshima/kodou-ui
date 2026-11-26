import AppKit
import SwiftUI

/// 1 つの欄。幅は等幅の文字数（ch）で決めるか、残りを使う
public struct KodouColumn: Sendable {
    public enum Width: Sendable { case ch(Int), fill }
    public let width: Width
    public init(_ width: Width) { self.width = width }
}

/// 1 つの欄に出す文字と色（nil は地の文字色）
public struct KodouCell {
    public let text: String
    public let color: NSColor?
    /// 一致した所（文字の位置）。緑の太字の下線で示す（コンボボックスの候補）
    public let mark: Range<Int>?
    public let bold: Bool
    public init(_ text: String, _ color: NSColor? = nil, mark: Range<Int>? = nil, bold: Bool = false) { self.text = text; self.color = color; self.mark = mark; self.bold = bold }
}

/// 一覧の中身を渡す側
@MainActor
public protocol KodouRowsSource: AnyObject {
    var rowCount: Int { get }
    func cells(_ row: Int) -> [KodouCell]
}

/// 何万行でも軽い一覧。NSTableView を使い、行は部品を持たずに文字を直接描く。
/// - 見えている行だけが描かれ、変わった行だけを描き直す（reload(rows:)）
/// - 選んだ行は反転表示。↑↓・PageUp/Down・Home/End は NSTableView のキー操作
/// - VoiceOver には行の位置と行の数を NSTableView が伝え、行の中身は欄をつないだ文で読む
@MainActor
public final class KodouRowsController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    public let scrollView = NSScrollView()
    public let table = KodouTableView()
    public weak var source: KodouRowsSource? { didSet { table.reloadData() } }
    public var columns: [KodouColumn]
    public var font: NSFont { get { text.font } set { text.font = newValue } }
    let text: KodouLineCache
    public var onSelect: ((Int) -> Void)?
    /// 行を押したとき（選択の変化とは別。プログラムで選んだときは呼ばれない）
    public var onClick: ((Int) -> Void)? { didSet { table.target = self; table.action = #selector(clicked) } }
    /// Space で複数を選べるようにする（リスト）。選んだ行は薄い青の面、j / k でも動ける
    public var allowsPicking = false
    /// Space で選んだ行の番号。行の部品ではなくデータの側に持つ
    public private(set) var picked = Set<Int>()
    public var onPick: ((Set<Int>) -> Void)?
    /// 末尾を追いかける（ログ）。利用者が上へ戻すと止まり、末尾まで戻すとまた追いかける
    public var followsTail = false
    public private(set) var following = true
    private var charWidth: CGFloat { text.charWidth }
    private var programmaticScroll = false

    public init(columns: [KodouColumn], rowHeight: CGFloat = 24, font: NSFont = KodouFont.mono(13), label: String) {
        self.columns = columns; text = KodouLineCache(font: font)
        super.init()
        let col = NSTableColumn(identifier: .init("c")); col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        table.headerView = nil
        table.rowHeight = rowHeight
        table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.gridStyleMask = []
        table.style = .plain
        table.focusRingType = .none
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.dataSource = self; table.delegate = self
        table.owner = self
        table.setAccessibilityLabel(label)
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }

    /// 欄の x 位置と幅（行の幅 w のとき）
    func frames(width w: CGFloat) -> [(CGFloat, CGFloat)] {
        let pad: CGFloat = 6, gap = charWidth
        let fixed = columns.reduce(CGFloat(0)) { s, c in if case .ch(let n) = c.width { return s + CGFloat(n) * charWidth } else { return s } }
        let fills = columns.filter { if case .fill = $0.width { return true } else { return false } }.count
        let rest = max(0, w - pad * 2 - fixed - gap * CGFloat(columns.count - 1)) / CGFloat(max(1, fills))
        var x = pad, out: [(CGFloat, CGFloat)] = []
        for c in columns {
            let cw: CGFloat
            switch c.width { case .ch(let n): cw = CGFloat(n) * charWidth; case .fill: cw = rest }
            out.append((x, cw)); x += cw + gap
        }
        return out
    }

    // MARK: 更新

    /// 行の数が変わったとき
    public func reloadAll() {
        table.reloadData()
        if followsTail && following { scrollToEnd() }
    }
    /// 行の数は同じで、中身だけ変わったとき。見えていない行は何もしない
    public func reload(rows: IndexSet) {
        let vis = table.rows(in: table.visibleRect)
        for r in rows where r >= vis.location && r < vis.location + vis.length {
            table.rowView(atRow: r, makeIfNecessary: false)?.needsDisplay = true
        }
    }
    /// 見えている行を全部描き直す（ログが 1 行ずれたとき）
    public func reloadVisible() {
        table.enumerateAvailableRowViews { v, _ in v.needsDisplay = true }
    }
    /// 行の数が増えたとき（末尾に足した）
    public func rowsAppended() {
        table.noteNumberOfRowsChanged()
        if followsTail && following { scrollToEnd() }
    }
    /// 先頭から r 行を消し、末尾に a 行を足した（リングバッファが上限で回ったとき）。残る行は描き直さない
    public func shift(removedFromTop r: Int, appended a: Int) {
        let n = table.numberOfRows
        table.beginUpdates()
        if r > 0 { table.removeRows(at: IndexSet(0..<min(r, n)), withAnimation: []) }
        if a > 0 { let m = n - min(r, n); table.insertRows(at: IndexSet(m..<(m + a)), withAnimation: []) }
        table.endUpdates()
        if followsTail && following { scrollToEnd() }
    }
    func togglePick(_ row: Int) {
        guard allowsPicking, row >= 0 else { return }
        if picked.contains(row) { picked.remove(row) } else { picked.insert(row) }
        reload(rows: [row])
        onPick?(picked)
        kodouAnnounce(picked.contains(row) ? "選びました。\(picked.count) 件" : "外しました。\(picked.count) 件")
    }
    public func select(_ row: Int) {
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }
    public func scrollToEnd() {
        let n = table.numberOfRows; guard n > 0 else { return }
        programmaticScroll = true; table.scrollRowToVisible(n - 1); programmaticScroll = false
    }

    @objc private func clicked() { if table.clickedRow >= 0 { onClick?(table.clickedRow) } }

    @objc private func scrolled() {
        guard followsTail, !programmaticScroll else { return }
        let clip = scrollView.contentView
        following = clip.bounds.maxY >= table.frame.height - 8
    }

    // MARK: NSTableView

    public func numberOfRows(in tableView: NSTableView) -> Int { source?.rowCount ?? 0 }
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { nil }
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let v = (tableView.makeView(withIdentifier: KodouRowView.id, owner: nil) as? KodouRowView) ?? KodouRowView()
        v.identifier = KodouRowView.id
        v.controller = self
        return v
    }
    public func tableViewSelectionDidChange(_ notification: Notification) {
        if table.selectedRow >= 0 { onSelect?(table.selectedRow) }
    }
}

/// 選んだ行をキーで動かせる NSTableView。最初のクリックでフォーカスを取る。j / k で上下、Space で複数を選ぶ
public final class KodouTableView: NSTableView {
    weak var owner: KodouRowsController?
    public override var acceptsFirstResponder: Bool { true }
    public override func drawFocusRingMask() {}
    public override func keyDown(with e: NSEvent) {
        guard let o = owner, o.allowsPicking, let c = e.charactersIgnoringModifiers, e.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return super.keyDown(with: e) }
        switch c {
        case "j": o.select(min(numberOfRows - 1, selectedRow + 1))
        case "k": o.select(max(0, selectedRow - 1))
        case " ": o.togglePick(selectedRow)
        default: super.keyDown(with: e)
        }
    }
}

/// 行。部品を持たず、欄の文字を直接描く
final class KodouRowView: NSTableRowView {
    static let id = NSUserInterfaceItemIdentifier("kodou-row")
    weak var controller: KodouRowsController?
    private var row: Int { (superview as? NSTableView)?.row(for: self) ?? -1 }

    override var isOpaque: Bool { false }
    override func drawSelection(in dirtyRect: NSRect) {
        KodouColor.selBg.setFill(); bounds.fill()
    }
    override func drawBackground(in dirtyRect: NSRect) {
        if let c = controller, c.picked.contains(row), !isSelected { KodouColor.blueBg.setFill(); bounds.fill() }
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let c = controller, let src = c.source, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let r = row; guard r >= 0, r < src.rowCount else { return }
        let cells = src.cells(r), frames = c.frames(width: bounds.width), sel = isSelected, ap = effectiveAppearance
        for (i, cell) in cells.enumerated() where i < frames.count {
            let (x, w) = frames[i]
            c.text.draw(cell.text, sel ? KodouColor.selFg : (cell.color ?? KodouColor.fg), in: CGRect(x: x, y: 0, width: w, height: bounds.height),
                        bold: cell.bold, mark: cell.mark, markColor: sel ? nil : KodouColor.green, appearance: ap, ctx: ctx)
        }
    }
    override var isFlipped: Bool { true }

    // VoiceOver: 行の中身を欄をつないで読む（位置と数は NSTableView が伝える）
    override func accessibilityLabel() -> String? {
        guard let src = controller?.source, row >= 0, row < src.rowCount else { return nil }
        let t = src.cells(row).map(\.text).filter { !$0.isEmpty }.joined(separator: "、")
        return controller?.picked.contains(row) == true ? t + "、選択済み" : t
    }
}

/// SwiftUI に置く口
public struct KodouRows: NSViewRepresentable {
    let controller: KodouRowsController
    public init(_ controller: KodouRowsController) { self.controller = controller }
    public func makeNSView(context: Context) -> NSScrollView { controller.scrollView }
    public func updateNSView(_ nsView: NSScrollView, context: Context) {}
}
