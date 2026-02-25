import SwiftUI

struct CropMapLegendView: View {
    let legendData: CropMapLegendData
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(legendData.title)
                .font(.caption.bold())
            ForEach(legendData.entries) { entry in
                let isHidden = settings.hiddenClasses.contains(entry.label)
                Button {
                    if isHidden {
                        settings.hiddenClasses.remove(entry.label)
                    } else {
                        settings.hiddenClasses.insert(entry.label)
                    }
                } label: {
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isHidden ? Color.clear : entry.color)
                                .frame(width: 14, height: 14)
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(isHidden ? .secondary : entry.color, lineWidth: 0.5)
                                .frame(width: 14, height: 14)
                            if isHidden {
                                // X mark for hidden classes
                                Path { path in
                                    path.move(to: CGPoint(x: 2, y: 2))
                                    path.addLine(to: CGPoint(x: 12, y: 12))
                                    path.move(to: CGPoint(x: 12, y: 2))
                                    path.addLine(to: CGPoint(x: 2, y: 12))
                                }
                                .stroke(.secondary, lineWidth: 1)
                                .frame(width: 14, height: 14)
                            }
                        }
                        Text(entry.label)
                            .font(.caption2)
                            .foregroundStyle(isHidden ? .secondary : .primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
