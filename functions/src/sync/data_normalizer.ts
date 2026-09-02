// functions/src/sync/data_normalizer.ts
//
// Maps raw Google Health API v4 responses → normalized Firestore documents.
// Nothing from this file is ever sent to Flutter; only Firestore writes happen.

import * as admin from "firebase-admin";
import type { DailyDataPoint } from "../google_health/google_health_service";

const Timestamp = admin.firestore.Timestamp;

export interface NormalizedHealthDaily {
  date: string;
  steps?: number;
  distanceMeters?: number;
  calories?: number;
  activeCalories?: number;
  activeMinutes?: number;
  floors?: number;
  restingHeartRate?: number;
  sleepMinutes?: number;
  sleepScore?: number;
  source: string;
  updatedAt: admin.firestore.FieldValue;
}

export interface NormalizedHeartRateRecord {
  timestamp: admin.firestore.Timestamp;
  bpm: number;
  source: string;
  updatedAt: admin.firestore.FieldValue;
}

export interface NormalizedSleepRecord {
  date: string;
  startTime: admin.firestore.Timestamp;
  endTime: admin.firestore.Timestamp;
  durationMinutes: number;
  awakeMinutes?: number;
  lightMinutes?: number;
  deepMinutes?: number;
  remMinutes?: number;
  sleepScore?: number;
  source: string;
  updatedAt: admin.firestore.FieldValue;
}

export interface NormalizedExerciseRecord {
  date: string;
  startTime: admin.firestore.Timestamp;
  durationMinutes: number;
  activityType: string;
  calories?: number;
  distanceMeters?: number;
  avgHeartRate?: number;
  source: string;
  updatedAt: admin.firestore.FieldValue;
}

export interface NormalizedHealthMetric {
  date: string;
  type: string;
  value: number;
  unit: string;
  source: string;
  updatedAt: admin.firestore.FieldValue;
}

// ─────────────────────────────────────────────────────────────────────────────
// Normalization functions
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Merges multiple daily data-type arrays into a single HealthDaily map keyed by date.
 */
export function normalizeHealthDaily(params: {
  steps: DailyDataPoint[];
  distance: DailyDataPoint[];
  calories: DailyDataPoint[];
  activeCalories: DailyDataPoint[];
  activeMinutes: DailyDataPoint[];
  floors: DailyDataPoint[];
  restingHR: DailyDataPoint[];
  sleep: DailyDataPoint[];
  dataSourceFamily: string;
}): Map<string, NormalizedHealthDaily> {
  const result = new Map<string, NormalizedHealthDaily>();
  const source = params.dataSourceFamily;
  const now = admin.firestore.FieldValue.serverTimestamp();

  const ensureDate = (date: string): NormalizedHealthDaily => {
    if (!result.has(date)) {
      result.set(date, { date, source, updatedAt: now });
    }
    return result.get(date)!;
  };

  for (const pt of params.steps) {
    const date = extractDate(pt);
    if (!date) continue;
    const doc = ensureDate(date);
    doc.steps = extractInt(pt);
  }

  for (const pt of params.distance) {
    const date = extractDate(pt);
    if (!date) continue;
    ensureDate(date).distanceMeters = extractFloat(pt);
  }

  for (const pt of params.calories) {
    const date = extractDate(pt);
    if (!date) continue;
    ensureDate(date).calories = extractInt(pt);
  }

  for (const pt of params.activeCalories) {
    const date = extractDate(pt);
    if (!date) continue;
    ensureDate(date).activeCalories = extractInt(pt);
  }

  for (const pt of params.activeMinutes) {
    const date = extractDate(pt);
    if (!date) continue;
    ensureDate(date).activeMinutes = extractInt(pt);
  }

  for (const pt of params.floors) {
    const date = extractDate(pt);
    if (!date) continue;
    ensureDate(date).floors = extractInt(pt);
  }

  for (const pt of params.restingHR) {
    const date = extractDate(pt);
    if (!date) continue;
    ensureDate(date).restingHeartRate = extractInt(pt);
  }

  for (const pt of params.sleep) {
    const date = extractDate(pt);
    if (!date) continue;
    const doc = ensureDate(date);
    // Sleep value is duration in minutes
    const durationSec = extractInt(pt) || extractFloat(pt) || 0;
    doc.sleepMinutes = Math.round(durationSec > 1000 ? durationSec / 60 : durationSec);
  }

  return result;
}

