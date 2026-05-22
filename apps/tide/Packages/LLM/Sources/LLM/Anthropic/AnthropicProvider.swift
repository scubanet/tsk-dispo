import Foundation

/// `LLMProvider` implementation against the Anthropic Messages API with
/// SSE streaming. Errors map onto `LLMError`. Tool-use chunks emit only
/// the `content_block_start` for the tool — v1 doesn't service tool
/// calls yet, but the event is surfaced so future code paths can.
public final class AnthropicProvider: LLMProvider {
  private let apiKey: String
  private let session: URLSession

  public init(apiKey: String, session: URLSession = .shared) {
    self.apiKey = apiKey
    self.session = session
  }

  public func streamChat(
    messages: [LLMMessage],
    tools: [LLMTool],
    model: String,
    systemPrompt: String?
  ) -> AsyncThrowingStream<LLMChunk, Error> {
    AsyncThrowingStream { continuation in
      let task = Task { [apiKey, session] in
        do {
          let request = try AnthropicRequestBuilder.makeRequest(
            apiKey: apiKey, messages: messages, tools: tools,
            model: model, systemPrompt: systemPrompt
          )
          let (bytes, response) = try await session.bytes(for: request)
          guard let http = response as? HTTPURLResponse else {
            throw LLMError.network("non-HTTP response")
          }
          switch http.statusCode {
          case 200..<300: break
          case 401: throw LLMError.unauthorized
          case 429:
            let retry = Int(http.value(forHTTPHeaderField: "retry-after") ?? "10") ?? 10
            throw LLMError.rateLimit(retryAfterSeconds: retry)
          default:
            throw LLMError.serverError(code: http.statusCode, message: "")
          }

          var buffer = ""
          for try await line in bytes.lines {
            buffer += line + "\n"
            if line.isEmpty {
              let events = SSEParser.parse(buffer)
              buffer = ""
              for event in events {
                if let chunk = decodeChunk(event: event) {
                  continuation.yield(chunk)
                }
              }
            }
          }
          if !buffer.isEmpty {
            let events = SSEParser.parse(buffer + "\n")
            for event in events {
              if let chunk = decodeChunk(event: event) {
                continuation.yield(chunk)
              }
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private func decodeChunk(event: SSEEvent) -> LLMChunk? {
    guard let data = event.data.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }

    switch event.event {
    case "content_block_delta":
      if let delta = json["delta"] as? [String: Any],
         let type = delta["type"] as? String,
         type == "text_delta",
         let text = delta["text"] as? String {
        return .text(text)
      }
    case "content_block_start":
      if let block = json["content_block"] as? [String: Any],
         let type = block["type"] as? String,
         type == "tool_use",
         let id = block["id"] as? String,
         let name = block["name"] as? String {
        // Tool input arrives via subsequent input_json_delta events.
        // v1: surface the start, leave input buffering to Phase-2-future.
        return .toolUse(id: id, name: name, inputJSON: "")
      }
    case "message_stop":
      return .done
    default:
      return nil
    }
    return nil
  }
}
