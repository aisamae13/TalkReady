const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");

// Only initialize once
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Sanitizes text by replacing smart quotes and special characters with standard equivalents.
 * @param {string} text The input text to sanitize.
 * @return {string} The sanitized text.
 */
const sanitizeText = (text) => {
  if (!text) return "";
  return text
      .replace(/[\u2018\u2019]/g, "'")
      .replace(/[\u201C\u201D]/g, "\"")
      .replace(/[\u2013\u2014]/g, "-")
      .replace(/\u2026/g, "...")
      .trim();
};

/**
 * Generates contextual analysis based on the transcript and prompt text.
 * @param {string} transcript The transcribed speech from the audio.
 * @param {string} promptText The original prompt the user was responding to.
 * @param {string} referenceText The ideal reference answer text.
 * @param {object} pronAssessment The pronunciation assessment data from Azure.
 * @param {string} context The overall context for the evaluation (e.g., "customer_service").
 * @return {object} An object containing detailed contextual analysis results.
 */
function generateContextualAnalysis(
    transcript,
    promptText,
    referenceText,
    pronAssessment,
    context,
) {
  const transcriptLower = transcript.toLowerCase().trim();
  const promptLower = promptText.toLowerCase();
  const referenceLower = (referenceText || "").toLowerCase();

  const transcriptWords = transcriptLower
      .split(/\s+/)
      .filter((w) => w.length > 0);
  const promptWords = promptLower.split(/\s+/).filter((w) => w.length > 3);
  const referenceWords = referenceLower
      .split(/\s+/)
      .filter((w) => w.length > 3);

  const matchedPromptWords = promptWords.filter((word) =>
    transcriptWords.some((tw) => tw.includes(word) || word.includes(tw)),
  );
  const relevanceScore = Math.min(
      100,
      Math.round(
          (matchedPromptWords.length / Math.max(promptWords.length, 1)) * 100,
      ),
  );

  const wordCount = transcriptWords.length;
  let completenessScore = 0;
  if (wordCount >= 30) completenessScore = 100;
  else if (wordCount >= 20) completenessScore = 85;
  else if (wordCount >= 10) completenessScore = 70;
  else completenessScore = Math.round((wordCount / 10) * 70);

  const fillerWords = [
    "um", "uh", "like", "you know", "basically", "actually", "literally",
  ];
  let fillerCount = 0;
  fillerWords.forEach((filler) => {
    const matches = transcriptLower.match(new RegExp(`\\b${filler}\\b`, "g"));
    if (matches) fillerCount += matches.length;
  });
  const professionalismScore = Math.max(0, 100 - fillerCount * 15);

  let accuracyScore = 80;
  if (referenceWords.length > 0) {
    const matchedRefWords = referenceWords.filter((word) =>
      transcriptWords.some((tw) => tw.includes(word) || word.includes(tw)),
    );
    accuracyScore = Math.min(
        100,
        Math.round((matchedRefWords.length / referenceWords.length) * 100),
    );
  }

  const clarityScore = Math.round(pronAssessment.AccuracyScore || 80);

  const scores = {
    relevance: relevanceScore,
    completeness: completenessScore,
    professionalism: professionalismScore,
    accuracy: accuracyScore,
    clarity: clarityScore,
  };

  const strengths = [];
  const improvementAreas = [];

  if (relevanceScore >= 70) {
    strengths.push("Response directly addresses the prompt");
  } else {
    improvementAreas.push(
        "Try to address all aspects of the prompt more directly",
    );
  }

  if (completenessScore >= 80) {
    strengths.push("Response is well-developed and complete");
  } else if (wordCount < 15) {
    improvementAreas.push(
        "Provide more detailed responses (aim for 20-30 words minimum)",
    );
  }

  if (professionalismScore >= 80) {
    strengths.push(
        "Professional and fluent delivery with minimal filler words",
    );
  } else if (fillerCount > 2) {
    improvementAreas.push(
        "Reduce filler words like \"um\", \"uh\", \"like\" for more professional speech",
    );
  }

  if (clarityScore >= 80) {
    strengths.push("Clear pronunciation and articulation");
  } else {
    improvementAreas.push("Focus on clearer pronunciation and articulation");
  }

  if (accuracyScore >= 70 && referenceWords.length > 0) {
    strengths.push("Response aligns well with expected content");
  } else if (referenceWords.length > 0) {
    improvementAreas.push(
        "Try to include key points from the reference answer",
    );
  }

  const avgScore = Math.round(
      (relevanceScore +
      completenessScore +
      professionalismScore +
      clarityScore +
      accuracyScore) /
      5,
  );

  let overallAssessment = "";
  if (avgScore >= 85) {
    overallAssessment = "Excellent response! The student demonstrates strong communication skills with clear articulation and relevant content.";
  } else if (avgScore >= 70) {
    overallAssessment = "Good response overall. The student shows solid understanding with room for minor improvements in delivery or content.";
  } else if (avgScore >= 50) {
    overallAssessment = "Adequate response with several areas for improvement. The student should focus on clarity, completeness, and relevance.";
  } else {
    overallAssessment = "The response needs significant improvement. Focus on addressing the prompt clearly and completely.";
  }

  let suggestion = "Continue practicing to improve customer service communication skills. ";
  if (wordCount < 15) {
    suggestion += "Try to give more detailed, complete responses. ";
  }
  if (fillerCount > 2) {
    suggestion += "Practice speaking without filler words by pausing briefly instead. ";
  }
  if (relevanceScore < 70) {
    suggestion += "Make sure to address all parts of the question or scenario given. ";
  }

  const appropriateAlternatives = generateAlternativeResponses(context, promptText);

  return {
    scores,
    strengths,
    improvementAreas,
    overallAssessment,
    suggestion,
    appropriateAlternatives,
  };
}

