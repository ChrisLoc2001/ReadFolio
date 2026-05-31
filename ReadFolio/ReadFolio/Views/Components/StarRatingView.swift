import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var interactive: Bool = true
    var starSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundStyle(star <= rating ? .yellow : .secondary)
                    .onTapGesture {
                        guard interactive else { return }
                        rating = (rating == star) ? 0 : star
                    }
                    .accessibilityLabel("\(star) stella\(star == 1 ? "" : "e")")
                    .accessibilityAddTraits(interactive ? .isButton : [])
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(rating == 0 ? "Non valutato" : "\(rating) su 5")
        .accessibilityAdjustableAction { direction in
            guard interactive else { return }
            switch direction {
            case .increment: rating = min(5, rating + 1)
            case .decrement: rating = max(0, rating - 1)
            @unknown default: break
            }
        }
    }
}
