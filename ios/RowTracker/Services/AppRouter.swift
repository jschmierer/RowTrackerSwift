import Foundation
import Observation

/// Which tab is on screen. Shared so a view in one tab (Log) can request a
/// move to another tab (Dashboard) after saving.
enum AppTab: Hashable {
    case dashboard
    case log
    case history
    case progress
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
}
