//
//  ReadingHistoryView.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import SwiftUI

struct ReadingHistoryView: View {
    let item: ReadingItem
    let duration: String?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            if let start = item.startDate {
                historyRow(
                    icon: "play.circle.fill",
                    color: .orange,
                    label: "Inizio lettura",
                    value: dateFormatter.string(from: start)
                )
            }
            if let end = item.endDate {
                historyRow(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    label: "Fine lettura",
                    value: dateFormatter.string(from: end)
                )
            }
            if let dur = duration {
                historyRow(
                    icon: "clock",
                    color: .blue,
                    label: "Durata",
                    value: dur
                )
            }
            historyRow(
                icon: "plus.circle.fill",
                color: .secondary,
                label: "Aggiunto",
                value: dateFormatter.string(from: item.createdAt)
            )
            historyRow(
                icon: "arrow.clockwise.circle.fill",
                color: .secondary,
                label: "Aggiornato",
                value: dateFormatter.string(from: item.updatedAt)
            )
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func historyRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
