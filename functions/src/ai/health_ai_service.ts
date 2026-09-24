// functions/src/ai/health_ai_service.ts
//
// Phase 2 Production AI Proxy for Health Coach & Vitality Copilot
// 100% Server-side secret key isolation (API key never exposed to client)
// Firestore chat logging & daily rate limiting per authenticated user

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import axios from "axios";

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "";

const PRIMARY_MODEL = "gemini-3.6-flash";
const FALLBACK_MODEL = "gemini-3.5-flash-lite";
const DAILY_CHAT_QUOTA = 30; // Max AI queries per day per user

export interface ChatRequestPayload {
  prompt: string;
  history?: Array<{ role: string; parts: Array<{ text: string }> }>;
  systemInstruction?: string;
  isPro?: boolean;
  groundedMetrics?: Record<string, unknown>;
}

export interface ChatResponsePayload {
  reply: string;
  model: string;
  remainingDailyQuota: number;
}

/**
 * Executes a Gemini prompt with automatic fallback
 */
async function callGemini(
  prompt: string,
  history: Array<{ role: string; parts: Array<{ text: string }> }>,
  systemInstruction: string,
  modelName: string
): Promise<{ text: string; modelUsed: string }> {
  const contents = [...history, { role: "user", parts: [{ text: prompt }] }];

  const requestBody = {
    system_instruction: systemInstruction
      ? { parts: [{ text: systemInstruction }] }
      : undefined,
    contents,
    generationConfig: {
      temperature: 0.7,
      topP: 0.95,
      maxOutputTokens: 1024,
    },
    safetySettings: [
      { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
      { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
      { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
      { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
    ],
  };

  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${GEMINI_API_KEY}`;
    const response = await axios.post(url, requestBody, {
      headers: { "Content-Type": "application/json" },
      timeout: 25000,
    });

    const candidates = response.data?.candidates;
    if (candidates && candidates.length > 0) {
      const text = candidates[0].content?.parts?.[0]?.text;
      if (text) {
        return { text: text.trim(), modelUsed: modelName };
      }
    }
    throw new Error("No candidate returned from Gemini");
  } catch (err: unknown) {
    functions.logger.warn(`Model ${modelName} failed, attempting fallback to ${FALLBACK_MODEL}`, {
      err: (err as Error).message,
    });

    // Fallback to flash-lite
    const fallbackUrl = `https://generativelanguage.googleapis.com/v1beta/models/${FALLBACK_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
    const fallbackResponse = await axios.post(fallbackUrl, requestBody, {
      headers: { "Content-Type": "application/json" },
      timeout: 25000,
    });

    const candidates = fallbackResponse.data?.candidates;
    if (candidates && candidates.length > 0) {
      const text = candidates[0].content?.parts?.[0]?.text;
      if (text) {
        return { text: text.trim(), modelUsed: FALLBACK_MODEL };
      }
    }
    throw new Error("Gemini AI service unavailable");
  }
}

/**
 * Handles AI chat logic with authentication, quota management, and Firestore logging
 */
export async function processHealthAiChat(
  uid: string,
  payload: ChatRequestPayload
): Promise<ChatResponsePayload> {
  const db = admin.firestore();
  const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
  const usageRef = db.doc(`users/${uid}/ai_usage/${today}`);

  // Check & increment daily usage quota in Firestore
  const usageSnap = await usageRef.get();
  const currentCount = usageSnap.exists ? usageSnap.data()?.count || 0 : 0;

  if (currentCount >= DAILY_CHAT_QUOTA) {
    throw new functions.https.HttpsError(
      "resource-exhausted",
      `Daily AI coaching limit reached (${DAILY_CHAT_QUOTA} chats/day). Resets at midnight UTC.`
    );
  }

  const systemPrompt =
    payload.systemInstruction ||
    "You are an expert clinical AI health coach analyzing fitness and vitality metrics.";

  const history = payload.history || [];
  const modelToUse = PRIMARY_MODEL;

  // Call Gemini through server proxy
  const { text: replyText, modelUsed } = await callGemini(
    payload.prompt,
    history,
    systemPrompt,
    modelToUse
  );

  // Update daily quota usage count
  await usageRef.set(
    {
      count: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Log conversation to Firestore database: users/{uid}/ai_conversations
  await db.collection(`users/${uid}/ai_conversations`).add({
    prompt: payload.prompt,
    reply: replyText,
    model: modelUsed,
    groundedMetrics: payload.groundedMetrics || null,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    reply: replyText,
    model: modelUsed,
    remainingDailyQuota: DAILY_CHAT_QUOTA - (currentCount + 1),
  };
}
