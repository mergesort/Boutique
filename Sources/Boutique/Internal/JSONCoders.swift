import Foundation

// A set of Encoders/Decoders used across Boutique.
// Rather than using different encoders/decoders across functions we can
// allocate them once here and not face additional performance costs.
enum JSONCoders {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
}
