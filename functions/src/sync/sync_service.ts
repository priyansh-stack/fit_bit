// functions/src/sync/sync_service.ts
//
// Orchestrates Google Health API data sync into Firestore.
// Supports both initial (90-day) and incremental syncs.

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { GoogleHealthService, DailyRollUpRequest } from "../google_health/google_health_service";
import { getValidAccessToken } from "../google_health/token_manager";
import {
  normalizeHealthDaily,
  normalizeHeartRate,
  normalizeSleepSessions,
  normalizeExercise,
  normalizeHealthMetric,
} from "./data_normalizer";

const DATA_SOURCE_FAMILY = "google-wearables"; // Prefer Fitbit/Pixel wearable data
const MAX_BATCH_SIZE = 500;

export interface SyncResult {
  success: boolean;
  recordsWritten: number;
  syncedDate: string;
  errors: string[];
}

/**
 * Performs an incremental sync: fetches data since the last successful sync.
 */
export async function syncIncremental(uid: string): Promise<SyncResult> {
  const db = admin.firestore();
  const errors: string[] = [];
  let recordsWritten = 0;

  // Get last sync date from the activity sync checkpoint
  const activitySync = await db
    .collection("users")
    .doc(uid)
    .collection("sync")
    .doc("activity")
    .get();

  const today = new Date().toISOString().split("T")[0];
  const lastDate = activitySync.data()?.lastSuccessfulDate as string | undefined;
  // Start from 2 days before last sync (to catch late-arriving data)
  const startDate = lastDate
    ? subtractDays(lastDate, 2)
    : subtractDays(today, 7);

  const request: DailyRollUpRequest = {
    startDate,
    endDate: today,
    dataSourceFamily: DATA_SOURCE_FAMILY,
  };

  return _performSync(uid, request, errors, recordsWritten, today);
}

/**
 * Performs a full historical sync (90 days).
 */
export async function syncHistorical(uid: string): Promise<SyncResult> {
  const today = new Date().toISOString().split("T")[0];
  const startDate = subtractDays(today, 90);

  const request: DailyRollUpRequest = {
    startDate,
    endDate: today,
    dataSourceFamily: DATA_SOURCE_FAMILY,
  };

  return _performSync(uid, request, [], 0, today);
}