/**
 * Generates sample alternative responses based on the evaluation context.
 * @param {string} context The evaluation context (e.g., "greeting", "complaint").
 * @param {string} promptText The original prompt text.
 * @return {Array<string>} An array of appropriate alternative responses.
 */
function generateAlternativeResponses(context, promptText) {
  const alternatives = [];

  if (
    (context && context.toLowerCase().includes("greeting")) ||
    promptText.toLowerCase().includes("greet")
  ) {
    alternatives.push(
        "Good morning! Welcome to our store. How may I assist you today?",
        "Hello! Thank you for visiting us. What can I help you with?",
        "Hi there! It's great to see you. How can I make your day better?",
    );
  } else if (
    (context && context.toLowerCase().includes("complaint")) ||
    promptText.toLowerCase().includes("issue")
  ) {
    alternatives.push(
        "I sincerely apologize for the inconvenience. Let me help resolve this right away.",
        "I understand your frustration, and I'm here to help. Let's fix this together.",
        "Thank you for bringing this to our attention. I'll do everything I can to make this right.",
    );
  } else if (
    (context && context.toLowerCase().includes("help")) ||
    promptText.toLowerCase().includes("assist")
  ) {
    alternatives.push(
        "I'd be happy to help you with that. Let me explain your options.",
        "Absolutely! I can assist you with that. Here's what I can do for you.",
        "Of course! Let me guide you through this step by step.",
    );
  } else {
    alternatives.push(
        "Thank you for your question. I'm here to help you find the best solution.",
        "I appreciate you reaching out. Let me provide you with the information you need.",
        "That's a great question. Allow me to explain that for you clearly.",
    );
  }

  return alternatives;
}


