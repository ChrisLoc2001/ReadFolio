import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var pendingCount: Int = 0
    private let socialRepo = SocialRepository()

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

            ProfileView()
                .tabItem { Label("Profilo", systemImage: "person.fill") }
                .badge(pendingCount > 0 ? pendingCount : 0)
                .tag(AppTab.settings)
        }
        .task { await refreshPending() }
        .onChange(of: selectedTab) { _, new in
            if new != .settings { Task { await refreshPending() } }
        }
        #endif
    }

    private func refreshPending() async {
        pendingCount = (try? await socialRepo.pendingRequests())?.count ?? 0
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard: DashboardView()
        case .library:   LibraryView()
        case .community: CommunityView()
        case .settings:  ProfileView()
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
        case .settings:  return "Profilo"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .library:   return "books.vertical.fill"
        case .community: return "person.2.fill"
        case .settings:  return "person.fill"
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
