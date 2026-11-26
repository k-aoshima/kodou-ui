import AppKit
import SwiftUI

/// 表の列
public struct KodouTableColumn {
    public let id: String
    public let title: String
    /// 幅（等幅の文字数）。nil は残りを使う
    public let ch: Int?
    /// 数字の列は右にそろえて桁を合わせる
    public let numeric: Bool
    public let sortable: Bool
    public init(_ id: String, _ title: String, ch: Int? = nil, numeric: Bool = false, sortable: Bool = true) {
        self.id = id; self.title = title; self.ch = ch; self.numeric = numeric; self.sortable = sortable
    }
}

/// 表の中身を渡す側。並べ替えは、渡す側が行の並び（番号の並び）を並べ直すだけにする
@MainActor
public protocol KodouTableSource: AnyObject {
    var rowCount: Int { get }
    func cell(_ row: Int, _ column: String) -> KodouCell
    func sort(by column: String, ascending: Bool)
}

/// 列と並べ替えのある表。NSTableView で見えている行だけを描き、行は部品を持たずに文字を直接描く。
/// - 見出しを押すと並べ替える（もう一度押すと逆順）。見出しは上に残る
/// - 数字の列は右にそろえる。選んだ行は反転
/// - VoiceOver には行と列の位置を NSTableView が伝える
@MainActor
public final class KodouTableController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    public let scrollView = NSScrollView()
    public let table = KodouTableView()
    public weak var source: KodouTableSource? { didSet { table.reloadData() } }
    public let columns: [KodouTableColumn]
    public var onSelect: ((Int) -> Void)?
    let text: KodouLineCache

    public init(columns: [KodouTableColumn], rowHeight: CGFloat = 24, font: NSFont = KodouFont.mono(13), label: String) {
        // 行の下の薄い罫線は KodouTableRowView が描く
        self.columns = columns; text = KodouLineCache(font: font)
        super.init()
        for c in columns {
            let col = NSTableColumn(identifier: .init(c.id))
            col.title = c.title
            col.headerCell = KodouHeaderCell(textCell: c.title)
            col.headerCell.alignment = c.numeric ? .right : .left
            if let ch = c.ch { col.width = CGFloat(ch) * text.charWidth + 16; col.minWidth = col.width / 2 }
            col.resizingMask = c.ch == nil ? .autoresizingMask : .userResizingMask
            if c.sortable { col.sortDescriptorPrototype = NSSortDescriptor(key: c.id, ascending: true) }
            table.addTableColumn(col)
        }
        table.rowHeight = rowHeight
        table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.gridStyleMask = []
        table.style = .plain
        table.focusRingType = .none
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.headerView = KodouHeaderView(frame: NSRect(x: 0, y: 0, width: 0, height: rowHeight))
        table.dataSource = self; table.delegate = self
        table.setAccessibilityLabel(label)
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
    }

    /// 行の中身だけが変わった（見えていない行は何もしない）
    public func reload(rows: IndexSet) {
        let vis = table.rows(in: table.visibleRect)
        for r in rows where r >= vis.location && r < vis.location + vis.length { table.rowView(atRow: r, makeIfNecessary: false)?.needsDisplay = true }
    }
    public func reloadAll() { table.reloadData() }
    public func select(_ row: Int) { table.selectRowIndexes([row], byExtendingSelection: false); table.scrollRowToVisible(row) }

    public func numberOfRows(in tableView: NSTableView) -> Int { source?.rowCount ?? 0 }
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { nil }
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let v = (tableView.makeView(withIdentifier: KodouTableRowView.id, owner: nil) as? KodouTableRowView) ?? KodouTableRowView()
        v.identifier = KodouTableRowView.id; v.controller = self
        return v
    }
    public func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let d = tableView.sortDescriptors.first, let key = d.key else { return }
        let sel = tableView.selectedRow
        source?.sort(by: key, ascending: d.ascending)
        tableView.reloadData()   // 行の部品は作り直さず、見えている行を描き直すだけ
        if sel >= 0 { tableView.scrollRowToVisible(tableView.selectedRow) }
        tableView.headerView?.needsDisplay = true
    }
    public func tableViewSelectionDidChange(_ notification: Notification) {
        if table.selectedRow >= 0 { onSelect?(table.selectedRow) }
    }
}

