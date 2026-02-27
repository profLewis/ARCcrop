import SwiftUI

struct CropMapLegendView: View {
    let legendData: CropMapLegendData
    var sourceID: String? = nil
    var year: Int? = nil
    @Environment(AppSettings.self) private var settings
    @State private var isExpanded = true
    @State private var editingEntry: LegendEntry?

    /// Override key prefix for this source
    private var sourcePrefix: String { (sourceID ?? settings.focusedCropMap.id) + "|" }

    private var titleText: String {
        if let y = year, y > 0 {
            return "\(legendData.title) (\(y))"
        }
        return legendData.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title bar: tap to collapse, long-press to toggle all classes
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2.bold())
                Text(titleText)
                    .font(.caption.bold())
            }
            .frame(minHeight: 32)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            .onLongPressGesture {
                let allLabels = Set(legendData.entries.map(\.label))
                if settings.hiddenClasses.isSuperset(of: allLabels) {
                    settings.hiddenClasses.subtract(allLabels)
                } else {
                    settings.hiddenClasses.formUnion(allLabels)
                }
            }

            if isExpanded {
                let columns = legendData.entries.count > 12 ? 2 : 1
                let rowHeight: CGFloat = 24
                let rows = columns == 1 ? legendData.entries.count : (legendData.entries.count + 1) / 2
                let contentHeight = CGFloat(rows) * rowHeight
                let needsScroll = contentHeight > 320

                if needsScroll {
                    ScrollView(.vertical, showsIndicators: true) {
                        legendGrid(columns: columns)
                    }
                    .frame(height: 320)
                } else {
                    legendGrid(columns: columns)
                }
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .fixedSize(horizontal: true, vertical: false)
        .sheet(item: $editingEntry) { entry in
            LegendEntryEditor(
                entry: entry,
                sourcePrefix: sourcePrefix,
                onSave: { newLabel, newColor in
                    let key = sourcePrefix + entry.label
                    let hex = newColor.hexString
                    settings.legendOverrides[key] = (label: newLabel, hex: hex)
                },
                onReset: {
                    settings.legendOverrides.removeValue(forKey: sourcePrefix + entry.label)
                }
            )
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func legendGrid(columns: Int) -> some View {
        if columns == 1 {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(legendData.entries) { entry in
                    legendRow(entry)
                }
            }
        } else {
            let half = (legendData.entries.count + 1) / 2
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(legendData.entries.prefix(half)) { entry in
                        legendRow(entry)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(legendData.entries.suffix(from: half)) { entry in
                        legendRow(entry)
                    }
                }
            }
        }
    }

    /// Display label for an entry, applying any override
    private func displayLabel(for entry: LegendEntry) -> String {
        let key = sourcePrefix + entry.label
        return settings.legendOverrides[key]?.label ?? entry.label
    }

    /// Display color for an entry, applying any override
    private func displayColor(for entry: LegendEntry) -> Color {
        let key = sourcePrefix + entry.label
        guard let hex = settings.legendOverrides[key]?.hex else { return entry.color }
        return Color(hex: hex) ?? entry.color
    }

    @ViewBuilder
    private func legendRow(_ entry: LegendEntry) -> some View {
        let isHidden = settings.hiddenClasses.contains(entry.label)
        let color = displayColor(for: entry)
        let label = displayLabel(for: entry)
        Button {
            if isHidden {
                settings.hiddenClasses.remove(entry.label)
            } else {
                settings.hiddenClasses.insert(entry.label)
            }
        } label: {
            HStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isHidden ? Color.clear : color)
                        .frame(width: 12, height: 12)
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(isHidden ? .secondary : color, lineWidth: 0.5)
                        .frame(width: 12, height: 12)
                    if isHidden {
                        Path { path in
                            path.move(to: CGPoint(x: 1, y: 1))
                            path.addLine(to: CGPoint(x: 11, y: 11))
                            path.move(to: CGPoint(x: 11, y: 1))
                            path.addLine(to: CGPoint(x: 1, y: 11))
                        }
                        .stroke(.secondary, lineWidth: 1)
                        .frame(width: 12, height: 12)
                    }
                }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isHidden ? .secondary : .primary)
                    .lineLimit(1)
            }
            .frame(minHeight: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 3.0)
                .onEnded { _ in editingEntry = entry }
        )
    }
}

// MARK: - Multi-legend container (tabs + drag to reorder + move whole panel)

