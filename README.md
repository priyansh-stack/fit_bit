# Fitbit Health Dashboard (Google Health API v4)

A complete, local-first Flutter Android application that connects a user's Fitbit account and wearable devices directly through the **Google Health API v4** with OAuth 2.0.

> [!IMPORTANT]
> **No Legacy Fitbit Web API**: The legacy Fitbit Web API (`api.fitbit.com`) is scheduled for complete decommissioning by September 30, 2026. This app is built entirely on the new **Google Health API + Google OAuth 2.0** architecture.

> [!WARNING]
> **⚠️ TESTING ONLY SECURITY MODEL**:
> This application runs **100% on-device** with zero backend requirement (no Cloud Functions, no server-side token storage). For local testing, OAuth client credentials can be embedded in `lib/core/constants/oauth_constants.dart`. For production deployment, token exchanges and client secrets must be moved to a backend.

---

## Features & Supported Data Types

| Category | Google Health API v4 Data Type | DataManager | Endpoint |
|---|---|---|---|
| **Activity** | Steps | `GoogleHealthStepsDataManager` | `:rollUp` (1d) |
| **Activity** | Active Minutes | `GoogleHealthActiveMinutesDataManager` | `:rollUp` (1d) |
| **Activity** | Sedentary Period | `GoogleHealthSedentaryPeriodDataManager` | `:rollUp` (1d) |
| **Heart** | Resting Heart Rate | `GoogleHealthRestingHeartRateDataManager` | `:dataPoints` |
| **Heart** | Heart Rate Variability (HRV) | `GoogleHealthHrvDataManager` | `:dataPoints` |
| **Heart** | Electrocardiogram (ECG) | `GoogleHealthElectrocardiogramDataManager` | `:dataPoints` |
| **Heart** | Irregular Rhythm (AFib) | `GoogleHealthIrregularRhythmNotificationDataManager` | `:dataPoints` |
| **Sleep** | Sleep Sessions & Stages | `GoogleHealthSleepDataManager` | `:dataPoints` |
| **Metrics** | Oxygen Saturation (SpO2) | `GoogleHealthOxygenSaturationDataManager` | `:dataPoints` |
| **Metrics** | Respiratory Rate | `GoogleHealthBreathingRateDataManager` | `:dataPoints` |
| **Metrics** | Skin Temperature | `GoogleHealthSkinTemperatureDataManager` | `:dataPoints` |
| **Profile** | User Identity & Units | `GoogleHealthProfileDataManager` | `/profile` |
| **Devices** | Paired Fitbit Devices | `GoogleHealthPairedDeviceDataManager` | `/devices` |

---

## 1. Google Cloud Configuration

### Step 1: Create or Select a Google Cloud Project
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project or select an existing one (e.g. `fitbit-health-dash-local`).

### Step 2: Enable the Google Health API
1. Navigate to **APIs & Services** > **Library**.
2. Search for **Google Health API** (or Health API v4).
3. Click **Enable**.

### Step 3: Configure the OAuth Consent Screen
1. Go to **APIs & Services** > **OAuth consent screen**.
2. User Type: Select **External**.
3. App information:
   - App name: `Fitbit Health Dashboard`
   - User support email: Select your email.
   - Developer contact email: Enter your email.
4. **Scopes**: Add the following read-only scopes:
   - `https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly`
   - `https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly`
   - `https://www.googleapis.com/auth/googlehealth.sleep.readonly`
   - `https://www.googleapis.com/auth/googlehealth.profile.readonly`
   - `https://www.googleapis.com/auth/googlehealth.settings.readonly`
5. **Test Users** (CRITICAL):
   - In "Testing" mode, Google blocks sign-ins from unlisted accounts.
   - Click **Add Users** and add the Gmail / Google Workspace account associated with your Fitbit device.

### Step 4: Create OAuth 2.0 Client Credentials
1. Go to **APIs & Services** > **Credentials**.
2. Click **Create Credentials** > **OAuth client ID**.
3. Application type: Select **Web application** or **Desktop app** (for local testing redirection).
4. Authorized redirect URIs:
   - `com.example.fitbithealth:/oauth2redirect`
   - `http://localhost` (if testing via local callback)
5. Copy your **Client ID** and **Client Secret**.

### Step 5: Configure Credentials in the App
Open `lib/core/constants/oauth_constants.dart`:
```dart
static const String clientId = 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
static const String clientSecret = 'YOUR_GOOGLE_CLIENT_SECRET';
static const String redirectUri = 'com.example.fitbithealth:/oauth2redirect';
```

---

## 2. Firebase Configuration (Local Persistence & Auth)

1. Ensure Firebase CLI is installed and logged in:
   ```bash
   firebase login
   ```
2. Initialize Firebase in this project or configure with FlutterFire:
   ```bash
   flutterfire configure
   ```
3. Enable **Google Sign-In** in the [Firebase Console](https://console.firebase.google.com/) under **Authentication > Sign-in method**.
4. Add your Android debug SHA-1 / SHA-256 fingerprint in Project Settings > Android apps.
5. Deploy Firestore Security Rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

---

## 3. Running & Testing on Android

### Prerequisites
- Flutter SDK (>= 3.6.0)
- Android device or emulator with Google Play Services (API level 24+)

### Run the App
```bash
# 1. Install dependencies
flutter pub get

# 2. Run unit tests
flutter test

# 3. Run on connected Android device
flutter run
```

### Verification Flow
1. **Sign In**: Open the app and tap "Continue with Google".
2. **Connect Fitbit**: Tap "Connect Fitbit via Google Health".
3. **Grant Consent**: The Google OAuth consent page opens in your browser. Grant the requested health permissions.
4. **Data Sync**: The deep link redirects back to the app (`com.example.fitbithealth:/oauth2redirect`), exchanges the tokens locally, saves them securely in Android Keystore, and triggers an initial 30-day sync.
5. **Explore Dashboard**: View steps, heart rate, calories, sleep sessions, and activity charts.
6. **Sync Now & Disconnect**: Test manual sync on the Profile screen, or disconnect anytime to revoke permissions.
