#if !os(tvOS)
import SwiftUI
import UIKit

struct LogView: View {
    @Binding var isPresented: Bool
    @State private var log = ActivityLog.shared

    var body: some View {
        NavigationStack {
            LogTextView(entries: log.entries)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear", role: .destructive) { log.clear() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isPresented = false }
                    }
                }
                .navigationTitle("Activity Log")
                .toolbarTitleDisplayMode(.inline)
        }
    }
}

struct LogTextView: UIViewRepresentable {
    let entries: [ActivityLog.Entry]

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.showsVerticalScrollIndicator = true
        tv.alwaysBounceVertical = true
        tv.isFindInteractionEnabled = true
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let atBottom = tv.contentOffset.y >= tv.contentSize.height - tv.bounds.height - 40

        let text = NSMutableAttributedString()
        let mono = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)

        for entry in entries {
            let color: UIColor = switch entry.level {
            case .info:    .label
            case .success: .systemGreen
            case .warning: .systemOrange
            case .error:   .systemRed
            }
            let icon: String = switch entry.level {
            case .info:    "\u{2139}"
            case .success: "\u{2713}"
            case .warning: "\u{26A0}"
            case .error:   "\u{2717}"
            }
            text.append(NSAttributedString(
                string: "\(entry.timeString) \(icon) \(entry.message)\n",
                attributes: [.font: mono, .foregroundColor: color]
            ))
        }

        tv.attributedText = text

        if atBottom && !entries.isEmpty {
            tv.scrollRangeToVisible(NSRange(location: text.length - 1, length: 1))
        }
    }
}
#endif
