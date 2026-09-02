import SpriteKit

/// Swallows touches so panels behave like modal sheets.
private final class TouchBlocker: SKSpriteNode {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
}

/// Shared chrome for the full-screen panels: dimmer, torn-paper sheet, title,
/// a close button and a simple paged list.
class PanelOverlay: SKNode {

    let panelSize: CGSize
    private let onClose: () -> Void
    private let titleLabel: SKLabelNode
    private let contentNode = SKNode()
    private let footerNode = SKNode()

    private var rows: [RowSpec] = []
    private var page = 0
    private let rowHeight: CGFloat = 54

    /// Proportions of the generated `ui/menu_panel` artwork: its width over its
    /// height, and how far in from each edge the drawn border stops. Anything
    /// inside that inset is guaranteed to be blank paper.
    private static let panelAspect: CGFloat = 0.659
    private static let panelInset: CGFloat = 0.09
    /// How much taller than its natural shape the panel may be pulled. A wobbly
    /// ink rectangle survives a nudge; it does not survive being squashed into a
    /// completely different shape.
    private static let maxStretch: CGFloat = 1.3

    /// Vertical bands reserved above and below the scrolling list.
    private let titleBand: CGFloat = 46
    private let closeBand: CGFloat = 54
    private let pagerBand: CGFloat = 48
    private var hasTabs = false
    private var tabBand: CGFloat { hasTabs ? 58 : 10 }

    /// Blank paper the list may draw on.
    private var contentTop: CGFloat { panelSize.height / 2 - inset.height - titleBand - tabBand }
    private var contentBottom: CGFloat { -panelSize.height / 2 + inset.height + closeBand + pagerBand }
    private var contentWidth: CGFloat { panelSize.width - inset.width * 2 - 16 }
    private var inset: CGSize {
        CGSize(width: panelSize.width * PanelOverlay.panelInset,
               height: panelSize.height * PanelOverlay.panelInset)
    }
    private var rowsPerPage: Int {
        max(1, Int((contentTop - contentBottom) / rowHeight))
    }

    /// One line of a list: a label, an optional right-hand value, and an action.
    struct RowSpec {
        var title: String
        var detail: String = ""
        var enabled: Bool = true
        var action: (() -> Void)?
    }

