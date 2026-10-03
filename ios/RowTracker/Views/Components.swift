import SwiftUI

/// Small stat block for the Dashboard.
struct StatTile: View {
    let title: String
    let value: String
    let subtitle: String?

    init(title: String, value: String, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// One row in a workout list — date, type, totals, optional notes.
struct WorkoutRow: View {
    let workout: Workout

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Self.dateFormatter.string(from: workout.date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(workout.kind == .timed ? "Timed" : "Distance")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            HStack(spacing: 12) {
                Text("\(Int(workout.totalDistance)) m")
                Text(RowingMath.formatTime(workout.totalDuration))
                if let avg = workout.averageSplit {
                    Text(RowingMath.formatTime(avg) + " /500m")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            if !workout.notes.isEmpty {
                Text(workout.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
