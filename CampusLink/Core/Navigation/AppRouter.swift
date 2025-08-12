import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var path = NavigationPath()
    private init() {}

    func pushTransactions() {
        path.append(Route.transactions)
    }
}

enum Route: Hashable {
    case transactions
}

struct RouterView<Content: View>: View {
    @ObservedObject var router: AppRouter
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack(path: $router.path) {
            content()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .transactions:
                        MyTransactionsView()
                    }
                }
        }
    }
}


