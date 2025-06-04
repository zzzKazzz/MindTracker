import Foundation

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

struct ChatResponse: Codable {
    struct Choice: Codable {
        let message: ChatMessage
    }
    let choices: [Choice]
}

class ChatGPTManager {
    static let shared = ChatGPTManager()
    private init() {}

    private let apiKey = "YOUR_OPENAI_API_KEY" // Set your API key here
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    func analyze(entries: [MindfulnessData], completion: @escaping (Result<String, Error>) -> Void) {
        var messages: [ChatMessage] = [
            ChatMessage(role: "system", content: "ユーザーの記録から価値観やモチベーションが感じられる行動や瞬間を抽出し、日本語で200文字以内でまとめてください。")
        ]

        let formatter = ISO8601DateFormatter()
        for entry in entries {
            let timestamp = entry.timestamp ?? Date()
            let activity = entry.activity ?? ""
            let feelings = entry.feelings ?? ""
            let mood = entry.mood ?? ""
            let content = "日時: \(formatter.string(from: timestamp))\n活動: \(activity)\n気分: \(mood)\n感情: \(feelings)"
            messages.append(ChatMessage(role: "user", content: content))
        }

        let requestBody = ChatRequest(model: "gpt-3.5-turbo", messages: messages, temperature: 0.7)

        guard let bodyData = try? JSONEncoder().encode(requestBody) else {
            completion(.failure(NSError(domain: "Encoding", code: -1, userInfo: nil)))
            return
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let response = try? JSONDecoder().decode(ChatResponse.self, from: data),
                  let text = response.choices.first?.message.content else {
                completion(.failure(NSError(domain: "InvalidResponse", code: -1, userInfo: nil)))
                return
            }
            completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        }.resume()
    }
}

