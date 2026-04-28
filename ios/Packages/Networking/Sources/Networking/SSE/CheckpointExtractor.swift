import Foundation

public struct CheckpointExtractor {
    public struct Result: Equatable {
        public let passthroughText: String
        public let checkpoints: [String]
    }

    private static let openMarker = "⟦CHECKPOINT: "
    private static let closeMarker = "⟧"

    private var buffer = ""

    public init() {}

    public mutating func feed(_ chunk: String) -> Result {
        buffer.append(chunk)

        var passthrough = ""
        var checkpoints: [String] = []

        while let openRange = buffer.range(of: Self.openMarker) {
            // Emit text before the open marker
            passthrough.append(contentsOf: buffer[..<openRange.lowerBound])
            // Look for matching close marker after the open
            let afterOpen = openRange.upperBound
            if let closeRange = buffer.range(of: Self.closeMarker, range: afterOpen..<buffer.endIndex) {
                let label = String(buffer[afterOpen..<closeRange.lowerBound])
                checkpoints.append(label)
                buffer.removeSubrange(buffer.startIndex..<closeRange.upperBound)
            } else {
                // Open marker without close — keep everything from openRange onward in buffer
                buffer.removeSubrange(buffer.startIndex..<openRange.lowerBound)
                return Result(passthroughText: passthrough, checkpoints: checkpoints)
            }
        }
        // No more open markers; buffer might still hold a partial open prefix
        // (e.g. ending with "⟦CHECK"). Don't emit those bytes yet.
        if let partial = Self.partialOpenSuffixIndex(in: buffer) {
            passthrough.append(contentsOf: buffer[..<partial])
            buffer.removeSubrange(buffer.startIndex..<partial)
        } else {
            passthrough.append(buffer)
            buffer.removeAll(keepingCapacity: true)
        }
        return Result(passthroughText: passthrough, checkpoints: checkpoints)
    }

    /// If the buffer ends with a strict prefix of `openMarker`, return the index where
    /// that prefix begins (so it can stay in the buffer for the next chunk).
    private static func partialOpenSuffixIndex(in s: String) -> String.Index? {
        let m = openMarker
        var len = m.count - 1
        while len > 0 {
            let suffix = m.prefix(len)
            if s.hasSuffix(suffix) {
                return s.index(s.endIndex, offsetBy: -len)
            }
            len -= 1
        }
        return nil
    }
}
