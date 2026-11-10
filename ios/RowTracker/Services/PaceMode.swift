import Foundation

/// How the detail screen shows pace: as a split per 500 m or as watts.
/// Watts are always derived from the split, never stored.
enum PaceMode: String, CaseIterable, Identifiable {
    case split
    case watts

    var id: Self { self }

    /// Segmented-control label.
    var label: String {
        switch self {
        case .split: return "Split"
        case .watts: return "Watts"
        }
    }

    /// Row label for an average ("Average split" / "Average watts").
    var averageLabel: String { "Average " + label.lowercased() }

    /// "1:45.2 /500m" or "302 W" for a split in seconds per 500 m.
    func format(split: TimeInterval?) -> String {
        switch self {
        case .split: return DetailFormat.split(split)
        case .watts: return DetailFormat.watts(split.flatMap(RowingMath.watts(fromSplit:)))
        }
    }

    /// The number to plot: seconds per 500 m, or watts.
    func value(split: TimeInterval) -> Double? {
        switch self {
        case .split: return split
        case .watts: return RowingMath.watts(fromSplit: split)
        }
    }
}
