import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var statusCounts:  [ReadingStatus: Int] = [:]
    var averageRating: Double               = 0
    var monthStats:    [MonthStat]          = []
    var recentItems:   [ReadingItem]        = []
    var isLoading      = false
    var errorMessage:  String?

    private let repository = ItemRepository()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all       = try await repository.fetchAll()
            statusCounts  = ItemRepository.countByStatus(in: all)
            averageRating = ItemRepository.averageRating(of: all)
            monthStats    = ItemRepository.completedPerMonth(from: all)
            recentItems   = Array(all.prefix(5))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var totalItems:     Int { statusCounts.values.reduce(0, +) }
    var completedCount: Int { statusCounts[.completed] ?? 0 }
    var readingCount:   Int { statusCounts[.reading]   ?? 0 }
    var toReadCount:    Int { statusCounts[.toRead]    ?? 0 }
    var abandonedCount: Int { statusCounts[.abandoned] ?? 0 }

    var formattedAverage: String {
        averageRating == 0 ? "—" : String(format: "%.1f", averageRating)
    }
}
