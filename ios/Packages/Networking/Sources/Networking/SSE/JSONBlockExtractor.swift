import Foundation

public enum JSONBlockExtractor {
    public struct LabeledBlock: Equatable {
        public let label: String?    // e.g. "adjustment" / "workout" / "rationale" — nil if no label
        public let body: String
    }

    /// Returns every fenced ```json[ <label>] ... ``` block in order.
    public static func extractAllLabeled(from text: String) -> [LabeledBlock] {
        var out: [LabeledBlock] = []
        let pattern = "```json(?:[ \\t]+([a-z]+))?[ \\t]*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return out }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            let label: String? = m.range(at: 1).location == NSNotFound
                ? nil : ns.substring(with: m.range(at: 1))
            let body = ns.substring(with: m.range(at: 2))
            out.append(.init(label: label, body: body))
        }
        return out
    }

    /// Returns the contents of the first ```json[ <label>] ... ``` fence if present.
    /// Used by plan-gen which expects a single unlabeled block.
    public static func extract(from text: String) -> String? {
        let blocks = extractAllLabeled(from: text)
        // Prefer unlabeled (legacy plan-gen). Fall back to first labeled block.
        return blocks.first(where: { $0.label == nil })?.body ?? blocks.first?.body
    }
}
