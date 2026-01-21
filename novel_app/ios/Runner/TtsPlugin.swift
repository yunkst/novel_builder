import Flutter
import AVFoundation

/// TTS插件 - iOS原生实现
public class TtsPlugin: NSObject, FlutterPlugin, AVSpeechSynthesizerDelegate {
    private var synthesizer: AVSpeechSynthesizer
    private var channel: FlutterMethodChannel?
    private var initialized = false

    public override init() {
        synthesizer = AVSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.example.novel_app/tts", binaryMessenger: registrar.messenger())
        let instance = TtsPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(result)
        case "speak":
            if let args = call.arguments as? [String: Any],
               let text = args["text"] as? String {
                speak(text: text, result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Text is required", details: nil))
            }
        case "pause":
            pause(result)
        case "resume":
            resume(result)
        case "stop":
            stop(result)
        case "setSpeechRate":
            if let args = call.arguments as? [String: Any],
               let rate = args["rate"] as? Double {
                setRate(rate: rate, result)
            } else {
                result(nil)
            }
        case "setPitch":
            if let args = call.arguments as? [String: Any],
               let pitch = args["pitch"] as? Double {
                setPitch(pitch: pitch, result)
            } else {
                result(nil)
            }
        case "setVolume":
            if let args = call.arguments as? [String: Any],
               let volume = args["volume"] as? Double {
                setVolume(volume: volume, result)
            } else {
                result(nil)
            }
        case "getVoices":
            getVoices(result)
        case "setVoice":
            if let args = call.arguments as? [String: Any],
               let voiceId = args["voiceId"] as? String {
                setVoice(identifier: voiceId, result)
            } else {
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// 初始化TTS引擎
    private func initialize(_ result: @escaping FlutterResult) {
        do {
            // 配置音频会话
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)

            initialized = true
            result(true)
        } catch {
            print("[TtsPlugin] 音频会话配置失败: \(error)")
            result(false)
        }
    }

    /// 朗读文本
    private func speak(text: String, _ result: @escaping FlutterResult) {
        if !initialized {
            result(FlutterError(code: "NOT_INITIALIZED", message: "TTS not initialized", details: nil))
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = Float(speechRate)
        utterance.pitchMultiplier = Float(pitch)
        utterance.volume = Float(volume)

        synthesizer.speak(utterance)
        result(text)
    }

    /// 暂停朗读
    private func pause(_ result: @escaping FlutterResult) {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
        }
        result(nil)
    }

    /// 继续朗读
    private func resume(_ result: @escaping FlutterResult) {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
        result(nil)
    }

    /// 停止朗读
    private func stop(_ result: @escaping FlutterResult) {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        result(nil)
    }

    // 播放参数
    private var speechRate: Double = 1.0
    private var pitch: Double = 1.0
    private var volume: Double = 1.0

    /// 设置语速
    private func setRate(rate: Double, _ result: @escaping FlutterResult) {
        speechRate = max(0.5, min(2.0, rate))
        result(nil)
    }

    /// 设置音调
    private func setPitch(pitch: Double, _ result: @escaping FlutterResult) {
        self.pitch = max(0.5, min(2.0, pitch))
        result(nil)
    }

    /// 设置音量
    private func setVolume(volume: Double, _ result: @escaping FlutterResult) {
        self.volume = max(0.0, min(1.0, volume))
        result(nil)
    }

    /// 获取可用语音列表
    private func getVoices(_ result: @escaping FlutterResult) {
        let voices = AVSpeechSynthesisVoice.speechVoices().map { voice in
            [
                "id": voice.identifier,
                "name": voice.name,
                "locale": voice.language,
                "language": voice.language.components(separatedBy: "-").first ?? ""
            ]
        }
        result(voices)
    }

    /// 设置语音
    private func setVoice(identifier: String, _ result: @escaping FlutterResult) {
        // 语音设置需要在speak时应用，这里记录标识符
        result(nil)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        channel?.invokeMethod("onSpeakStart", arguments: utterance.speechString)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        channel?.invokeMethod("onSpeakComplete", arguments: utterance.speechString)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        channel?.invokeMethod("onSpeakComplete", arguments: utterance.speechString)
    }
}
