import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            tabContent(for: selectedTab)
        }
        .frame(minWidth: 900, minHeight: 600)
        #else
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                .tag(AppTab.dashboard)

            LibraryView()
                .tabItem { Label("Libreria", systemImage: "books.vertical.fill") }
                .tag(AppTab.library)

            CommunityView()
                .tabItem { Label("Community", systemImage: "person.2.fill") }
                .tag(AppTab.community)

            SettingsView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        #endif
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard: DashboardView()
        case .library:   LibraryView()
        case .community: CommunityView()
        case .settings:  SettingsView()
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, library, community, settings
    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .library:   return "Libreria"
        case .community: return "Community"
        case .settings:  return "Impostazioni"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .library:   return "books.vertical.fill"
        case .community: return "person.2.fill"
        case .settings:  return "gearshape.fill"
        }
    }
}

// MARK: - Sidebar (macOS only)
#if os(macOS)
struct SidebarView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        List(AppTab.allCases, selection: $selectedTab) { tab in
            Label(tab.label, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationTitle("Readfolio")
    }
}
#endif
