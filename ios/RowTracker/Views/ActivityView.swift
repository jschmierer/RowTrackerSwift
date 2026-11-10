import SwiftUI
import UIKit

/// The iOS share sheet, opened from code. SwiftUI's ShareLink only opens
/// when the rower taps it, so the Log screen's "Share workout" button
/// (which saves first) uses this instead. The detail screen uses ShareLink.
struct ActivityView: UIViewControllerRepresentable {
    let text: String
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so the share text can drive `.sheet(item:)`.
struct ShareText: Identifiable {
    let id = UUID()
    let text: String
}