    init(size sceneSize: CGSize, title: String, onClose: @escaping () -> Void) {
        let maxWidth = min(sceneSize.width - 40, 560)
        let maxHeight = min(sceneSize.height - 110, 900)
        var width = maxWidth
        var height = width / PanelOverlay.panelAspect
        if height > maxHeight {
            // Too tall for this screen: shrink, but keep the drawing's shape.
            height = maxHeight
            width = min(width, height * PanelOverlay.panelAspect)
        } else {
            // Room to spare: use it, within what the artwork tolerates.
            height = min(maxHeight, height * PanelOverlay.maxStretch)
        }
        self.panelSize = CGSize(width: width, height: height)
        self.onClose = onClose
        self.titleLabel = Paper.label(title, size: 28)
        super.init()

        let dimmer = TouchBlocker(color: UIColor(white: 0.1, alpha: 0.35), size: sceneSize)
        dimmer.isUserInteractionEnabled = true
        dimmer.zPosition = 0
        addChild(dimmer)

        let sheet = SKSpriteNode(texture: Art.texture("menu_panel", in: "ui"))
        sheet.size = panelSize
        sheet.zPosition = 1
        addChild(sheet)

        titleLabel.position = CGPoint(x: 0, y: panelSize.height / 2 - inset.height - titleBand / 2)
        titleLabel.zPosition = 3
        addChild(titleLabel)

        contentNode.zPosition = 3
        addChild(contentNode)

        footerNode.zPosition = 3
        addChild(footerNode)

        let close = PaperButton(title: "CLOSE",
                                size: CGSize(width: min(160, contentWidth), height: 50),
                                fontSize: 20) { onClose() }
        close.position = CGPoint(x: 0, y: -panelSize.height / 2 + inset.height + closeBand / 2)
        close.zPosition = 4
        addChild(close)

        setScale(0.92)
        alpha = 0
        run(.group([.fadeIn(withDuration: 0.14), .scale(to: 1.0, duration: 0.16)]))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func close() { onClose() }

    /// Replaces the header text, used by the tabbed menu.
    func setTitle(_ text: String) { titleLabel.text = text }

    /// Adds a strip of tab buttons just under the title.
    func setTabs(_ tabs: [(String, () -> Void)], selected: Int) {
        footerNode.removeAllChildren()
        hasTabs = !tabs.isEmpty
        guard !tabs.isEmpty else { return }

        let gap: CGFloat = 8
        // Tabs may use the full paper width; only the list keeps a side margin.
        let band = panelSize.width - inset.width * 2
        let available = band - gap * CGFloat(tabs.count - 1)
        let width = min(available / CGFloat(tabs.count), 170)
        let total = width * CGFloat(tabs.count) + gap * CGFloat(tabs.count - 1)
        let y = panelSize.height / 2 - inset.height - titleBand - tabBand / 2

        for (index, tab) in tabs.enumerated() {
            let button = PaperButton(title: tab.0,
                                     size: CGSize(width: width, height: 46),
                                     fontSize: 15,
                                     action: tab.1)
            button.position = CGPoint(
                x: -total / 2 + width / 2 + CGFloat(index) * (width + gap),
                y: y)
            button.alpha = index == selected ? 1.0 : 0.5
            footerNode.addChild(button)
        }

        // The list starts below the tabs, so its geometry just changed.
        renderRows()
    }

    /// Renders a list, paging automatically when it is too long to fit.
    func setRows(_ newRows: [RowSpec], resetPage: Bool = true) {
        rows = newRows
        if resetPage { page = 0 }
        renderRows()
    }

    private func renderRows() {
        contentNode.removeAllChildren()

        let perPage = rowsPerPage
        let pageCount = max(1, Int(ceil(Double(rows.count) / Double(perPage))))
        page = min(page, pageCount - 1)

        let start = page * perPage
        let slice = Array(rows.dropFirst(start).prefix(perPage))
        let topY = contentTop - rowHeight / 2

        if slice.isEmpty {
            let empty = Paper.label("Nothing here yet.", size: 20, color: Paper.softInk)
            empty.position = CGPoint(x: 0, y: topY)
            contentNode.addChild(empty)
        }

        for (index, row) in slice.enumerated() {
            let y = topY - CGFloat(index) * rowHeight
            let node = makeRow(row, width: contentWidth)
            node.position = CGPoint(x: 0, y: y)
            contentNode.addChild(node)
        }

        guard pageCount > 1 else { return }

        let pagerY = -panelSize.height / 2 + inset.height + closeBand + pagerBand / 2

        let previous = PaperButton(title: "‹", size: CGSize(width: 58, height: 44), fontSize: 24) {
            [weak self] in
            guard let self else { return }
            self.page = max(0, self.page - 1)
            self.renderRows()
        }
        previous.position = CGPoint(x: -76, y: pagerY)
        previous.setEnabled(page > 0)
        contentNode.addChild(previous)

        let indicator = Paper.label("\(page + 1)/\(pageCount)", size: 18, color: Paper.softInk)
        indicator.position = CGPoint(x: 0, y: pagerY)
        contentNode.addChild(indicator)

        let next = PaperButton(title: "›", size: CGSize(width: 58, height: 44), fontSize: 24) {
            [weak self] in
            guard let self else { return }
            self.page = min(pageCount - 1, self.page + 1)
            self.renderRows()
        }
        next.position = CGPoint(x: 76, y: pagerY)
        next.setEnabled(page < pageCount - 1)
        contentNode.addChild(next)
    }

    private func makeRow(_ row: RowSpec, width: CGFloat) -> SKNode {
        let container = SKNode()
        let buttonHeight = rowHeight - 8
        let sideInset: CGFloat = 14

        // The row is a ruled line with text on it, not a slab: the button art is
        // drawn in perspective and cannot be stretched this wide without its
        // borders running through the label.
        let button = PaperButton(title: "",
                                 size: CGSize(width: width, height: buttonHeight),
                                 fontSize: 1,
                                 showsBackground: false) {
            row.action?()
        }
        button.setEnabled(row.enabled && row.action != nil)
        container.addChild(button)

        if row.action != nil {
            let rule = Paper.rule(width: width)
            rule.position = CGPoint(x: 0, y: -buttonHeight / 2)
            rule.alpha = row.enabled ? 0.9 : 0.35
            rule.zPosition = 4
            container.addChild(rule)
        }

        let detailWidth: CGFloat = row.detail.isEmpty ? 0 : 84
        let title = Paper.label(row.title, size: 19)
        title.horizontalAlignmentMode = .left
        title.numberOfLines = 1
        title.preferredMaxLayoutWidth = width - sideInset * 2 - detailWidth
        title.lineBreakMode = .byTruncatingTail
        title.position = CGPoint(x: -width / 2 + sideInset, y: 0)
        title.zPosition = 5
        title.alpha = row.enabled ? 1.0 : 0.45
        container.addChild(title)

        if !row.detail.isEmpty {
            let detail = Paper.label(row.detail, size: 17, color: Paper.softInk)
            detail.horizontalAlignmentMode = .right
            detail.position = CGPoint(x: width / 2 - sideInset, y: 0)
            detail.zPosition = 5
            detail.alpha = row.enabled ? 1.0 : 0.45
            container.addChild(detail)
        }

        return container
    }
}

// MARK: - Bag

/// Status, items and equipment.
final class MenuOverlay: PanelOverlay {

    private enum Tab: Int, CaseIterable {
        case status, items, gear

