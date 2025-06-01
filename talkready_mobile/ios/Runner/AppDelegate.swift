import UIKit
import Flutter
import MicrosoftCognitiveServicesSpeech

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.example.talkready/azure_speech", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "transcribeAudio":
        guard let args = call.arguments as? [String: Any],
              let apiKey = args["apiKey"] as? String,
              let region = args["region"] as? String,
              let audioPath = args["audioPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing API key, region, or audio path", details: nil))
          return
        }
        self.transcribeAudio(apiKey: apiKey, region: region, audioPath: audioPath, result: result)
      case "assessPronunciation":
        guard let args = call.arguments as? [String: Any],
              let apiKey = args["apiKey"] as? String,
              let region = args["region"] as? String,
              let audioPath = args["audioPath"] as? String,
              let referenceText = args["referenceText"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing API key, region, audio path, or reference text", details: nil))
          return
        }
        self.assessPronunciation(apiKey: apiKey, region: region, audioPath: audioPath, referenceText: referenceText, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func transcribeAudio(apiKey: String, region: String, audioPath: String, result: @escaping FlutterResult) {
    do {
      let config = try SPXSpeechConfiguration(subscription: apiKey, region: region)
      config.speechRecognitionLanguage = "en-US"
      let audioConfig = try SPXAudioConfiguration(fromWAVFileInput: audioPath)
      let recognizer = try SPXSpeechRecognizer(speechConfiguration: config, audioConfiguration: audioConfig)

      recognizer.recognizeOnce { (recognition: SPXSpeechRecognitionResult?) in
        if let reason = recognition?.reason, reason == .recognizedSpeech {
          result(recognition?.text)
        } else {
          result(FlutterError(code: "STT_FAILED", message: "Speech recognition failed", details: recognition?.reason.rawValue))
        }
      }
    } catch {
      result(FlutterError(code: "STT_ERROR", message: "Error during transcription: \(error)", details: nil))
    }
  }

  private func assessPronunciation(apiKey: String, region: String, audioPath: String, referenceText: String, result: @escaping FlutterResult) {
    do {
      let config = try SPXSpeechConfiguration(subscription: apiKey, region: region)
      config.speechRecognitionLanguage = "en-US"
      let audioConfig = try SPXAudioConfiguration(fromWAVFileInput: audioPath)
      let recognizer = try SPXSpeechRecognizer(speechConfiguration: config, audioConfiguration: audioConfig)
      let pronConfig = try SPXPronunciationAssessmentConfiguration(referenceText, gradingSystem: .hundredMark, granularity: .phoneme)

      try pronConfig.apply(to: recognizer)
      recognizer.recognizeOnce { (recognition: SPXSpeechRecognitionResult?) in
        if let reason = recognition?.reason, reason == .recognizedSpeech {
          let pronResult = SPXPronunciationAssessmentResult(fromResult: recognition)
          let feedback = "Pronunciation Feedback: Overall score: \(pronResult.pronunciationScore)/100. " +
                         "Accuracy: \(pronResult.accuracyScore)/100, Fluency: \(pronResult.fluencyScore)/100, " +
                         "Completeness: \(pronResult.completenessScore)/100. Word-level tips: " +
                         pronResult.words.map { w in
                            w.errorType == .none ? "" : "'\(w.word)' (Accuracy: \(w.accuracyScore)/100, Issue: \(w.errorType.rawValue))"
                         }.joined().trimmingCharacters(in: .whitespaces)
          result(feedback)
        } else {
          result(FlutterError(code: "PRON_FAILED", message: "Pronunciation assessment failed", details: recognition?.reason.rawValue))
        }
      }
    } catch {
      result(FlutterError(code: "PRON_ERROR", message: "Error during pronunciation assessment: \(error)", details: nil))
    }
  }
}