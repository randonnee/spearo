import Foundation

struct SpearoSlot: Codable, Identifiable, Equatable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String

    static func == (lhs: SpearoSlot, rhs: SpearoSlot) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