/** Normalizes intraday heart rate data points. */
export function normalizeHeartRate(
  dataPoints: DailyDataPoint[],
  dataSourceFamily: string
): NormalizedHeartRateRecord[] {
  const now = admin.firestore.FieldValue.serverTimestamp();
  return dataPoints
    .filter((pt) => extractTimestamp(pt) && extractInt(pt))
    .map((pt) => ({
      timestamp: Timestamp.fromDate(new Date(extractTimestamp(pt)!)),
      bpm: extractInt(pt)!,
      source: dataSourceFamily,
      updatedAt: now,
    }));
}

/** Normalizes sleep session data. */
export function normalizeSleepSessions(
  dataPoints: DailyDataPoint[],
  dataSourceFamily: string
): NormalizedSleepRecord[] {
  const now = admin.firestore.FieldValue.serverTimestamp();
  return dataPoints
    .filter((pt) => pt.startTime && pt.endTime)
    .map((pt) => {
      const startDt = new Date(pt.startTime as string);
      const endDt = new Date(pt.endTime as string);
      const durationMin = Math.round((endDt.getTime() - startDt.getTime()) / 60000);

      const stages = pt.stages as Record<string, number> | undefined;

      return {
        date: extractDateFromTimestamp(pt.startTime as string),
        startTime: Timestamp.fromDate(startDt),
        endTime: Timestamp.fromDate(endDt),
        durationMinutes: durationMin,
        awakeMinutes: stages?.awake,
        lightMinutes: stages?.light,
        deepMinutes: stages?.deep,
        remMinutes: stages?.rem,
        sleepScore: pt.sleepScore as number | undefined,
        source: dataSourceFamily,
        updatedAt: now,
      };
    });
}

/** Normalizes exercise/workout sessions. */
export function normalizeExercise(
  dataPoints: DailyDataPoint[],
  dataSourceFamily: string
): NormalizedExerciseRecord[] {
  const now = admin.firestore.FieldValue.serverTimestamp();
  return dataPoints
    .filter((pt) => pt.startTime && pt.durationMinutes)
    .map((pt) => {
      const startDt = new Date(pt.startTime as string);
      return {
        date: extractDateFromTimestamp(pt.startTime as string),
        startTime: Timestamp.fromDate(startDt),
        durationMinutes: (pt.durationMinutes as number) || 0,
        activityType: (pt.activityType as string) || "unknown",
        calories: pt.calories as number | undefined,
        distanceMeters: pt.distanceMeters as number | undefined,
        avgHeartRate: pt.avgHeartRate as number | undefined,
        source: dataSourceFamily,
        updatedAt: now,
      };
    });
}

/** Normalizes health metrics (SpO2, respiratory rate, weight, body fat). */
export function normalizeHealthMetric(
  dataPoints: DailyDataPoint[],
  metricType: string,
  unit: string,
  dataSourceFamily: string
): NormalizedHealthMetric[] {
  const now = admin.firestore.FieldValue.serverTimestamp();
  return dataPoints
    .filter((pt) => extractTimestamp(pt))
    .map((pt) => ({
      date: extractDateFromTimestamp(extractTimestamp(pt)!),
      type: metricType,
      value: extractFloat(pt) || 0,
      unit,
      source: dataSourceFamily,
      updatedAt: now,
    }));
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — Google Health API v4 field extraction
// ─────────────────────────────────────────────────────────────────────────────

/** Extracts the calendar date (yyyy-MM-dd) from a data point. */
function extractDate(pt: DailyDataPoint): string | undefined {
  if (pt.date) return pt.date as string;
  const ts = pt.startTime as string | undefined;
  if (ts) return extractDateFromTimestamp(ts);
  return undefined;
}

function extractDateFromTimestamp(ts: string): string {
  return new Date(ts).toISOString().split("T")[0];
}

function extractTimestamp(pt: DailyDataPoint): string | undefined {
  return (pt.startTime || pt.timestamp || pt.sampleTime) as string | undefined;
}

function extractInt(pt: DailyDataPoint): number | undefined {
  const v = pt.intValue ?? pt.value ?? pt.floatValue;
  if (v === undefined || v === null) return undefined;
  return Math.round(Number(v));
}

function extractFloat(pt: DailyDataPoint): number | undefined {
  const v = pt.floatValue ?? pt.value ?? pt.intValue;
  if (v === undefined || v === null) return undefined;
  return Number(v);
}
