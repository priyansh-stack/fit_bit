// functions/src/webhooks/webhook_handler.ts
//
// Handles Google Health API webhook (subscription) notifications.
// Security: verifies ECDSA P256 signature using Google's public keyset.
// Key rotation: fetches keyset dynamically (rotates every 30 days).
//
// Verified endpoint (Aug 2026):
//   Public keyset: https://www.gstatic.com/googlehealthapi/webhooks/webhooks_public_keyset.json
//   Signature header: GOOGLE-HEALTH-API-SIGNATURE
//   Algorithm: ECDSA NIST P256

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { createVerify } from "crypto";
import * as crypto from "crypto";
import axios from "axios";
import { syncIncremental } from "../sync/sync_service";

const PUBLIC_KEYSET_URL =
  "https://www.gstatic.com/googlehealthapi/webhooks/webhooks_public_keyset.json";
const WEBHOOK_SIGNATURE_HEADER = "google-health-api-signature";

// Cache the public keyset for 1 hour
let cachedKeyset: GoogleKeyset | null = null;
let keysetFetchedAt = 0;
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

interface GoogleKey {
  kty: string;
  crv: string;
  x: string;
  y: string;
  use: string;
  kid?: string;
}

interface GoogleKeyset {
  keys: GoogleKey[];
}

async function getPublicKeyset(): Promise<GoogleKeyset> {
  const now = Date.now();
  if (cachedKeyset && now - keysetFetchedAt < CACHE_TTL_MS) {
    return cachedKeyset;
  }

  const res = await axios.get<GoogleKeyset>(PUBLIC_KEYSET_URL, { timeout: 5000 });
  cachedKeyset = res.data;
  keysetFetchedAt = now;
  return cachedKeyset;
}

/** Verifies the ECDSA P256 signature of a webhook payload. */
async function verifyWebhookSignature(
  rawBody: Buffer,
  signatureB64: string
): Promise<boolean> {
  try {
    const keyset = await getPublicKeyset();
    const signature = Buffer.from(signatureB64, "base64");

    for (const key of keyset.keys) {
      if (key.kty !== "EC" || key.crv !== "P-256") continue;

      // Convert JWK to PEM for Node.js crypto
      const jwk = { kty: key.kty, crv: key.crv, x: key.x, y: key.y };
      try {
        const { createPublicKey } = await import("crypto");
        const jwkInput: crypto.JsonWebKeyInput = { key: jwk as crypto.JsonWebKey, format: "jwk" };
        const publicKey = createPublicKey(jwkInput);
        const verifier = createVerify("SHA256");
        verifier.update(rawBody);
        if (verifier.verify(publicKey, signature)) {
          return true;
        }
      } catch {
        continue; // Try next key
      }
    }

    return false;
  } catch (err) {
    functions.logger.error("Webhook signature verification failed", { err });
    return false;
  }
}

/**
 * handleGoogleHealthWebhook (HTTPS)
 *
 * Receives POST notifications from Google Health API subscriptions.
 * Verifies the ECDSA signature, then triggers an incremental sync
 * for the affected user. Idempotent.
 *
 * Also handles Google's endpoint verification challenge (GET request).
 */
export const handleGoogleHealthWebhook = functions.https.onRequest(
  async (req, res) => {
    // Endpoint verification challenge (GET) — Google sends this to verify the endpoint
    if (req.method === "GET") {
      const challenge = req.query["x-goog-channel-token"] as string;
      if (challenge) {
        res.status(200).send(challenge);
      } else {
        res.status(200).send("OK");
      }
      return;
    }

    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // Verify ECDSA signature
    const signatureHeader = req.headers[WEBHOOK_SIGNATURE_HEADER] as string | undefined;
    if (!signatureHeader) {
      functions.logger.warn("Webhook received without signature header");
      res.status(401).send("Missing signature");
      return;
    }

    const rawBody = (req as unknown as { rawBody: Buffer }).rawBody;
    if (!rawBody) {
      functions.logger.error("Raw body unavailable — ensure rawBody middleware is enabled");
      res.status(400).send("Bad request");
      return;
    }

    const isValid = await verifyWebhookSignature(rawBody, signatureHeader);
    if (!isValid) {
      functions.logger.warn("Webhook signature verification failed");
      res.status(401).send("Invalid signature");
      return;
    }

    // Parse notification payload
    let notification: Record<string, unknown>;
    try {
      notification = JSON.parse(rawBody.toString("utf8"));
    } catch {
      res.status(400).send("Invalid JSON");
      return;
    }

    functions.logger.info("Webhook received", {
      dataType: notification.dataType,
      userId: notification.userId ? "[redacted]" : undefined,
    });

    // Find the Firebase user by Google Health userId
    const healthUserId = notification.userId as string | undefined;
    if (!healthUserId) {
      res.status(200).send("No userId in notification");
      return;
    }

    // Look up the Firebase UID from the connection document
    const db = admin.firestore();
    const connSnap = await db
      .collectionGroup("connections")
      .where("healthUserId", "==", healthUserId)
      .where("status", "==", "active")
      .limit(1)
      .get();

    if (connSnap.empty) {
      functions.logger.info("No active connection for healthUserId", {
        healthUserId: "[redacted]",
      });
      res.status(200).send("No matching user");
      return;
    }

    const connDoc = connSnap.docs[0];
    const uid = connDoc.ref.parent.parent?.id;

    if (!uid) {
      res.status(200).send("Could not determine UID");
      return;
    }

    // Idempotency check: use notification ID to avoid duplicate syncs
    const notificationId = notification.notificationId as string | undefined;
    if (notificationId) {
      const idempotencyRef = db
        .collection("_webhookEvents")
        .doc(notificationId);
      const existing = await idempotencyRef.get();
      if (existing.exists) {
        res.status(200).send("Already processed");
        return;
      }
      await idempotencyRef.set({
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        uid,
        dataType: notification.dataType,
      });
    }

    // Respond immediately before triggering sync (webhook must respond < 10s)
    res.status(200).send("Accepted");

    // Trigger incremental sync asynchronously
    try {
      await syncIncremental(uid);
    } catch (err) {
      functions.logger.error("Sync triggered by webhook failed", { uid, err });
    }
  }
);
