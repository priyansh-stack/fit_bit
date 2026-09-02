// functions/src/google_health/google_health_service.ts
//
// Calls Google Health API v4 — the server-side successor to Fitbit Web API.
// Base URL: https://health.googleapis.com/v4/
// Data type naming: kebab-case in URL path (e.g., heart-rate)
//                   snake_case in filter expressions
//
// VERIFIED endpoints (August 2026):
//   GET  /v4/users/me/identity
//   GET  /v4/users/me/profile
//   GET  /v4/users/me/settings
//   POST /v4/users/me/dataTypes/{type}/dataPoints:dailyRollUp
//   GET  /v4/users/me/dataTypes/{type}/dataPoints

import axios, { AxiosError } from "axios";

const BASE_URL = "https://health.googleapis.com/v4";

export interface HealthIdentity {
  userId: string;
  email?: string;
}

export interface HealthProfile {
  displayName?: string;
  birthdate?: string;
  height?: number; // cm
  weight?: number; // kg
  timezone?: string;
}

export interface DailyRollUpRequest {
  startDate: string; // yyyy-MM-dd
  endDate: string;   // yyyy-MM-dd
  dataSourceFamily?: "all-sources" | "google-sources" | "google-wearables";
}

// Raw daily rollup response — shape varies per data type but we parse what we need.
export interface DailyDataPoint {
  date?: string;
  startTime?: string;
  endTime?: string;
  value?: number;
  intValue?: number;
  floatValue?: number;
  [key: string]: unknown;
}

export interface ListDataPointsRequest {
  startTime?: string; // ISO 8601 UTC
  endTime?: string;
  pageSize?: number;
  pageToken?: string;
  filter?: string; // e.g. "heart_rate.sample_time.physical_time > '2026-08-01T00:00:00Z'"
  dataSourceFamily?: "all-sources" | "google-sources" | "google-wearables";
}

export class GoogleHealthService {
  private accessToken: string;

  constructor(accessToken: string) {
    this.accessToken = accessToken;
  }

  private headers() {
    return {
      Authorization: `Bearer ${this.accessToken}`,
      "Content-Type": "application/json",
    };
  }

  // -----------------------------------------------------------------------
  // Identity & Profile
  // -----------------------------------------------------------------------

  async getIdentity(): Promise<HealthIdentity> {
    const res = await this.get<HealthIdentity>("/users/me/identity");
    return res;
  }

  async getProfile(): Promise<HealthProfile> {
    const res = await this.get<HealthProfile>("/users/me/profile");
    return res;
  }

  async getSettings(): Promise<Record<string, unknown>> {
    return this.get<Record<string, unknown>>("/users/me/settings");
  }

  // -----------------------------------------------------------------------
  // Daily Roll-Up endpoints (aggregated per calendar day)
  // Supported data types: steps, distance, calories, active-calories,
  //   active-minutes, floors, heart-rate, resting-heart-rate, sleep, weight, body-fat
  // -----------------------------------------------------------------------

  async getDailyRollUp(
    dataType: string,
    req: DailyRollUpRequest
  ): Promise<DailyDataPoint[]> {
    const body: Record<string, unknown> = {
      startDate: req.startDate,
      endDate: req.endDate,
    };
    if (req.dataSourceFamily) {
      body.dataSourceFamily = req.dataSourceFamily;
    }
    const res = await this.post<{ dataPoints?: DailyDataPoint[] }>(
      `/users/me/dataTypes/${dataType}/dataPoints:dailyRollUp`,
      body
    );
    return res.dataPoints || [];
  }

  async getSteps(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("steps", req);
  }

  async getDistance(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("distance", req);
  }

  async getCalories(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("calories", req);
  }

  async getActiveCalories(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("active-calories", req);
  }

  async getActiveMinutes(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("active-minutes", req);
  }

  async getFloors(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("floors", req);
  }

  async getRestingHeartRate(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("resting-heart-rate", req);
  }

  async getSleep(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("sleep", req);
  }

  async getWeight(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("weight", req);
  }

  async getBodyFat(req: DailyRollUpRequest): Promise<DailyDataPoint[]> {
    return this.getDailyRollUp("body-fat", req);
  }

  // -----------------------------------------------------------------------
  // List endpoints (intraday / point-in-time data)
  // -----------------------------------------------------------------------

  async listDataPoints(
    dataType: string,
    req: ListDataPointsRequest
  ): Promise<{ dataPoints: DailyDataPoint[]; nextPageToken?: string }> {
    const params: Record<string, string> = {};
    if (req.startTime) params.startTime = req.startTime;
    if (req.endTime) params.endTime = req.endTime;
    if (req.pageSize) params.pageSize = req.pageSize.toString();
    if (req.pageToken) params.pageToken = req.pageToken;
    if (req.filter) params.filter = req.filter;
    if (req.dataSourceFamily) params.dataSourceFamily = req.dataSourceFamily;

    const res = await this.get<{
      dataPoints?: DailyDataPoint[];
      nextPageToken?: string;
    }>(`/users/me/dataTypes/${dataType}/dataPoints`, params);

    return {
      dataPoints: res.dataPoints || [],
      nextPageToken: res.nextPageToken,
    };
  }

  async getHeartRate(req: ListDataPointsRequest): Promise<DailyDataPoint[]> {
    const { dataPoints } = await this.listDataPoints("heart-rate", req);
    return dataPoints;
  }

  async getHRV(req: ListDataPointsRequest): Promise<DailyDataPoint[]> {
    const { dataPoints } = await this.listDataPoints("heart-rate-variability", req);
    return dataPoints;
  }

  async getSpO2(req: ListDataPointsRequest): Promise<DailyDataPoint[]> {
    const { dataPoints } = await this.listDataPoints("spo2", req);
    return dataPoints;
  }

  async getRespiratoryRate(req: ListDataPointsRequest): Promise<DailyDataPoint[]> {
    const { dataPoints } = await this.listDataPoints("respiratory-rate", req);
    return dataPoints;
  }

  async getExercise(req: ListDataPointsRequest): Promise<DailyDataPoint[]> {
    const { dataPoints } = await this.listDataPoints("exercise", req);
    return dataPoints;
  }

  // -----------------------------------------------------------------------
  // HTTP helpers
  // -----------------------------------------------------------------------

  private async get<T>(
    path: string,
    params?: Record<string, string>
  ): Promise<T> {
    try {
      const res = await axios.get<T>(`${BASE_URL}${path}`, {
        headers: this.headers(),
        params,
      });
      return res.data;
    } catch (e) {
      throw this.handleAxiosError(e as AxiosError);
    }
  }

  private async post<T>(path: string, body: unknown): Promise<T> {
    try {
      const res = await axios.post<T>(`${BASE_URL}${path}`, body, {
        headers: this.headers(),
      });
      return res.data;
    } catch (e) {
      throw this.handleAxiosError(e as AxiosError);
    }
  }

  private handleAxiosError(e: AxiosError): Error {
    if (e.response) {
      const status = e.response.status;
      const message = (e.response.data as Record<string, unknown>)?.error?.toString()
        || e.message;

      if (status === 401) return new Error("HEALTH_UNAUTHORIZED");
      if (status === 403) return new Error(`HEALTH_FORBIDDEN: ${message}`);
      if (status === 404) return new Error(`HEALTH_NOT_FOUND: ${message}`);
      if (status === 429) return new Error("HEALTH_RATE_LIMITED");
      return new Error(`HEALTH_API_ERROR_${status}: ${message}`);
    }
    return new Error(`HEALTH_NETWORK_ERROR: ${e.message}`);
  }
}
