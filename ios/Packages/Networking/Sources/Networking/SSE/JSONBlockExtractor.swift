import Foundation

public enum JSONBlockExtractor {
    /// Extract the LAST ```json fenced code block from the text. Returns the content
    /// without the fences, leading/trailing whitespace trimmed. Nil if no block.
    public static func extract(from text: String) -> String? {
        let pattern = "```json\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard let last = matches.last else { return nil }
        guard let inner = Range(last.range(at: 1), in: text) else { return nil }
        return String(text[inner]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
