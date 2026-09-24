// functions/src/index.ts
//
// Entry point — exports all Firebase Cloud Functions.
// Sensitive credentials are NEVER logged or returned to Flutter.

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

// Initialize Firebase Admin SDK once
admin.initializeApp();

// ─── OAuth / Connection ───────────────────────────────────────────────────────
export { startGoogleHealthAuth } from "./google_health/oauth_handler";
export { googleHealthOAuthCallback } from "./google_health/oauth_handler";
export { getHealthConnectionStatus } from "./google_health/oauth_handler";
export { disconnectGoogleHealth } from "./google_health/oauth_handler";

// ─── Webhook ─────────────────────────────────────────────────────────────────
export { handleGoogleHealthWebhook } from "./webhooks/webhook_handler";

// ─── Sync — Callable Functions ────────────────────────────────────────────────

import { syncIncremental, syncHistorical } from "./sync/sync_service";

/**
 * syncHealthData (Callable)
 * Triggers an incremental sync of the authenticated user's health data.
 */
export const syncHealthData = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .https.onCall(async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to sync health data."
      );
    }

    const uid = request.auth.uid;
    functions.logger.info("syncHealthData called", { uid });

    try {
      const result = await syncIncremental(uid);
      return result;
    } catch (err: unknown) {
      const message = (err as Error).message || "Sync failed";

      if (message.includes("HEALTH_TOKEN_REVOKED")) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "Your Google Health access has been revoked. Please reconnect."
        );
      }
      if (message.includes("HEALTH_NOT_CONNECTED")) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Google Health is not connected. Please connect your account."
        );
      }
      if (message.includes("HEALTH_RATE_LIMITED")) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "Google Health API rate limit reached. Please try again later."
        );
      }

      functions.logger.error("syncHealthData failed", { uid, err });
      throw new functions.https.HttpsError("internal", "Sync failed. Please try again.");
    }
  });

/**
 * syncHistoricalHealthData (Callable)
 * Fetches 90 days of historical health data. Called once after initial connection.
 */
export const syncHistoricalHealthData = functions
  .runWith({ timeoutSeconds: 300, memory: "1GB" })
  .https.onCall(async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    const uid = request.auth.uid;
    functions.logger.info("syncHistoricalHealthData called", { uid });

    try {
      const result = await syncHistorical(uid);
      return result;
    } catch (err: unknown) {
      const message = (err as Error).message || "";
      if (message.includes("HEALTH_TOKEN_REVOKED")) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "Google Health access was revoked. Please reconnect."
        );
      }
      functions.logger.error("syncHistoricalHealthData failed", { uid, err });
      throw new functions.https.HttpsError("internal", "Historical sync failed.");
    }
  });

// ─── AI Health Coach / Copilot Proxy ─────────────────────────────────────────

import { processHealthAiChat, ChatRequestPayload } from "./ai/health_ai_service";

/**
 * chatWithHealthAi (Callable)
 * Secure server-side Gemini AI proxy for Flutter clients with Firebase Auth.
 */
export const chatWithHealthAi = functions
  .runWith({ timeoutSeconds: 60, memory: "512MB" })
  .https.onCall(async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to consult the AI health coach."
      );
    }

    const uid = request.auth.uid;
    const data = request.data as ChatRequestPayload;

    if (!data || !data.prompt) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid prompt is required."
      );
    }

    functions.logger.info("chatWithHealthAi called", { uid });
    return await processHealthAiChat(uid, data);
  });

/**
 * chatWithHealthAiHttp (HTTPS REST)
 * Direct REST endpoint for authenticated clients via Authorization: Bearer <idToken>
 */
export const chatWithHealthAiHttp = functions
  .runWith({ timeoutSeconds: 60, memory: "512MB" })
  .https.onRequest(async (req, res) => {
    // CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).json({ error: "Missing or invalid Authorization header" });
      return;
    }

    const idToken = authHeader.split("Bearer ")[1];
    try {
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      const uid = decodedToken.uid;
      const data = req.body as ChatRequestPayload;

      if (!data || !data.prompt) {
        res.status(400).json({ error: "Missing prompt in request body" });
        return;
      }

      const result = await processHealthAiChat(uid, data);
      res.status(200).json(result);
    } catch (err: unknown) {
      functions.logger.error("chatWithHealthAiHttp error", { err });
      const message = (err as Error).message || "Internal error";
      res.status(500).json({ error: message });
    }
  });

