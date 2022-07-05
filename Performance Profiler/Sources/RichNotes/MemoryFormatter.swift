import Foundation

enum MemoryFormatter {

    static func formatted(bytes: Int, unit: ByteCountFormatStyle.Units = .mb) -> String {
        ByteCountFormatStyle(style: .memory, allowedUnits: unit).format(Int64(bytes))
    }

}
