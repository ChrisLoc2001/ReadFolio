import SwiftUI
import Charts
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // MARK: - Stat Cards
                    statsGrid

                    // MARK: - Chart
                    monthlyChart

                    // MARK: - Recenti
                    recentSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .task {
                vm.setup(context: context)
                await vm.load()
            }
            .refreshable { await vm.load() }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCardView(
                title: "Letti",
                value: "\(vm.completedCount)",
                icon: "checkmark.seal.fill",
                color: .green
            )
            StatCardView(
                title: "In lettura",
                value: "\(vm.readingCount)",
                icon: "book.open",
                color: .orange
            )
            StatCardView(
                title: "Da leggere",
                value: "\(vm.toReadCount)",
                icon: "bookmark",
                color: .blue
            )
            StatCardView(
                title: "Media ⭐",
                value: vm.formattedAverage,
                icon: "star.fill",
                color: .yellow
            )
        }
    }

    // MARK: - Monthly Chart

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Completati per mese")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if vm.monthStats.isEmpty || vm.monthStats.allSatisfy({ $0.count == 0 }) {
                Text("Nessun dato disponibile")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart(vm.monthStats) { stat in
                    BarMark(
                        x: .value("Mese", stat.label),
                        y: .value("Completati", stat.count)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 160)
                .chartYAxis { AxisMarks(position: .leading) }
                .accessibilityLabel("Grafico completati per mese")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aggiunti di recente")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if vm.recentItems.isEmpty {
                Text("Nessun elemento ancora. Aggiungi il primo dalla Libreria!")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(vm.recentItems) { item in
                    NavigationLink(value: item) {
                        LibraryItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
