package com.example.talkready_mobile

import com.microsoft.cognitiveservices.speech.*
import com.microsoft.cognitiveservices.speech.audio.AudioConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val channel = "com.example.talkready/azure_speech"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "transcribeAudio" -> {
                    val apiKey = call.argument<String>("apiKey")
                    val region = call.argument<String>("region")
                    val audioPath = call.argument<String>("audioPath")
                    transcribeAudio(apiKey, region, audioPath, result)
                }
                "assessPronunciation" -> {
                    val apiKey = call.argument<String>("apiKey")
                    val region = call.argument<String>("region")
                    val audioPath = call.argument<String>("audioPath")
                    val referenceText = call.argument<String>("referenceText")
                    assessPronunciation(apiKey, region, audioPath, referenceText, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun transcribeAudio(apiKey: String?, region: String?, audioPath: String?, result: MethodChannel.Result) {
        if (apiKey == null || region == null || audioPath == null) {
            result.error("INVALID_ARGS", "Missing API key, region, or audio path", null)
            return
        }
        if (!File(audioPath).exists()) {
            result.error("FILE_ERROR", "Audio file does not exist: $audioPath", null)
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            var config: SpeechConfig? = null
            var recognizer: SpeechRecognizer? = null
            try {
                config = SpeechConfig.fromSubscription(apiKey, region)
                config.speechRecognitionLanguage = "en-US"
                val audioConfig = AudioConfig.fromWavFileInput(audioPath)
                recognizer = SpeechRecognizer(config, audioConfig)

                val recognition = recognizer?.recognizeOnceAsync()?.get()
                withContext(Dispatchers.Main) {
                    if (recognition?.reason == ResultReason.RecognizedSpeech) {
                        result.success(recognition.text)
                    } else {
                        result.error("STT_FAILED", "Speech recognition failed: ${recognition?.reason}", null)
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("STT_EXCEPTION", "Transcription error: ${e.message}", null)
                }
            } finally {
                recognizer?.close()
                config?.close()
            }
        }
    }

    private fun assessPronunciation(apiKey: String?, region: String?, audioPath: String?, referenceText: String?, result: MethodChannel.Result) {
        if (apiKey == null || region == null || audioPath == null || referenceText == null) {
            result.error("INVALID_ARGS", "Missing API key, region, audio path, or reference text", null)
            return
        }
        if (!File(audioPath).exists()) {
            result.error("FILE_ERROR", "Audio file does not exist: $audioPath", null)
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            var config: SpeechConfig? = null
            var pronConfig: PronunciationAssessmentConfig? = null
            var recognizer: SpeechRecognizer? = null
            try {
                config = SpeechConfig.fromSubscription(apiKey, region)
                config.speechRecognitionLanguage = "en-US"
                val audioConfig = AudioConfig.fromWavFileInput(audioPath)
                recognizer = SpeechRecognizer(config, audioConfig)

                // Create pronunciation assessment config
                pronConfig = PronunciationAssessmentConfig(
                    referenceText,
                    PronunciationAssessmentGradingSystem.HundredMark,
                    PronunciationAssessmentGranularity.Phoneme
                )
                pronConfig.applyTo(recognizer)

                val recognition = recognizer?.recognizeOnceAsync()?.get()
                withContext(Dispatchers.Main) {
                    if (recognition?.reason == ResultReason.RecognizedSpeech) {
                        val pronResult = PronunciationAssessmentResult.fromResult(recognition)
                        if (pronResult != null) {
                            val feedback = "Pronunciation Feedback: Overall score: ${pronResult.pronunciationScore}/100. " +
                                          "Accuracy: ${pronResult.accuracyScore}/100, Fluency: ${pronResult.fluencyScore}/100, " +
                                          "Completeness: ${pronResult.completenessScore}/100. Word-level tips: " +
                                          pronResult.words.joinToString { w ->
                                              if (w.errorType == "None") "" else "'${w.word}' (Accuracy: ${w.accuracyScore}/100, Issue: ${w.errorType})"
                                          }.trim()
                            result.success(feedback)
                        } else {
                            result.error("PRON_FAILED", "Pronunciation result unavailable", null)
                        }
                    } else {
                        result.error("PRON_FAILED", "Pronunciation assessment failed: ${recognition?.reason}", null)
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("PRON_EXCEPTION", "Pronunciation assessment error: ${e.message}", null)
                }
            } finally {
                recognizer?.close()
                pronConfig?.close()
                config?.close()
            }
        }
    }
}