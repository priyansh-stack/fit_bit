// functions/src/google_health/token_manager.ts
//
// Manages Google OAuth 2.0 tokens for the Google Health API.
// All tokens are stored in Google Secret Manager — NEVER in Firestore or Flutter.

import { SecretManagerServiceClient } from "@google-cloud/secret-manager";
import { OAuth2Client } from "google-auth-library";
import * as admin from "firebase-admin";

const secretClient = new SecretManagerServiceClient();

const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT_ID || process.env.GCLOUD_PROJECT || "";
const CLIENT_ID = process.env.GOOGLE_CLIENT_ID || "";
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || "";
const REDIRECT_URI = process.env.GOOGLE_REDIRECT_URI || "";

// Google Health API v4 OAuth scopes (verified August 2026)
export const HEALTH_SCOPES = [
  "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
  "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
  "https://www.googleapis.com/auth/googlehealth.settings.readonly",
];

/** Returns the Secret Manager path for a user's refresh token. */
function secretName(uid: string): string {
  return `projects/${PROJECT_ID}/secrets/health-token-${uid}/versions/latest`;
}

/** Returns the Secret Manager secret resource name (without version). */
function secretResourceName(uid: string): string {
  return `projects/${PROJECT_ID}/secrets/health-token-${uid}`;
}

/** Stores a refresh token in Secret Manager for a given Firebase UID. */
export async function storeRefreshToken(uid: string, refreshToken: string): Promise<void> {
  const parent = `projects/${PROJECT_ID}`;
  const secretId = `health-token-${uid}`;
  const encoded = Buffer.from(refreshToken, "utf8");

  // Check if secret already exists; create if not
  try {
    await secretClient.addSecretVersion({
      parent: secretResourceName(uid),
      payload: { data: encoded },
    });
  } catch {
    // Secret doesn't exist — create it first
    await secretClient.createSecret({
      parent,
      secretId,
      secret: {
        replication: { automatic: {} },
      },
    });
    await secretClient.addSecretVersion({
      parent: secretResourceName(uid),
      payload: { data: encoded },
    });
  }
}

/** Retrieves the stored refresh token from Secret Manager. Returns null if not found. */
export async function getRefreshToken(uid: string): Promise<string | null> {
  try {
    const [version] = await secretClient.accessSecretVersion({
      name: secretName(uid),
    });
    const payload = version.payload?.data;
    if (!payload) return null;
    return Buffer.from(payload as Uint8Array).toString("utf8");
  } catch {
    return null;
  }
}

/** Deletes the stored refresh token from Secret Manager. */
export async function deleteRefreshToken(uid: string): Promise<void> {
  try {
    await secretClient.deleteSecret({ name: secretResourceName(uid) });
  } catch {
    // Ignore if not found
  }
}

/** Creates an OAuth2Client with the stored refresh token and returns a valid access token. */
export async function getValidAccessToken(uid: string): Promise<string> {
  const refreshToken = await getRefreshToken(uid);
  if (!refreshToken) {
    throw new Error("HEALTH_NOT_CONNECTED");
  }

  const oauth2Client = new OAuth2Client(CLIENT_ID, CLIENT_SECRET, REDIRECT_URI);
  oauth2Client.setCredentials({ refresh_token: refreshToken });

  const { credentials } = await oauth2Client.refreshAccessToken();
  if (!credentials.access_token) {
    // Token revoked or expired — mark connection as disconnected
    await markConnectionDisconnected(uid, "Token refresh failed. Please reconnect.");
    throw new Error("HEALTH_TOKEN_REVOKED");
  }

  // Update refresh token if a new one was issued
  if (credentials.refresh_token && credentials.refresh_token !== refreshToken) {
    await storeRefreshToken(uid, credentials.refresh_token);
  }

  return credentials.access_token;
}

/** Builds the authorization URL for the Google Health OAuth flow. */
export function buildAuthorizationUrl(uid: string, state: string): string {
  const oauth2Client = new OAuth2Client(CLIENT_ID, CLIENT_SECRET, REDIRECT_URI);
  return oauth2Client.generateAuthUrl({
    access_type: "offline",
    scope: HEALTH_SCOPES,
    state,
    prompt: "consent", // Force consent to always get refresh_token
    include_granted_scopes: true,
  });
}

/** Exchanges an authorization code for tokens. Returns access + refresh tokens. */
export async function exchangeCodeForTokens(code: string): Promise<{
  accessToken: string;
  refreshToken: string;
  grantedScopes: string[];
}> {
  const oauth2Client = new OAuth2Client(CLIENT_ID, CLIENT_SECRET, REDIRECT_URI);
  const { tokens } = await oauth2Client.getToken(code);

  if (!tokens.access_token || !tokens.refresh_token) {
    throw new Error("TOKEN_EXCHANGE_FAILED");
  }

  const grantedScopes = (tokens.scope || "").split(" ").filter(Boolean);

  return {
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,
    grantedScopes,
  };
}

async function markConnectionDisconnected(uid: string, reason: string): Promise<void> {
  const db = admin.firestore();
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
      errorMessage: reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await db.collection("users").doc(uid).update({
    healthConnected: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
