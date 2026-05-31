import SwiftUI

struct StatusBadgeView: View {
    let status: ReadingStatus

    var body: some View {
        Label(status.rawValue, systemImage: status.systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
            .accessibilityLabel("Stato: \(status.rawValue)")
    }
}
