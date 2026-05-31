//
//  DashboardViewModel.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var statusCounts: [ReadingStatus: Int] = [:]
    var averageRating: Double = 0
    var monthStats: [MonthStat] = []
    var recentItems: [ReadingItem] = []
    var isLoading = false
    var errorMessage: String?

    private var repository: ItemRepository?

    func setup(context: ModelContext) {
        repository = ItemRepository(context: context)
    }

    func load() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            statusCounts  = try repository.countByStatus()
            averageRating = try repository.averageRating()
            monthStats    = try repository.completedPerMonth()

            let all = try repository.fetchAll()
            recentItems = Array(all.prefix(5))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var totalItems: Int { statusCounts.values.reduce(0, +) }
    var completedCount: Int { statusCounts[.completed] ?? 0 }
    var readingCount: Int  { statusCounts[.reading]   ?? 0 }
    var toReadCount: Int   { statusCounts[.toRead]    ?? 0 }
    var abandonedCount: Int{ statusCounts[.abandoned] ?? 0 }

    var formattedAverage: String {
        averageRating == 0 ? "—" : String(format: "%.1f", averageRating)
    }
}
