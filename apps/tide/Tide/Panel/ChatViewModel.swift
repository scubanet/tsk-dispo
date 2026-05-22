import Foundation
import Observation
import Core
import LLM
import TideSpeech

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

  private var recorder: AudioRecorder?
  private var partialTask: Task<Void, Never>?

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

    let userMsg = Message(role: .user, content: trimmed)
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
        }
      }
      try? conversationStore.append(assistantMsg, to: conv)
    } catch {
      assistantMsg.content += "\n\n[Fehler: \(error.localizedDescription)]"
      messages = messages.map { $0 }
    }
  }

  func startNew() {
    _ = try? conversationStore.startNew()
    messages = []
  }

  func startRecording() async {
    guard !isRecording else { return }
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
