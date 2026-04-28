import Foundation

/// Incremental SSE parser. Feed `Data` chunks as they arrive; receive complete
/// events back. Buffers partial events across chunk boundaries.
public struct SSEStreamParser {
    private var buffer = ""

    public init() {}

    public mutating func feed(_ chunk: Data) -> [SSEEvent] {
        guard let s = String(data: chunk, encoding: .utf8) else { return [] }
        buffer.append(s)

        var events: [SSEEvent] = []
        // Events are separated by a blank line ("\n\n" or "\r\n\r\n").
        while let range = buffer.range(of: "\n\n") {
            let raw = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if let evt = Self.parseEvent(raw) {
                events.append(evt)
            }
        }
        return events
    }

    private static func parseEvent(_ raw: String) -> SSEEvent? {
        var event = "message"
        var dataLines: [String] = []
        var id: String? = nil
        for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix(":") { continue }            // comment
            guard let colon = line.firstIndex(of: ":") else { continue }
            let field = String(line[..<colon])
            var value = String(line[line.index(after: colon)...])
            if value.hasPrefix(" ") { value.removeFirst() }
            switch field {
            case "event": event = value
            case "data":  dataLines.append(value)
            case "id":    id = value
            default: break
            }
        }
        guard !dataLines.isEmpty else { return nil }
        return SSEEvent(event: event, data: dataLines.joined(separator: "\n"), id: id)
    }
}