struct MultiLegendView: View {
    @Environment(AppSettings.self) private var settings
    @State private var panelOffset: CGSize = .zero
    @State private var panelSaved: CGSize = .zero
    @State private var draggingID: String?

    /// Show legends for all active sources that have legend data
    private var visibleLegends: [(source: CropMapSource, data: CropMapLegendData)] {
        settings.activeCropMaps.compactMap { source in
            guard let data = CropMapLegendData.forSource(source) else { return nil }
            return (source, data)
        }
    }

    var body: some View {
        if !visibleLegends.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Tab bar — tap to focus, drag to reorder layers
                if visibleLegends.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(visibleLegends, id: \.source.id) { item in
                                legendTab(item.source)
                                    .opacity(draggingID == item.source.id ? 0.4 : 1.0)
                                    .onDrag {
                                        draggingID = item.source.id
                                        return NSItemProvider(object: item.source.id as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: TabDropDelegate(
                                        targetID: item.source.id,
                                        settings: settings,
                                        draggingID: $draggingID
                                    ))
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    }
                }

                // Show the focused legend (or the first/only one)
                let focusedID = settings.focusedCropMap.id
                if let item = visibleLegends.first(where: { $0.source.id == focusedID }) ?? visibleLegends.first {
                    let yr = item.source.availableYears != nil ? item.source.currentYear : nil
                    CropMapLegendView(legendData: item.data, sourceID: item.source.id, year: yr)
                }
            }
            .offset(x: panelOffset.width + panelSaved.width,
                    y: panelOffset.height + panelSaved.height)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { panelOffset = $0.translation }
                    .onEnded { value in
                        panelSaved = CGSize(
                            width: panelSaved.width + value.translation.width,
                            height: panelSaved.height + value.translation.height
                        )
                        panelOffset = .zero
                    }
            )
        }
    }

    private func legendTab(_ source: CropMapSource) -> some View {
        let isFocused = source.id == settings.focusedCropMap.id
        let year = source.currentYear
        let showYear = (source.availableYears != nil && year > 0)
        let label = showYear ? "\(source.sourceName) \(year)" : source.sourceName
        return Button {
            if let idx = settings.activeCropMaps.firstIndex(where: { $0.id == source.id }) {
                settings.focusedLayerIndex = idx
            }
        } label: {
            Text(label)
                .font(.system(size: 9, weight: isFocused ? .bold : .regular))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isFocused ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

/// Drop delegate for reordering legend tabs via drag-and-drop
struct TabDropDelegate: DropDelegate {
    let targetID: String
    let settings: AppSettings
    @Binding var draggingID: String?

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragID = draggingID, dragID != targetID else { return }
        guard let fromIdx = settings.activeCropMaps.firstIndex(where: { $0.id == dragID }),
              let toIdx = settings.activeCropMaps.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.activeCropMaps.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
            // Keep focus on the dragged item
            if let newIdx = settings.activeCropMaps.firstIndex(where: { $0.id == dragID }) {
                settings.focusedLayerIndex = newIdx
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Legend entry editor sheet

struct LegendEntryEditor: View {
    let entry: LegendEntry
    let sourcePrefix: String
    let onSave: (String, Color) -> Void
    let onReset: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var editLabel: String = ""
    @State private var editColor: Color = .gray

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("Class name", text: $editLabel)
                }
                Section("Colour") {
                    ColorPicker("Tile colour to match", selection: $editColor, supportsOpacity: false)
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(entry.color)
                            .frame(width: 40, height: 40)
                            .overlay(Text("Old").font(.caption2).foregroundStyle(.white))
                        Image(systemName: "arrow.right")
                        RoundedRectangle(cornerRadius: 6)
                            .fill(editColor)
                            .frame(width: 40, height: 40)
                            .overlay(Text("New").font(.caption2).foregroundStyle(.white))
                    }
                }
                Section {
                    Button("Reset to Default", role: .destructive) {
                        onReset()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Legend Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editLabel, editColor)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            let key = sourcePrefix + entry.label
            if let override = settings.legendOverrides[key] {
                editLabel = override.label
                editColor = Color(hex: override.hex) ?? entry.color
            } else {
                editLabel = entry.label
                editColor = entry.color
            }
        }
    }
}

// MARK: - Color hex helpers

extension Color {
    /// Initialise from a hex string like "#FF8800" or "FF8800"
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard cleaned.count == 6, let rgb = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }

    /// Convert to hex string like "FF8800"
    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
