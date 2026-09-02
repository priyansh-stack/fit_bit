// functions/src/google_health/oauth_handler.ts
//
// Handles the Google Health OAuth 2.0 authorization flow.
// The authorization code is exchanged server-side — Flutter never sees tokens.

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {
  buildAuthorizationUrl,
  exchangeCodeForTokens,
  storeRefreshToken,
  HEALTH_SCOPES,
} from "./token_manager";
import { GoogleHealthService } from "./google_health_service";

/**
 * startGoogleHealthAuth (Callable)
 * Returns the Google OAuth authorization URL to open in a browser.
 * Flutter opens this URL externally; the user grants permissions.
 */
export const startGoogleHealthAuth = functions.https.onCall(
  async (request) => {
    // Verify Firebase authentication
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to connect Google Health."
      );
    }

    const uid = request.auth.uid;

    // Use uid as state to correlate the callback
    const state = Buffer.from(JSON.stringify({ uid })).toString("base64url");
    const url = buildAuthorizationUrl(uid, state);

    return { authorizationUrl: url };
  }
);

/**
 * googleHealthOAuthCallback (HTTPS)
 * Receives the OAuth redirect from Google after user grants permission.
 * Exchanges the code for tokens, stores the refresh token securely,
 * updates Firestore, then redirects to the app deep-link.
 */
export const googleHealthOAuthCallback = functions.https.onRequest(
  async (req, res) => {
    const { code, state, error } = req.query as Record<string, string>;

    const APP_DEEP_LINK = "com.healthdash.fitbitdash://oauth-callback/";

    if (error) {
      res.redirect(`${APP_DEEP_LINK}?error=${encodeURIComponent(error)}`);
      return;
    }

    if (!code || !state) {
      res.redirect(`${APP_DEEP_LINK}?error=missing_params`);
      return;
    }

    let uid: string;
    try {
      const stateData = JSON.parse(Buffer.from(state, "base64url").toString());
      uid = stateData.uid;
      if (!uid) throw new Error("Missing uid in state");
    } catch {
      res.redirect(`${APP_DEEP_LINK}?error=invalid_state`);
      return;
    }

    try {
      // Exchange code for tokens
      const { accessToken, refreshToken, grantedScopes } =
        await exchangeCodeForTokens(code);

      // Check that required scopes were granted
      const requiredScopes = HEALTH_SCOPES;
      const missingScopes = requiredScopes.filter(
        (s) => !grantedScopes.includes(s)
      );

      if (missingScopes.length > 0) {
        functions.logger.warn("Partial consent", { uid, missingScopes });
        // Partial consent: redirect with warning but still proceed
        // (user can reconnect to grant all scopes)
      }

      // Store refresh token securely in Secret Manager
      await storeRefreshToken(uid, refreshToken);

      // Get Google Health user identity
      const healthService = new GoogleHealthService(accessToken);
      let healthUserId: string | undefined;
      let displayName: string | undefined;
      try {
        const identity = await healthService.getIdentity();
        healthUserId = identity.userId;
        const profile = await healthService.getProfile();
        displayName = profile.displayName;
      } catch {
        // Non-fatal — connection still works without identity
      }

      // Write connection document to Firestore
      const db = admin.firestore();
      const connectionRef = db
        .collection("users")
        .doc(uid)
        .collection("connections")
        .doc(); // auto-ID

      const now = admin.firestore.FieldValue.serverTimestamp();
      await connectionRef.set({
        status: "active",
        provider: "google_health",
        healthUserId: healthUserId || null,
        displayName: displayName || null,
        connectedAt: now,
        lastSyncAt: null,
        grantedScopes,
        missingScopes,
      });

      // Mark user as health-connected
      await db.collection("users").doc(uid).update({
        healthConnected: true,
        updatedAt: now,
      });

      // Write sync checkpoints initialized to null (will be set on first sync)
      const syncTypes = ["activity", "heartRate", "sleep", "metrics"];
      const batch = db.batch();
      for (const syncType of syncTypes) {
        const ref = db
          .collection("users")
          .doc(uid)
          .collection("sync")
          .doc(syncType);
        batch.set(ref, { syncType, status: "pending" }, { merge: true });
      }
      await batch.commit();

      res.redirect(`${APP_DEEP_LINK}?connected=true`);
    } catch (err) {
      functions.logger.error("OAuth callback failed", { uid, err });
      res.redirect(
        `${APP_DEEP_LINK}?error=${encodeURIComponent(
          "oauth_exchange_failed"
        )}`
      );
    }
  }
);

/**
 * getHealthConnectionStatus (Callable)
 * Returns the current connection status from Firestore.
 */
export const getHealthConnectionStatus = functions.https.onCall(
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Not authenticated.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("connections")
      .where("provider", "==", "google_health")
      .limit(1)
      .get();

    if (snap.empty) {
      return { connected: false, status: "disconnected" };
    }

    const conn = snap.docs[0].data();
    return {
      connected: conn.status === "active",
      status: conn.status,
      lastSyncAt: conn.lastSyncAt?.toDate()?.toISOString() || null,
      healthUserId: conn.healthUserId || null,
    };
  }
);

/**
 * disconnectGoogleHealth (Callable)
 * Revokes the OAuth token, deletes from Secret Manager, and marks disconnected.
 */
export const disconnectGoogleHealth = functions.https.onCall(
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Not authenticated.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    // Revoke token if possible
    try {
      const { getRefreshToken, deleteRefreshToken } = await import("./token_manager");
      const refreshToken = await getRefreshToken(uid);
      if (refreshToken) {
        // Google token revocation endpoint
        await import("axios").then(({ default: axios }) =>
          axios.post(
            `https://oauth2.googleapis.com/revoke?token=${encodeURIComponent(
              refreshToken
            )}`
          ).catch(() => {}) // Non-fatal if revocation fails
        );
        await deleteRefreshToken(uid);
      }
    } catch {
      // Continue with disconnect even if revocation fails
    }

    // Mark connection as disconnected in Firestore
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("connections")
      .where("provider", "==", "google_health")
      .limit(1)
      .get();

    if (!snap.empty) {
      await snap.docs[0].ref.update({
        status: "disconnected",
        disconnectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await db.collection("users").doc(uid).update({
      healthConnected: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  }
);
