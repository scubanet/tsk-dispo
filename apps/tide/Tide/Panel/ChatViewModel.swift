import Foundation
import Observation
import Core
import LLM
import TideSpeech
import Selection

@Observable
@MainActor
final class ChatViewModel {
  let conversationStore: ConversationStore
  private let provider: any LLMProvider
  private let settings: AppSettings

  var messages: [Message] = []
  var input: String = ""
  var isStreaming = false

  var isRecording = false
  var liveTranscript = ""

  /// Selection captured from another app, waiting to be included in the
  /// next outgoing user message. Cleared after send() or startNew().
  var pendingSelection: SelectedText? = nil

  private var recorder: AudioRecorder?
  private var partialTask: Task<Void, Never>?
  private let synthesizer: any Synthesizer = AppleSynthesizer()
  private var pendingForTTS: String = ""

  init(conversationStore: ConversationStore, provider: any LLMProvider, settings: AppSettings) {
    self.conversationStore = conversationStore
    self.provider = provider
    self.settings = settings
    loadActiveConversation()
  }

  private func loadActiveConversation() {
    if let conv = conversationStore.activeConversation() {
      messages = conv.messages.sorted { $0.createdAt < $1.createdAt }
    }
  }

  func send() async {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isStreaming else { return }
    input = ""

    let conv: Conversation
    if let active = conversationStore.activeConversation() {
      conv = active
    } else {
      do {
        conv = try conversationStore.startNew()
      } catch {
        return
      }
    }

    // Compose the actual prompt. If we have a selection, include it.
    let promptText: String
    if let sel = pendingSelection {
      promptText = """
      Selektierter Text aus \(sel.sourceAppName):
      \"\"\"
      \(sel.text)
      \"\"\"

      \(trimmed)
      """
    } else {
      promptText = trimmed
    }

    let userMsg = Message(role: .user, content: promptText)
    // Persist selection-context JSON on the message for UI redisplay.
    if let sel = pendingSelection,
       let data = try? JSONEncoder().encode(sel),
       let json = String(data: data, encoding: .utf8) {
      userMsg.selectionContextJSON = json
    }
    // Clear pendingSelection after composing — single-shot semantic.
    pendingSelection = nil

    try? conversationStore.append(userMsg, to: conv)
    messages.append(userMsg)

    let assistantMsg = Message(role: .assistant, content: "")
    try? conversationStore.append(assistantMsg, to: conv)
    messages.append(assistantMsg)

    isStreaming = true
    defer { isStreaming = false }

    do {
      let llmMessages = messages.dropLast().map { msg in
        LLMMessage(
          role: msg.role == .user ? .user : .assistant,
          content: msg.content
        )
      }
      let stream = provider.streamChat(
        messages: Array(llmMessages),
        tools: [],
        model: settings.selectedModel,
        systemPrompt: defaultSystemPrompt
      )
      for try await chunk in stream {
        if case let .text(t) = chunk {
          assistantMsg.content += t
          // Force SwiftUI re-render by re-emitting the array
          messages = messages.map { $0 }
          if settings.voiceEnabled {
            pendingForTTS += t
            while let range = pendingForTTS.range(
              of: #"[\.!\?][\s\n]"#, options: .regularExpression
            ) {
              let sentence = String(pendingForTTS[..<range.upperBound])
              synthesizer.speak(sentence)
              pendingForTTS.removeSubrange(..<range.upperBound)
            }
          }
        }
      }
      // Flush any leftover partial sentence after the stream ends.
      if settings.voiceEnabled, !pendingForTTS.isEmpty {
        synthesizer.speak(pendingForTTS)
      }
      pendingForTTS = ""
      try? conversationStore.append(assistantMsg, to: conv)
    } catch {
      assistantMsg.content += "\n\n[Fehler: \(error.localizedDescription)]"
      messages = messages.map { $0 }
      pendingForTTS = ""
    }
  }

  func startNew() {
    synthesizer.stop()
    _ = try? conversationStore.startNew()
    messages = []
    pendingSelection = nil
  }

  func startRecording() async {
    guard !isRecording else { return }
    synthesizer.stop()
    let recognizer = AppleSpeechRecognizer()
    let recorder = AudioRecorder(recognizer: recognizer)
    self.recorder = recorder
    liveTranscript = ""
    isRecording = true

    // Subscribe to partial transcripts so the UI can show the live text.
    partialTask = Task { [weak self] in
      for await partial in recorder.partialTranscript {
        await MainActor.run {
          self?.liveTranscript = partial
        }
      }
    }

    do {
      try await recorder.start()
    } catch {
      isRecording = false
      self.recorder = nil
      partialTask?.cancel()
    }
  }

  func stopRecording() async {
    guard isRecording, let recorder else { return }
    isRecording = false
    do {
      let finalText = try await recorder.stop()
      let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        input = trimmed
        await send()
      }
    } catch {
      // Swallow — UI will just show no result.
    }
    self.recorder = nil
    partialTask?.cancel()
    liveTranscript = ""
  }

  private let defaultSystemPrompt = """
  Du bist ein präziser Assistent für einen deutschsprachigen Nutzer.
  Antworte direkt und ohne Floskeln.
  """
}
