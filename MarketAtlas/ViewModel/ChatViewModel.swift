import Foundation

@MainActor
@Observable
final class ChatViewModel {

    struct Message: Identifiable {
        let id = UUID()
        let isUser: Bool
        let userText: String?
        let response: ChatResponse?
    }

    var messages: [Message] = []
    var inputText: String = ""
    var isLoading = false

    // Build history for API (last 3 user/assistant exchanges)
    private var historyForAPI: [ChatMessage] {
        var result: [ChatMessage] = []
        for msg in messages.suffix(6) {
            if msg.isUser, let text = msg.userText {
                result.append(ChatMessage(role: "user", content: text))
            } else if !msg.isUser, let resp = msg.response {
                let text = resp.blocks.compactMap { block -> String? in
                    if case .text(let t) = block { return t.content }
                    return nil
                }.joined(separator: "\n")
                if !text.isEmpty {
                    result.append(ChatMessage(role: "assistant", content: text))
                }
            }
        }
        return result
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        SpeechManager.shared.stop()
        inputText = ""
        let history = historyForAPI  // capture BEFORE appending current message
        messages.append(Message(isUser: true, userText: text, response: nil))
        isLoading = true

        do {
            let response = try await APIService.shared.sendChatMessage(
                message: text,
                history: history
            )
            messages.append(Message(isUser: false, userText: nil, response: response))
        } catch {
            let fallback = ChatResponse(blocks: [
                .text(TextChatBlock(content: "Sorry, I couldn't process that. Please try again."))
            ])
            messages.append(Message(isUser: false, userText: nil, response: fallback))
        }

        isLoading = false
    }

    func clear() {
        messages = []
        inputText = ""
    }
}
