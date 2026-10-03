import Foundation
import Testing
@testable import RowTracker

// MARK: - Vector decoding

struct ParseTimeCase: Decodable, Sendable {
    let name: String
    let input: String
    let python_actual: Double?
    let python_raises: String?
    let expected: Double?
    let suspected_bug: Bool
}

struct FormatTimeCase: Decodable, Sendable {
    let name: String
    let value: Double
    let python_actual: String
    let expected: String?
    let suspected_bug: Bool
}

struct VectorInterval: Decodable, Sendable {
    let time: String
    let distance: Double
    let split: String
}

struct AverageExpected: Decodable, Sendable {
    let total_time_sec: Double?
    let total_distance: Double?
    let avg_split_sec: Double?
    let total_time_str: String?
    let avg_split_str: String?
}

struct AverageCase: Decodable, Sendable {
    let name: String
    let intervals: [VectorInterval]
    let python_actual: AverageExpected
    let expected: AverageExpected?
    let suspected_bug: Bool
}

// MARK: - parseTime

@Suite("RowingMath.parseTime")
struct ParseTimeTests {
    @Test(arguments: Vectors.load("parse_time", as: [ParseTimeCase].self))
    func matchesOracle(_ c: ParseTimeCase) throws {
        let target = c.expected ?? c.python_actual
        guard let target else {
            Issue.record("Vector \(c.name) has neither expected nor python_actual.")
            return
        }
        let actual = try RowingMath.parseTime(c.input)
        #expect(abs(actual - target) < 1e-9, "\(c.name): got \(actual), expected \(target)")
    }
}

@Suite("RowingMath.parseTime input validation")
struct ParseTimeInvalidTests {
    @Test("empty input throws") func emptyThrows() {
        #expect(throws: RowingMath.ParseError.self) {
            _ = try RowingMath.parseTime("   ")
        }
    }

    @Test("garbage throws") func garbageThrows() {
        #expect(throws: RowingMath.ParseError.self) {
            _ = try RowingMath.parseTime("abc")
        }
    }

    @Test("minute >= 60 throws for H:MM:SS") func minuteOutOfRange() {
        #expect(throws: RowingMath.ParseError.self) {
            _ = try RowingMath.parseTime("1:60:00")
        }
    }
}

// MARK: - formatTime

@Suite("RowingMath.formatTime")
struct FormatTimeTests {
    @Test(arguments: Vectors.load("format_time", as: [FormatTimeCase].self))
    func matchesOracle(_ c: FormatTimeCase) {
        let target = c.expected ?? c.python_actual
        let actual = RowingMath.formatTime(c.value)
        #expect(actual == target, "\(c.name): got \(actual), expected \(target)")
    }
}

// MARK: - averageSplit via Workout

@Suite("Workout totals and averageSplit")
struct AverageSplitTests {
    @Test(arguments: Vectors.load("average_split", as: [AverageCase].self))
    func matchesOracle(_ c: AverageCase) throws {
        let intervals: [Interval] = try c.intervals.map {
            let dur = try RowingMath.parseTime($0.time)
            return Interval(durationSec: dur, distanceMeters: $0.distance)
        }
        let workout = Workout(kind: .timed, intervals: intervals)

        let expectedTotalTime = c.expected?.total_time_sec ?? c.python_actual.total_time_sec
        if let t = expectedTotalTime {
            #expect(abs(workout.totalDuration - t) < 1e-6, "\(c.name) total time")
        }
        let expectedTotalDist = c.expected?.total_distance ?? c.python_actual.total_distance
        if let d = expectedTotalDist {
            #expect(abs(workout.totalDistance - d) < 1e-6, "\(c.name) total distance")
        }
        let expectedAvgSec = c.expected?.avg_split_sec ?? c.python_actual.avg_split_sec
        if let a = expectedAvgSec {
            let actual = workout.averageSplit ?? -1
            // Python rounds the stored avg to 1 decimal; compare rounded.
            let rounded = (actual * 10).rounded() / 10
            #expect(abs(rounded - a) < 0.1, "\(c.name) avg split: \(rounded) vs \(a)")
        }
        // String comparisons — these are the ones that catch the Python bugs.
        let expectedTotalStr = c.expected?.total_time_str ?? c.python_actual.total_time_str
        if let s = expectedTotalStr {
            let actual = RowingMath.formatTime(workout.totalDuration)
            #expect(actual == s, "\(c.name) total time str: got \(actual), expected \(s)")
        }
        let expectedAvgStr = c.expected?.avg_split_str ?? c.python_actual.avg_split_str
        if let s = expectedAvgStr, let avg = workout.averageSplit {
            // Round like Python does before formatting.
            let roundedAvg = (avg * 10).rounded() / 10
            let actual = RowingMath.formatTime(roundedAvg)
            #expect(actual == s, "\(c.name) avg split str: got \(actual), expected \(s)")
        }
    }
}
