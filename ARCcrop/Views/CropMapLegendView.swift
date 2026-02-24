import SwiftUI

struct CropMapLegendView: View {
    let legendData: CropMapLegendData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(legendData.title)
                .font(.caption.bold())
            ForEach(legendData.entries) { entry in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(entry.color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(.secondary, lineWidth: 0.5)
                        )
                    Text(entry.label)
                        .font(.caption2)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