async function _performSync(
  uid: string,
  request: DailyRollUpRequest,
  errors: string[],
  recordsWritten: number,
  syncDate: string
): Promise<SyncResult> {
  const db = admin.firestore();

  // Get a valid access token (handles auto-refresh)
  let accessToken: string;
  try {
    accessToken = await getValidAccessToken(uid);
  } catch (err) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Google Health access is not authorized. Please reconnect."
    );
  }

  const health = new GoogleHealthService(accessToken);

  // ─── Fetch all daily data types in parallel ───────────────────────────────
  const [stepsData, distanceData, caloriesData, activeCalData, activeMinData,
    floorsData, restingHRData, sleepData] = await Promise.allSettled([
    health.getSteps(request),
    health.getDistance(request),
    health.getCalories(request),
    health.getActiveCalories(request),
    health.getActiveMinutes(request),
    health.getFloors(request),
    health.getRestingHeartRate(request),
    health.getSleep(request),
  ]);

  const get = <T>(r: PromiseSettledResult<T[]>, name: string): T[] => {
    if (r.status === "rejected") {
      const msg = r.reason?.message || "unknown";
      if (!msg.includes("NOT_FOUND") && !msg.includes("unavailable")) {
        errors.push(`${name}: ${msg}`);
      }
      return [];
    }
    return r.value;
  };

  const dailyMap = normalizeHealthDaily({
    steps: get(stepsData, "steps"),
    distance: get(distanceData, "distance"),
    calories: get(caloriesData, "calories"),
    activeCalories: get(activeCalData, "activeCalories"),
    activeMinutes: get(activeMinData, "activeMinutes"),
    floors: get(floorsData, "floors"),
    restingHR: get(restingHRData, "restingHR"),
    sleep: get(sleepData, "sleep"),
    dataSourceFamily: DATA_SOURCE_FAMILY,
  });

  // ─── Write healthDaily documents ─────────────────────────────────────────
  if (dailyMap.size > 0) {
    const chunks = chunked([...dailyMap.entries()], MAX_BATCH_SIZE);
    for (const chunk of chunks) {
      const batch = db.batch();
      for (const [date, doc] of chunk) {
        const ref = db
          .collection("users")
          .doc(uid)
          .collection("healthDaily")
          .doc(date);
        batch.set(ref, doc, { merge: true });
        recordsWritten++;
      }
      await batch.commit();
    }
  }

  // ─── Intraday heart rate ──────────────────────────────────────────────────
  try {
    const hrPoints = await health.getHeartRate({
      startTime: `${request.startDate}T00:00:00Z`,
      endTime: `${request.endDate}T23:59:59Z`,
      pageSize: 1000,
      dataSourceFamily: DATA_SOURCE_FAMILY,
    });

    const hrRecords = normalizeHeartRate(hrPoints, DATA_SOURCE_FAMILY);
    if (hrRecords.length > 0) {
      const chunks = chunked(hrRecords, MAX_BATCH_SIZE);
      for (const chunk of chunks) {
        const batch = db.batch();
        for (const rec of chunk) {
          const ref = db
            .collection("users")
            .doc(uid)
            .collection("heartRate")
            .doc(rec.timestamp.toMillis().toString());
          batch.set(ref, rec, { merge: true });
          recordsWritten++;
        }
        await batch.commit();
      }
    }
  } catch (err: unknown) {
    errors.push(`heartRate: ${(err as Error).message}`);
  }

  // ─── Sleep sessions (list endpoint) ──────────────────────────────────────
  try {
    const sleepPoints = await health.listDataPoints("sleep", {
      startTime: `${request.startDate}T00:00:00Z`,
      endTime: `${request.endDate}T23:59:59Z`,
      pageSize: 100,
      dataSourceFamily: DATA_SOURCE_FAMILY,
    });

    const sleepSessions = normalizeSleepSessions(sleepPoints.dataPoints, DATA_SOURCE_FAMILY);
    if (sleepSessions.length > 0) {
      const batch = db.batch();
      for (const session of sleepSessions) {
        const ref = db
          .collection("users")
          .doc(uid)
          .collection("sleep")
          .doc(`${session.date}-${session.startTime.toMillis()}`);
        batch.set(ref, session, { merge: true });
        recordsWritten++;
      }
      await batch.commit();
    }
  } catch (err: unknown) {
    errors.push(`sleep: ${(err as Error).message}`);
  }

  // ─── Exercise sessions ────────────────────────────────────────────────────
  try {
    const exercisePoints = await health.getExercise({
      startTime: `${request.startDate}T00:00:00Z`,
      endTime: `${request.endDate}T23:59:59Z`,
      pageSize: 100,
      dataSourceFamily: DATA_SOURCE_FAMILY,
    });

    const exercises = normalizeExercise(exercisePoints, DATA_SOURCE_FAMILY);
    if (exercises.length > 0) {
      const batch = db.batch();
      for (const ex of exercises) {
        const ref = db
          .collection("users")
          .doc(uid)
          .collection("exercise")
          .doc(`${ex.date}-${ex.startTime.toMillis()}`);
        batch.set(ref, ex, { merge: true });
        recordsWritten++;
      }
      await batch.commit();
    }
  } catch (err: unknown) {
    errors.push(`exercise: ${(err as Error).message}`);
  }

  // ─── Health metrics (SpO2, respiratory rate, weight, body fat) ───────────
  const metricFetches: Array<{ method: () => Promise<unknown[]>; type: string; unit: string }> = [
    { method: () => health.getSpO2({ startTime: `${request.startDate}T00:00:00Z`, endTime: `${request.endDate}T23:59:59Z`, pageSize: 200, dataSourceFamily: DATA_SOURCE_FAMILY }), type: "spo2", unit: "%" },
    { method: () => health.getRespiratoryRate({ startTime: `${request.startDate}T00:00:00Z`, endTime: `${request.endDate}T23:59:59Z`, pageSize: 200, dataSourceFamily: DATA_SOURCE_FAMILY }), type: "respiratoryRate", unit: "breaths/min" },
    { method: () => health.getWeight({ startDate: request.startDate, endDate: request.endDate, dataSourceFamily: DATA_SOURCE_FAMILY }), type: "weight", unit: "kg" },
    { method: () => health.getBodyFat({ startDate: request.startDate, endDate: request.endDate, dataSourceFamily: DATA_SOURCE_FAMILY }), type: "bodyFat", unit: "%" },
  ];

  for (const { method, type, unit } of metricFetches) {
    try {
      const pts = await method() as unknown[];
      const metrics = normalizeHealthMetric(
        pts as Parameters<typeof normalizeHealthMetric>[0],
        type,
        unit,
        DATA_SOURCE_FAMILY
      );
      if (metrics.length > 0) {
        const batch = db.batch();
        for (const m of metrics) {
          const ref = db
            .collection("users")
            .doc(uid)
            .collection("healthMetrics")
            .doc(`${m.type}-${m.date}`);
          batch.set(ref, m, { merge: true });
          recordsWritten++;
        }
        await batch.commit();
      }
    } catch {
      // Non-fatal — metric not available on this device
    }
  }

  // ─── Update sync checkpoints ─────────────────────────────────────────────
  const now = admin.firestore.FieldValue.serverTimestamp();
  const syncBatch = db.batch();

  const syncTypes = ["activity", "heartRate", "sleep", "metrics"];
  for (const syncType of syncTypes) {
    syncBatch.set(
      db.collection("users").doc(uid).collection("sync").doc(syncType),
      {
        syncType,
        lastSyncAt: now,
        lastSuccessfulDate: request.endDate,
        status: "success",
        recordsWritten,
        errorMessage: null,
      },
      { merge: true }
    );
  }

  // Update lastSyncAt on the connection document
  const connSnap = await db
    .collection("users")
    .doc(uid)
    .collection("connections")
    .where("provider", "==", "google_health")
    .limit(1)
    .get();

  if (!connSnap.empty) {
    syncBatch.update(connSnap.docs[0].ref, { lastSyncAt: now });
  }

  await syncBatch.commit();

  return {
    success: errors.length === 0,
    recordsWritten,
    syncedDate: syncDate,
    errors,
  };
}

function subtractDays(isoDate: string, days: number): string {
  const dt = new Date(`${isoDate}T00:00:00Z`);
  dt.setUTCDate(dt.getUTCDate() - days);
  return dt.toISOString().split("T")[0];
}

function chunked<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}
