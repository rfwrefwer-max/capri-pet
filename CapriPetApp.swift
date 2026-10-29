import SwiftUI
import AVKit
import AVFoundation
import UIKit

@main
struct CapriPetApp: App {
    @StateObject private var manager = CapriManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager)
                .onOpenURL { url in
                    if url.host == "scan" {
                        manager.analyzeClipboardScreenshot()
                    }
                }
        }
    }
}

// MARK: - Главный экран управления и виджета внутри приложения
struct ContentView: View {
    @ObservedObject var manager: CapriManager
    @State private var userInput: String = ""
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 18) {
                    // Заголовок в стиле Киберпанк
                    HStack {
                        Text("CAPRI // OS v2.077")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.yellow)
                        Spacer()
                        Circle()
                            .fill(manager.isPiPActive ? Color.green : Color.cyan)
                            .frame(width: 10, height: 10)
                        Text(manager.isPiPActive ? "OVERLAY ON" : "STANDBY")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal)
                    
                    // Превью карточки Капри (то, что уходит в плавающее окно поверх экрана)
                    VStack(spacing: 10) {
                        Text(manager.currentMoodEmoji)
                            .font(.system(size: 64))
                            .scaleEffect(manager.isAnimating ? 1.08 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: manager.isAnimating)
                        
                        Text("CAPRI")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                        
                        Text(manager.speechBubble)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.yellow, lineWidth: 2)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.16).cornerRadius(16))
                    )
                    .padding(.horizontal)
                    
                    // Скрытый слой для генерации плавающего окна PiP
                    PiPContainerView(layer: manager.sampleBufferLayer)
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                    
                    // Кнопки управления оверлеем и реакцией на экран
                    HStack(spacing: 12) {
                        Button(action: {
                            manager.togglePiP()
                        }) {
                            Label(manager.isPiPActive ? "Убрать с экрана" : "Вывести поверх экрана", systemImage: "pip.enter")
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.yellow)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            manager.analyzeClipboardScreenshot()
                        }) {
                            Label("Оценить экран", systemImage: "eye.fill")
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.cyan)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Интерактивная панель быстрых действий (Виджет-панель)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ВЗАИМОДЕЙСТВИЕ")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 10) {
                            ActionButton(title: "Потыкать", icon: "hand.tap.fill") {
                                manager.triggerReaction(prompt: "Пользователь тыкнул в тебя пальцем на экране телефона. Отреагируй дерзко в стиле Капри!")
                            }
                            ActionButton(title: "Что делать?", icon: "bolt.fill") {
                                manager.triggerReaction(prompt: "Дай короткий киберпанк-совет на день, будто ты сидишь в нейроимпланте пользователя.")
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Чат с Капри
                    HStack {
                        TextField("Напиши Капри...", text: $userInput)
                            .textFieldStyle(.roundedBorder)
                            .colorScheme(.dark)
                        
                        Button("Отпр.") {
                            guard !userInput.isEmpty else { return }
                            let text = userInput
                            userInput = ""
                            manager.triggerReaction(prompt: text)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Настройка API ключа Gemini
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GEMINI API KEY (для зрения и ИИ):")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.gray)
                        SecureField("Вставь ключ из Google AI Studio", text: $manager.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .colorScheme(.dark)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
        }
        .onAppear {
            manager.isAnimating = true
            manager.startRenderingLoop()
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(.caption, design: .monospaced).bold())
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.1))
            .foregroundColor(.cyan)
            .cornerRadius(8)
        }
    }
}

