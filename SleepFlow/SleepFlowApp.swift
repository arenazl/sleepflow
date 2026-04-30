import SwiftUI
import SwiftData

@main
struct SleepFlowApp: App {
    @StateObject private var controller = SessionController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    controller.handleURL(url)
                }
                .task {
                    await controller.heart.requestAuthorization()
                }
        }
        .modelContainer(for: SleepSession.self)
    }
}

struct RootView: View {
    @EnvironmentObject var controller: SessionController
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            AppBackground()
            Group {
                switch controller.phase {
                case .idle:
                    HomeView()
                case .active:
                    SessionActiveView()
                case .finished:
                    SessionSummaryView(session: controller.lastSummary)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .animation(.easeInOut(duration: 0.4), value: controller.phase)
        .onAppear {
            controller.bind(modelContext)
        }
    }
}