final class KodouTableRowView: NSTableRowView {
    static let id = NSUserInterfaceItemIdentifier("kodou-table-row")
    weak var controller: KodouTableController?
    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }
    override func drawSelection(in dirtyRect: NSRect) { KodouColor.selBg.setFill(); bounds.fill() }
    override func drawBackground(in dirtyRect: NSRect) {}
    private var row: Int { (superview as? NSTableView)?.row(for: self) ?? -1 }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if !isSelected { KodouColor.ruleSoft.setFill(); NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill() }
        guard let c = controller, let src = c.source, let tv = superview as? NSTableView, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let r = row; guard r >= 0, r < src.rowCount else { return }
        let sel = isSelected, ap = effectiveAppearance
        for (i, col) in c.columns.enumerated() {
            let cr = tv.rect(ofColumn: i).insetBy(dx: 8, dy: 0)
            let cell = src.cell(r, col.id)
            c.text.draw(cell.text, sel ? KodouColor.selFg : (cell.color ?? KodouColor.fg), in: CGRect(x: cr.minX, y: 0, width: cr.width, height: bounds.height),
                        align: col.numeric ? .right : .left, appearance: ap, ctx: ctx)
        }
    }
    override func accessibilityLabel() -> String? {
        guard let c = controller, let src = c.source, row >= 0, row < src.rowCount else { return nil }
        return c.columns.map { "\($0.title) \(src.cell(row, $0.id).text)" }.joined(separator: "、")
    }
}

/// 見出し。反転（sel-bg の面に sel-fg の太字）。並べ替えの向きは ▲▼ の文字で出す（色だけで伝えない）
final class KodouHeaderView: NSTableHeaderView {
    override func draw(_ dirtyRect: NSRect) {
        // 系の見出しの地を描かせず、反転の地と各列の見出しだけを描く
        KodouColor.selBg.setFill(); bounds.fill()
        guard let tv = tableView else { return }
        for i in tv.tableColumns.indices { tv.tableColumns[i].headerCell.draw(withFrame: headerRect(ofColumn: i), in: self) }
    }
}

final class KodouHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        var title = stringValue
        if let tv = (controlView as? NSTableHeaderView)?.tableView, let col = tv.tableColumns.first(where: { $0.headerCell === self }), col.sortDescriptorPrototype != nil {
            if let d = tv.sortDescriptors.first, d.key == col.identifier.rawValue { title += d.ascending ? " ▲" : " ▼" } else { title += " ↕" }
        }
        let p = NSMutableParagraphStyle(); p.alignment = alignment; p.lineBreakMode = .byTruncatingTail
        let f = KodouFont.mono(13, weight: .bold)
        let r = cellFrame.insetBy(dx: 8, dy: 0)
        let h = f.ascender - f.descender
        (title as NSString).draw(in: NSRect(x: r.minX, y: r.midY - h / 2, width: r.width, height: h),
                                 withAttributes: [.font: f, .foregroundColor: KodouColor.selFg, .paragraphStyle: p])
    }
    override func drawSortIndicator(withFrame cellFrame: NSRect, in controlView: NSView, ascending: Bool, priority: Int) {}
}

/// SwiftUI に置く口
public struct KodouTable: NSViewRepresentable {
    let controller: KodouTableController
    public init(_ controller: KodouTableController) { self.controller = controller }
    public func makeNSView(context: Context) -> NSScrollView { controller.scrollView }
    public func updateNSView(_ nsView: NSScrollView, context: Context) {}
}