// MARK: - Логика плавающего окна (PiP без кнопок) и ИИ
class CapriManager: NSObject, ObservableObject, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    @Published var speechBubble: String = "Никто меня не слышит и не видит... кроме тебя, чумба."
    @Published var currentMoodEmoji: String = "👾"
    @Published var isPiPActive: Bool = false
    @Published var isAnimating: Bool = false
    @AppStorage("gemini_api_key") var apiKey: String = ""
    
    let sampleBufferLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController?
    private var renderTimer: Timer?
    private let synth = AVSpeechSynthesizer()
    private var frameToggle = false
    
    override init() {
        super.init()
        setupAudioSession()
        setupPiP()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio error: \(error)")
        }
    }
    
    private func setupPiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        sampleBufferLayer.frame = CGRect(x: 0, y: 0, width: 360, height: 220)
        sampleBufferLayer.videoGravity = .resizeAspect
        
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: sampleBufferLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.requiresLinearPlayback = true
        // Приватный ключ iOS: полностью убирает кнопки паузы/перемотки с плавающего окна!
        controller.setValue(2, forKey: "controlsStyle")
        self.pipController = controller
    }
    
    func startRenderingLoop() {
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.enqueueCapriFrame()
        }
    }
    
    func togglePiP() {
        guard let pip = pipController else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
        }
    }
    
    // Отрисовка Капри и её текста в видеопоток плавающего окна
    private func enqueueCapriFrame() {
        frameToggle.toggle()
        let size = CGSize(width: 360, height: 220)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { ctx in
            UIColor(red: 0.06, green: 0.06, blue: 0.11, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // Неоновая рамка
            let borderRect = CGRect(x: 4, y: 4, width: size.width - 8, height: size.height - 8)
            UIColor.systemYellow.setStroke()
            let path = UIBezierPath(roundedRect: borderRect, cornerRadius: 14)
            path.lineWidth = 3
            path.stroke()
            
            // Аватар/Спрайт Капри (сюда можно подставить свои PNG-спрайты в Assets)
            let emojiY: CGFloat = frameToggle ? 18 : 24
            let emojiAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 54)]
            (currentMoodEmoji as NSString).draw(at: CGPoint(x: 22, y: emojiY), withAttributes: emojiAttr)
            
            // Имя
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.cyan
            ]
            ("CAPRI // LIVE" as NSString).draw(at: CGPoint(x: 92, y: 20), withAttributes: titleAttr)
            
            // Реплика Капри поверх экрана
            let textRect = CGRect(x: 92, y: 44, width: size.width - 108, height: size.height - 56)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            let textAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            (speechBubble as NSString).draw(in: textRect, withAttributes: textAttr)
        }
        
        if let buffer = makeSampleBuffer(from: image) {
            if sampleBufferLayer.status == .failed {
                sampleBufferLayer.flush()
            }
            sampleBufferLayer.enqueue(buffer)
        }
    }
    
    // MARK: - Озвучка и ИИ (Чат + Зрение экрана)
    func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = 0.53
        utterance.pitchMultiplier = 1.15
        synth.speak(utterance)
    }
    
    func triggerReaction(prompt: String, base64Image: String? = nil) {
        guard !apiKey.isEmpty else {
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
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"),
              let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let resParts = content["parts"] as? [[String: Any]],
                  let reply = resParts.first?["text"] as? String else {
                DispatchQueue.main.async {
                    self?.speechBubble = "Сбой связи с Сетью. Проверь ключ API!"
                    self?.currentMoodEmoji = "⚠️"
                }
                return
            }
            
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
    
    // Чтение скриншота твоего экрана из буфера обмена (вызывается по двойному тапу сзади iPhone)
    func analyzeClipboardScreenshot() {
        if let image = UIPasteboard.general.image,
           let jpegData = image.jpegData(compressionQuality: 0.5) {
            let base64 = jpegData.base64EncodedString()
            triggerReaction(prompt: "Посмотри на скриншот экрана моего телефона прямо сейчас и прокомментируй то, чем я занимаюсь или во что играю!", base64Image: base64)
        } else {
            speechBubble = "В буфере нет скриншота! Сделай скрин или тапни дважды по крышке iPhone."
            currentMoodEmoji = "👀"
        }
    }
    
    // MARK: - Делегаты PiP
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { return false }
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    private func makeSampleBuffer(from image: UIImage) -> CMSampleBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &formatDesc)
        guard let desc = formatDesc else { return nil }
        
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescription: desc, sampleTiming: &timing, sampleBufferOut: &sampleBuffer)
        
        if let sb = sampleBuffer, let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(), Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sampleBuffer
    }
}

struct PiPContainerView: UIViewRepresentable {
    let layer: AVSampleBufferDisplayLayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.layer.addSublayer(layer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        layer.frame = uiView.bounds
    }
}

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value >= 0x203C || unicodeScalars.count >= 2)
    }
}
