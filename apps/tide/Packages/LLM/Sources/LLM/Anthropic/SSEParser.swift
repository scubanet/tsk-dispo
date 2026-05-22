import Foundation

/// One Server-Sent Event: an `event` name plus a `data` payload.
public struct SSEEvent: Equatable, Sendable {
  public let event: String
  public let data: String

  public init(event: String, data: String) {
    self.event = event
    self.data = data
  }
}

/// Tiny SSE parser. Splits a chunk of stream text on the blank-line
/// delimiter and extracts each event's `event:` and `data:` fields.
/// Multi-line `data:` fields (rare in Anthropic, but legal per spec) are
/// joined with `\n`. Blocks without an `event:` field are dropped — we
/// only care about typed events.
///
/// **Completeness rule:** the last block is always dropped because we
/// can't tell whether it was followed by `\n\n` in the wire format or
/// arrived mid-event. The streaming caller is expected to append a
/// closing `\n\n` to any final flush. This keeps the parser side-effect
/// free and prevents emitting half-parsed JSON.
public enum SSEParser {
  public static func parse(_ chunk: String) -> [SSEEvent] {
    var events: [SSEEvent] = []
    // `components(separatedBy: "\n\n")` returns one more element than there
    // are "\n\n" separators. The last element is either an empty string
    // (input ended with "\n\n", clean) or a potentially-incomplete tail
    // (input was cut mid-event). Either way it's unsafe — drop it.
    let blocks = chunk.components(separatedBy: "\n\n").dropLast()
    for block in blocks where !block.isEmpty {
      var eventName = ""
      var data = ""
      for line in block.components(separatedBy: "\n") {
        if line.hasPrefix("event:") {
          eventName = String(line.dropFirst("event:".count))
            .trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
          let part = String(line.dropFirst("data:".count))
            .trimmingCharacters(in: .whitespaces)
          data = data.isEmpty ? part : data + "\n" + part
        }
      }
      if !eventName.isEmpty {
        events.append(SSEEvent(event: eventName, data: data))
      }
    }
    return events
  }
}
