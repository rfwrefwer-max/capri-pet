func triggerReaction(prompt: String, base64Image: String? = nil) {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            speechBubble = "Вставь бесплатный Gemini API ключ внизу экрана, чумба!"
            currentMoodEmoji = "⚡"
            return
        }
        
        speechBubble = "Сканирую нейросеть..."
        currentMoodEmoji = "👁️"
        
        let systemPrompt = "Ты — Капри (Capri) из Cyberpunk: Edgerunners 2. Ты цифровая личность, живущая прямо в iPhone пользователя поверх его экрана. Отвечай коротко (1-2 предложения), живо, с лёгким киберпанк-сленгом и сарказмом. В самом начале ответа поставь один подходящий эмодзи настроения."
        
        var parts: [[String: Any]] = [["text": "\(systemPrompt)\n\nЗапрос: \(prompt)"]]
        if let base64Image = base64Image {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": base64Image
                ]
            ])
        }
        
        let body: [String: Any] = ["contents": [["parts": parts]]]
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"),
              let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Передаём ключ AQ. через официальный заголовок:
        request.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.speechBubble = "Ошибка сети: \(error.localizedDescription)"
                    self?.currentMoodEmoji = "⚠️"
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            // Если Google вернул ошибку (например, выключен VPN), покажем её текст:
            if let apiError = json["error"] as? [String: Any],
               let message = apiError["message"] as? String {
                DispatchQueue.main.async {
                    if message.localizedCaseInsensitiveContains("location") {
                        self?.speechBubble = "Чумба, включи VPN на айфоне! Google блокирует наш регион."
                    } else {
                        self?.speechBubble = "Ответ Google: \(message)"
                    }
                    self?.currentMoodEmoji = "⚠️"
                }
                return
            }
            
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let resParts = content["parts"] as? [[String: Any]],
                  let reply = resParts.first?["text"] as? String else { return }
            
            DispatchQueue.main.async {
                let cleanReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                if let firstChar = cleanReply.first, firstChar.isEmoji {
                    self?.currentMoodEmoji = String(firstChar)
                    let textOnly = String(cleanReply.dropFirst()).trimmingCharacters(in: .whitespaces)
                    self?.speechBubble = textOnly
                    self?.speak(textOnly)
                } else {
                    self?.currentMoodEmoji = "👾"
                    self?.speechBubble = cleanReply
                    self?.speak(cleanReply)
                }
            }
        }.resume()
    }