        var title: String {
            switch self {
            case .status: return "STATUS"
            case .items: return "ITEMS"
            case .gear: return "GEAR"
            }
        }
    }

    private var tab: Tab = .status
    private let state = GameState.shared

    init(size sceneSize: CGSize, onClose: @escaping () -> Void) {
        super.init(size: sceneSize, title: "BAG", onClose: onClose)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func refresh() {
        setTitle(tab.title)
        setTabs(Tab.allCases.map { candidate in
            (candidate.title, { [weak self] in
                self?.tab = candidate
                self?.refresh()
            })
        }, selected: tab.rawValue)

        switch tab {
        case .status: setRows(statusRows())
        case .items: setRows(itemRows())
        case .gear: setRows(gearRows())
        }
    }

    private func statusRows() -> [RowSpec] {
        let stats = state.totalStats
        let nextLabel = state.level >= Progression.maxLevel
            ? "MAX"
            : "\(state.experienceIntoLevel)/\(state.experienceForNextLevel)"
        return [
            RowSpec(title: "Level", detail: "\(state.level)", action: nil),
            RowSpec(title: "Experience", detail: nextLabel, action: nil),
            RowSpec(title: "Health", detail: "\(state.currentHP)/\(stats.maxHP)", action: nil),
            RowSpec(title: "Ink", detail: "\(state.currentInk)/\(stats.maxInk)", action: nil),
            RowSpec(title: "Attack / Defense",
                    detail: "\(stats.attack) / \(stats.defense)", action: nil),
            RowSpec(title: "Speed / Luck",
                    detail: "\(stats.speed) / \(stats.luck)", action: nil),
            RowSpec(title: "Coins", detail: "\(state.coins)", action: nil),
            RowSpec(title: "Monsters erased", detail: "\(state.save.defeatedCount)", action: nil),
            RowSpec(title: "Weapon",
                    detail: state.equippedWeapon?.name ?? "none", action: nil),
            RowSpec(title: "Shield",
                    detail: state.equippedShield?.name ?? "none", action: nil)
        ]
    }

    private func itemRows() -> [RowSpec] {
        state.inventory.compactMap { slot in
            guard let item = ItemCatalog.item(id: slot.itemID) else { return nil }
            let usableOutsideBattle: Bool
            switch item.effect {
            case .restoreHP, .restoreInk, .cure: usableOutsideBattle = true
            case .keyItem: usableOutsideBattle = false
            }
            return RowSpec(title: "\(item.name) x\(slot.count)",
                           detail: usableOutsideBattle ? "use" : "key item",
                           enabled: usableOutsideBattle,
                           action: usableOutsideBattle ? { [weak self] in
                               self?.use(item)
                           } : nil)
        }
    }

    private func use(_ item: Item) {
        guard let consumed = state.consumeItem(item.id) else { return }
        switch consumed.effect {
        case .restoreHP(let amount): state.heal(amount)
        case .restoreInk(let amount): state.restoreInk(amount)
        case .cure, .keyItem: break
        }
        state.persist()
        Haptics.success()
        refresh()
    }

    private func gearRows() -> [RowSpec] {
        state.ownedEquipment.map { gear in
            let equipped = (state.save.weaponID == gear.id) || (state.save.shieldID == gear.id)
            return RowSpec(title: gear.name,
                           detail: equipped ? "equipped" : gear.summary,
                           enabled: !equipped,
                           action: equipped ? nil : { [weak self] in
                               self?.state.equip(gear.id)
                               Haptics.tap()
                               self?.refresh()
                           })
        }
    }
}

// MARK: - Shop

/// The vendor's cart. Buys are immediate and permanent, which suits a game this
/// short far better than a confirm dialog on every tap.
final class ShopOverlay: PanelOverlay {

    private let state = GameState.shared

    init(size sceneSize: CGSize, onClose: @escaping () -> Void) {
        super.init(size: sceneSize, title: "CART", onClose: onClose)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func refresh() {
        setTitle("CART   \(state.coins) coins")

        var rows: [RowSpec] = ItemCatalog.forSale.map { item in
            RowSpec(title: item.name,
                    detail: "\(item.price)c",
                    enabled: state.canAfford(item.price),
                    action: { [weak self] in
                        guard let self, self.state.buyItem(item.id) else { return }
                        Haptics.success()
                        self.refresh()
                    })
        }

        rows += EquipmentCatalog.forSale.map { gear in
            let owned = self.state.save.ownedEquipment.contains(gear.id)
            return RowSpec(title: gear.name,
                           detail: owned ? "owned" : "\(gear.price)c",
                           enabled: !owned && state.canAfford(gear.price),
                           action: owned ? nil : { [weak self] in
                               guard let self, self.state.buyEquipment(gear.id) else { return }
                               Haptics.success()
                               self.refresh()
                           })
        }

        setRows(rows, resetPage: false)
    }
}
