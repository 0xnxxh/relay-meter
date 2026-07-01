import AppKit

final class RankingMenuCardView: RoundedPanelView {
    init(snapshot: UsageSnapshot, enabled: Set<DisplayItem>, texts: TextBundle) {
        super.init(accentColor: RelayTheme.line, fillAlpha: 0.92)
        build(snapshot: snapshot, enabled: enabled, texts: texts)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func build(snapshot: UsageSnapshot, enabled: Set<DisplayItem>, texts: TextBundle) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        stack.addArrangedSubview(menuIconTitle(cardTitle(enabled: enabled, texts: texts), accent: RelayTheme.cyan))
        let content = NSStackView()
        content.orientation = .horizontal
        content.alignment = .top
        content.distribution = enabled.contains(.topModel) && enabled.contains(.topApiKey) ? .fillEqually : .fill
        content.spacing = 12

        if enabled.contains(.topModel) {
            content.addArrangedSubview(rankingColumn(title: texts.topModel, rows: snapshot.topModels))
        }
        if enabled.contains(.topApiKey) {
            content.addArrangedSubview(rankingColumn(title: texts.topApiKey, rows: snapshot.topApiKeys))
        }
        stack.addArrangedSubview(content)
    }

    private func cardTitle(enabled: Set<DisplayItem>, texts: TextBundle) -> String {
        let titles = [
            enabled.contains(.topModel) ? texts.topModel : nil,
            enabled.contains(.topApiKey) ? texts.topApiKey : nil
        ].compactMap { $0 }
        return titles.joined(separator: " / ")
    }

    private func rankingColumn(title: String, rows: [UsageRankingRow]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.addArrangedSubview(menuLabel(title.uppercased(), size: 10, weight: .bold, color: RelayTheme.muted))

        guard !rows.isEmpty else {
            stack.addArrangedSubview(menuLabel("--", size: 11, weight: .bold, color: RelayTheme.muted))
            return stack
        }

        for (index, row) in rows.prefix(3).enumerated() {
            let item = NSStackView()
            item.orientation = .vertical
            item.alignment = .leading
            item.spacing = 1

            let nameRow = NSStackView()
            nameRow.orientation = .horizontal
            nameRow.alignment = .firstBaseline
            nameRow.spacing = 5
            nameRow.addArrangedSubview(menuLabel("#\(index + 1)", size: 10, weight: .bold, color: RelayTheme.accent))
            let name = menuLabel(row.label, size: 12, weight: .bold, color: RelayTheme.text)
            name.lineBreakMode = .byTruncatingMiddle
            nameRow.addArrangedSubview(name)
            item.addArrangedSubview(nameRow)
            item.addArrangedSubview(menuLabel("\(MenuValueFormatter.number(row.requests)) REQ / \(MenuValueFormatter.percent(row.successRate))", size: 10, weight: .bold, color: RelayTheme.muted))
            stack.addArrangedSubview(item)
        }
        return stack
    }
}
