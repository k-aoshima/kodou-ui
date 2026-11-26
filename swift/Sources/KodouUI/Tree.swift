import AppKit
import SwiftUI

/// ツリーの 1 つの節
@MainActor
public final class KodouTreeNode {
    public let name: String
    /// 文字の印（変更のあるファイルの M、A など）。色だけで伝えない
    public let mark: String?
    public let children: [KodouTreeNode]
    public weak private(set) var parent: KodouTreeNode?
    public init(_ name: String, mark: String? = nil, children: [KodouTreeNode] = []) {
        self.name = name; self.mark = mark; self.children = children
        for c in children { c.parent = self }
    }
    var isFolder: Bool { !children.isEmpty }
    var isLast: Bool { parent.map { $0.children.last === self } ?? true }
}

/// 罫線でつながりを見せるツリー。NSOutlineView を使う。
/// - ← で閉じる・親へ、→ で開く・子へ、↑↓ で動く（NSOutlineView のキー操作）
/// - 開いている分だけが行になり、見えている行だけを描く
/// - VoiceOver には、階層の深さ・兄弟の中での位置と数・開閉を NSOutlineView が伝える
@MainActor
public final class KodouTreeController: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    public let scrollView = NSScrollView()
    public let outline = KodouOutlineView()
    public var roots: [KodouTreeNode] { didSet { outline.reloadData() } }
    public var onSelect: ((KodouTreeNode) -> Void)?
    let text: KodouLineCache

    public init(roots: [KodouTreeNode], rowHeight: CGFloat = 24, font: NSFont = KodouFont.mono(13), label: String) {
        self.roots = roots; text = KodouLineCache(font: font)
        super.init()
        let col = NSTableColumn(identifier: .init("c")); col.resizingMask = .autoresizingMask
        outline.addTableColumn(col); outline.outlineTableColumn = col
        outline.headerView = nil
        outline.rowHeight = rowHeight
        outline.indentationPerLevel = 0     // 字下げは罫線の文字で描く
        outline.intercellSpacing = .zero
        outline.backgroundColor = .clear
        outline.style = .plain
        outline.focusRingType = .none
        outline.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outline.dataSource = self; outline.delegate = self
        outline.setAccessibilityLabel(label)
        scrollView.documentView = outline
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
    }

    public func expandAll() { outline.expandItem(nil, expandChildren: true) }

    /// 行の頭に置く罫線（│ ├─ └─）と開閉の印（▸ ▾）
    func prefix(_ n: KodouTreeNode) -> String {
        var parts: [String] = []
        var p = n.parent
        while let q = p, q.parent != nil { parts.insert(q.isLast ? "   " : "│  ", at: 0); p = q.parent }
        let branch = n.parent == nil ? "" : (n.isLast ? "└─ " : "├─ ")
        let open = n.isFolder ? (outline.isItemExpanded(n) ? "▾ " : "▸ ") : "  "
        return parts.joined() + branch + open
    }

    public func outlineView(_ o: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int { (item as? KodouTreeNode)?.children.count ?? roots.count }
    public func outlineView(_ o: NSOutlineView, child index: Int, ofItem item: Any?) -> Any { (item as? KodouTreeNode)?.children[index] ?? roots[index] }
    public func outlineView(_ o: NSOutlineView, isItemExpandable item: Any) -> Bool { (item as? KodouTreeNode)?.isFolder ?? false }
    public func outlineView(_ o: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? { nil }
    public func outlineView(_ o: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let v = (o.makeView(withIdentifier: KodouTreeRowView.id, owner: nil) as? KodouTreeRowView) ?? KodouTreeRowView()
        v.identifier = KodouTreeRowView.id; v.controller = self
        return v
    }
    public func outlineViewItemDidExpand(_ n: Notification) { redrawPrefixes() }
    public func outlineViewItemDidCollapse(_ n: Notification) { redrawPrefixes() }
    private func redrawPrefixes() { outline.enumerateAvailableRowViews { v, _ in v.needsDisplay = true } }
    public func outlineViewSelectionDidChange(_ notification: Notification) {
        if let n = outline.item(atRow: outline.selectedRow) as? KodouTreeNode { onSelect?(n) }
    }
}

/// 開閉の三角は出さない（罫線の ▸ ▾ で見せる）。キー操作と VoiceOver の開閉はそのまま
public final class KodouOutlineView: NSOutlineView {
    public override func frameOfOutlineCell(atRow row: Int) -> NSRect { .zero }
    public override var acceptsFirstResponder: Bool { true }
    public override func drawFocusRingMask() {}
}

final class KodouTreeRowView: NSTableRowView {
    static let id = NSUserInterfaceItemIdentifier("kodou-tree-row")
    weak var controller: KodouTreeController?
    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }
    override func drawSelection(in dirtyRect: NSRect) { KodouColor.selBg.setFill(); bounds.fill() }
    override func drawBackground(in dirtyRect: NSRect) {}
    private var node: KodouTreeNode? {
        guard let o = superview as? NSOutlineView else { return nil }
        let r = o.row(for: self); return r >= 0 ? o.item(atRow: r) as? KodouTreeNode : nil
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let c = controller, let n = node, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let sel = isSelected, ap = effectiveAppearance, t = c.text
        let pre = c.prefix(n)
        var x: CGFloat = 6
        let pw = CGFloat(pre.count) * t.charWidth
        t.draw(pre, sel ? KodouColor.selFg : KodouColor.deco, in: CGRect(x: x, y: 0, width: pw, height: bounds.height), appearance: ap, ctx: ctx)
        x += pw
        if let m = n.mark {
            let color = m == "A" ? KodouColor.green : m == "D" ? KodouColor.red : KodouColor.yellow
            t.draw(m, sel ? KodouColor.selFg : color, in: CGRect(x: x, y: 0, width: t.charWidth * 2, height: bounds.height), bold: true, appearance: ap, ctx: ctx)
            x += t.charWidth * 2
        }
        t.draw(n.name + (n.isFolder ? "/" : ""), sel ? KodouColor.selFg : KodouColor.fg, in: CGRect(x: x, y: 0, width: bounds.width - x - 6, height: bounds.height), appearance: ap, ctx: ctx)
    }
    override func accessibilityLabel() -> String? {
        guard let n = node else { return nil }
        let kind = n.isFolder ? "フォルダ" : "ファイル"
        let mark = n.mark.map { ["M": "変更あり", "A": "追加", "D": "削除"][$0] ?? $0 }
        return [n.name, kind, mark].compactMap { $0 }.joined(separator: "、")
    }
}

/// SwiftUI に置く口
public struct KodouTree: NSViewRepresentable {
    let controller: KodouTreeController
    public init(_ controller: KodouTreeController) { self.controller = controller }
    public func makeNSView(context: Context) -> NSScrollView { controller.scrollView }
    public func updateNSView(_ nsView: NSScrollView, context: Context) {}
}
