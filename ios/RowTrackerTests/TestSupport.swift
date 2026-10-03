import Foundation

/// Dummy class so `Bundle(for:)` points at the test bundle.
final class BundleToken {}

/// Loads a vector JSON file from `tests/vectors/` (added to the test bundle
/// as a folder reference by XcodeGen).
enum Vectors {
    static let bundle = Bundle(for: BundleToken.self)

    static func load<T: Decodable>(_ name: String, as type: T.Type) -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "vectors")
                ?? bundle.url(forResource: name, withExtension: "json") else {
            fatalError("Missing test vector: \(name).json")
        }
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(T.self, from: data)
    }
}