exports.evaluateSpeaking = onCall(
    {
      secrets: ["AZURE_SPEECH_KEY", "AZURE_SPEECH_REGION"],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "User must be authenticated to evaluate speech.",
        );
      }

      const {audioUrl, promptText, referenceText, evaluationContext} =
        request.data;

      if (!audioUrl || !promptText) {
        throw new HttpsError(
            "invalid-argument",
            "Missing required fields: audioUrl and promptText are required",
        );
      }

      try {
        console.log("Starting speech evaluation for user:", request.auth.uid);

        const audioResponse = await axios.get(audioUrl, {
          responseType: "arraybuffer",
          timeout: 30000,
        });
        const audioBuffer = Buffer.from(audioResponse.data);
        console.log("Audio downloaded, size:", audioBuffer.length);

        // Extract just the PCM data from WAV (skip the header)
        // WAV header is typically 44 bytes
        let pcmData;
        if (audioBuffer.length > 44 &&
            audioBuffer.slice(0, 4).toString() === "RIFF") {
          // Find the 'data' chunk
          let dataOffset = 12; // Start after RIFF header
          while (dataOffset < audioBuffer.length - 8) {
            const chunkId = audioBuffer.slice(dataOffset, dataOffset + 4).toString();
            const chunkSize = audioBuffer.readUInt32LE(dataOffset + 4);

            if (chunkId === "data") {
              pcmData = audioBuffer.slice(dataOffset + 8, dataOffset + 8 + chunkSize);
              console.log("Extracted PCM data, size:", pcmData.length);
              break;
            }
            dataOffset += 8 + chunkSize;
          }
        }

        if (!pcmData) {
          throw new HttpsError(
              "invalid-argument",
              "Could not extract PCM data from audio file",
          );
        }

        const AZURE_SPEECH_API_KEY = process.env.AZURE_SPEECH_KEY;
        const AZURE_SPEECH_REGION = process.env.AZURE_SPEECH_REGION;

        if (!AZURE_SPEECH_API_KEY || !AZURE_SPEECH_REGION) {
          throw new HttpsError(
              "failed-precondition",
              "Azure credentials not configured",
          );
        }

        const endpoint = `https://${AZURE_SPEECH_REGION}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1`;

        const params = new URLSearchParams({
          language: "en-US",
          format: "detailed",
        });

        const pronAssessmentParams = {
          ReferenceText: sanitizeText(referenceText || promptText),
          GradingSystem: "HundredMark",
          Granularity: "Phoneme",
          Dimension: "Comprehensive",
          EnableMiscue: true,
        };

        console.log("Calling Azure Speech API with raw PCM data...");
        const azureResponse = await axios.post(
            `${endpoint}?${params.toString()}`,
            pcmData,
            {
              headers: {
                "Ocp-Apim-Subscription-Key": AZURE_SPEECH_API_KEY,
                "Content-Type": "audio/pcm; samplerate=16000; bitdepth=16; channels=1",
                "Accept": "application/json",
                "Pronunciation-Assessment": JSON.stringify(pronAssessmentParams),
              },
              timeout: 30000,
            },
        );

        const azureData = azureResponse.data;
        console.log("Azure API response received");

        const bestResult = azureData.NBest && azureData.NBest[0];
        if (!bestResult) {
          throw new HttpsError(
              "not-found",
              "No transcription results found. Audio may be unclear or too short.",
          );
        }

        const transcript = bestResult.Display || bestResult.Lexical || "";
        const pronAssessment = bestResult.PronunciationAssessment || {};

        const audioQuality = {
          speechClarity: Math.min(
              100,
              Math.round(pronAssessment.AccuracyScore || 0),
          ),
          speechFluency: Math.min(
              100,
              Math.round(pronAssessment.FluencyScore || 0),
          ),
          prosody: Math.min(100, Math.round(pronAssessment.ProsodyScore || 0)),
        };

        const contextualAnalysis = generateContextualAnalysis(
            transcript,
            promptText,
            referenceText,
            pronAssessment,
            evaluationContext,
        );

        const overallScore = Math.round(
            (audioQuality.speechClarity +
          audioQuality.speechFluency +
          audioQuality.prosody +
          ((contextualAnalysis.scores &&
            contextualAnalysis.scores.relevance) ||
            0) +
          ((contextualAnalysis.scores &&
            contextualAnalysis.scores.completeness) ||
            0)) /
          5,
        );

        console.log("Evaluation completed successfully");

        return {
          transcript,
          audioQuality,
          contextualAnalysis,
          overallScore,
          evaluatedAt: admin.firestore.FieldValue.serverTimestamp(),
          evaluatedBy: "Azure Speech Service + Custom Analysis",
        };
      } catch (error) {
        console.error("Speech evaluation error:", error);

        if (error.response && error.response.data) {
          console.error("Azure API error details:", error.response.data);
        }

        throw new HttpsError(
            "internal",
            `Failed to evaluate speech: ${error.message}`,
        );
      }
    },
);
