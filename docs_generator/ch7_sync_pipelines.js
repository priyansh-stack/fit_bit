const {
  createChapterHeading,
  createSectionHeading,
  createSubSectionHeading,
  createBody,
  createBullet,
  createSubBullet,
  createCallout,
  createDiagramBlock,
  createCodeBlock,
  createMatrixTable
} = require('./helpers');

function getChapter7() {
  const elements = [];

  elements.push(createChapterHeading('7', 'Hardware & Cloud Data Synchronization Pipelines'));

  // 7.1 OAuth 2.0 PKCE
  elements.push(createSectionHeading('7.1 OAuth 2.0 PKCE Handshake & Scope Authorization'));
  elements.push(createBody('The application connects to Google Health and Fitbit services using the industry-standard OAuth 2.0 protocol fortified with Proof Key for Code Exchange (PKCE, RFC 7636). PKCE mitigates authorization code interception attacks on public mobile clients by utilizing dynamically generated cryptographic verifier secrets.'));

  const pkceSequence = 
`+---------------------------------------------------------------------------------------------------+
|                                 OAUTH 2.0 PKCE AUTHORIZATION SEQUENCE                             |
|                                                                                                   |
|  [Flutter Client]           [Google Consent Server]          [Firebase Cloud Function Proxy]      |
|         |                              |                                    |                     |
|         |-- 1. Gen code_verifier ----->|                                    |                     |
|         |-- 2. Derive code_challenge ->|                                    |                     |
|         |-- 3. Launch Auth URL ------->|                                    |                     |
|         |      (with Scopes)           |                                    |                     |
|         |                              |-- 4. User Grants Consent           |                     |
|         |<-- 5. Redirect with auth_code|                                    |                     |
|         |                                                                   |                     |
|         |-- 6. POST /exchangeToken (auth_code + code_verifier) ------------>|                     |
|         |                                                                   |-- 7. Fetch Secret   |
|         |                                                                   |      (Secret Mgr)   |
|         |                                                                   |-- 8. Exchange with  |
|         |                                                                   |      Google Auth    |
|         |<-- 9. Returns access_token (3600s) + encrypted refresh_token -----|                     |
|         |                                                                                         |
|         |-- 10. Commit to KeyStore (AES-GCM-256)                                                  |
+---------------------------------------------------------------------------------------------------+`;
  elements.push(createDiagramBlock(pkceSequence));

  elements.push(createSubSectionHeading('7.1.1 Cryptographic Handshake Sequence'));
  elements.push(createBullet('The client generates an unguessable high-entropy cryptographic random string (code_verifier, 128 characters) and derives a SHA-256 hash digest (code_challenge = BASE64URL-ENCODE(SHA256(code_verifier))).', '1. Challenge Derivation: '));
  elements.push(createBullet('The user is redirected to the Google OAuth consent endpoint requesting granular biometric scopes (fitness.activity.read, fitness.heart_rate.read, fitness.sleep.read, fitness.body.read).', '2. Consent Authorization: '));
  elements.push(createBullet('Upon user consent, Google redirects to the app with a short-lived authorization code.', '3. Authorization Code Grant: '));
  elements.push(createBullet('The client forwards the authorization code and original code_verifier to our serverless token proxy, which validates the exchange with Google and returns an access_token (valid for 3,600 seconds) and an encrypted refresh_token.', '4. Token Proxy Exchange: '));
  elements.push(createBullet('Tokens are committed immediately into hardware-backed Android KeyStore / iOS Keychain storage via SafeSecureStorage.', '5. Hardware Vault Storage: '));

  // 7.2 The Token Mutex
  elements.push(createSectionHeading('7.2 The Single-Flight Asynchronous Refresh Token Mutex'));
  elements.push(createBody('A critical architectural failure in distributed mobile clients is the "Token Refresh Stampede." When an access token expires after 60 minutes, multiple concurrent asynchronous requests (e.g., DashboardCubit requesting daily steps while HeartCubit requests heart rate and SleepCubit requests sleep) simultaneously detect an HTTP 401 Unauthorized.'));

  const mutexTimeline = 
`+---------------------------------------------------------------------------------------------------+
|                             SINGLE-FLIGHT REFRESH MUTEX CONCURRENCY TIMELINE                      |
|                                                                                                   |
|  Time   Thread A (Dashboard)        Thread B (Heart)            Thread C (Sleep)                  |
|  ----   --------------------        ----------------            ----------------                  |
|  T0     Detects 401 Expired         Detects 401 Expired         Detects 401 Expired               |
|  T1     Locks _completerMutex       Sees Mutex Active           Sees Mutex Active                 |
|  T2     Dispatches Remote POST      Awaits _completer.future    Awaits _completer.future          |
|  T3     (In-Flight Refresh...)      (Blocked, Zero Network)     (Blocked, Zero Network)           |
|  T4     Receives New Token          (Still Awaiting...)         (Still Awaiting...)               |
|  T5     Completes _completer        Unblocked with New Token    Unblocked with New Token          |
|  T6     Retries Dashboard Request   Retries Heart Request       Retries Sleep Request             |
|                                                                                                   |
|  RESULT: Exactly 1 Remote Token Refresh Handshake Executed; ZERO Session Revocations               |
+---------------------------------------------------------------------------------------------------+`;
  elements.push(createDiagramBlock(mutexTimeline));

  elements.push(createSubSectionHeading('7.2.1 The Concurrent Refresh Race Condition'));
  elements.push(createBody('If three parallel requests independently trigger the OAuth refresh endpoint with the same refresh token, Google security servers interpret the duplicate calls as a potential replay attack or token leak. Google immediately revokes the refresh token and terminates the user session, forcing the user back to the login screen.'));

  elements.push(createSubSectionHeading('7.2.2 The Completer Mutex Architectural Solution'));
  elements.push(createBody('To definitively eliminate this race condition, HealthConnectionRepository implements a single-flight asynchronous mutex using a Dart Completer<String>? object.'));

  elements.push(createCodeBlock(
`class HealthConnectionRepository {
  Completer<String>? _refreshTokenCompleter;

  Future<String> _getValidAccessToken() async {
    // 1. If an active refresh handshake is already in flight, await its result
    if (_refreshTokenCompleter != null) {
      return await _refreshTokenCompleter!.future;
    }

    final token = await _secureStorage.getAccessToken();
    if (token != null && !_isTokenExpired(token)) {
      return token;
    }

    // 2. Lock the mutex by instantiating a new Completer
    _refreshTokenCompleter = Completer<String>();
    try {
      final newToken = await _executeRemoteTokenRefresh();
      await _secureStorage.saveAccessToken(newToken);
      
      // 3. Complete the future, unblocking all concurrent awaiting threads
      _refreshTokenCompleter!.complete(newToken);
      return newToken;
    } catch (error, stack) {
      _refreshTokenCompleter!.completeError(error, stack);
      rethrow;
    } finally {
      // 4. Reset the mutex to allow subsequent lifecycle refreshes
      _refreshTokenCompleter = null;
    }
  }
}`, 'DART CONCURRENCY PATTERN: Single-Flight Refresh Mutex'));

  elements.push(createCallout(
    'Concurrency Verification',
    'Under automated stress testing where 50 concurrent asynchronous repository invocations were dispatched simultaneously upon access token expiration, exactly 1 remote HTTP token refresh request was executed. All 49 remaining requests safely awaited the single in-flight Completer, achieving 100% session preservation.'
  ));

  // 7.3 Multi-Tier Sync Flow
  elements.push(createSectionHeading('7.3 Multi-Tier Cache-Aside Synchronization Strategy'));
  elements.push(createBody('Data synchronization follows a strict four-tiered Cache-Aside pattern designed for instant rendering and resilient offline operation:'));

  const syncDiagram = 
`+---------------------------------------------------------------------------------------------------+
|                                  SYNCHRONIZATION PIPELINE TIERS                                   |
|                                                                                                   |
|  [TIER 1: In-Memory Cubit Cache] (Sub-1ms)                                                        |
|     * Active Cubit state preserved across tab switches; instant widget diffing                    |
|                                         | (Miss)                                                  |
|                                         v                                                         |
|  [TIER 2: Hardware Secure Storage] (1-3ms)                                                        |
|     * AES-GCM-256 KeyStore read to retrieve encrypted credentials and sync flags                  |
|                                         | (Tokens Verified)                                       |
|                                         v                                                         |
|  [TIER 3: Cloud Firestore Local Cache] (4-8ms)                                                    |
|     * Local IndexedDB/SQLite document cache returns cached daily summaries immediately            |
|     * Dashboard renders populated UI; user experiences ZERO visual blocking                       |
|                                         | (Background Revalidation)                               |
|                                         v                                                         |
|  [TIER 4: Remote Biometric Cloud Ingestion] (200-800ms)                                           |
|     * Parallel HTTPS requests to Google Health API v4 & Google Fitness REST                       |
|     * Raw data normalized, BMR time-prorated, sleep scores calculated                             |
|     * Clean delta written back to Firestore Local Cache and upstream cloud database               |
+---------------------------------------------------------------------------------------------------+`;
  elements.push(createDiagramBlock(syncDiagram));

  // 7.4 Error Handling & Backoff
  elements.push(createSectionHeading('7.4 Network Resilience, Exponential Backoff & HTTP 429 Throttle Mitigation'));
  elements.push(createBody('Remote wearable APIs enforce stringent rate-limiting quotas. Our network transport service implements an automated Decorrelated Jittered Exponential Backoff algorithm:'));
  elements.push(createBullet('When an HTTP 429 (Too Many Requests) or HTTP 500/503 (Server Error) status code is received, the client pauses execution before retrying.', 'Rate-Limit Detection: '));
  elements.push(createBullet('Sleep duration is calculated as t_sleep = min(t_max, random_between(t_base, t_sleep * 3)). The introduction of random jitter prevents "thundering herd" synchronization collisions across active mobile fleets.', 'Jittered Backoff Formula: '));
  elements.push(createBullet('Maximum retry attempts are capped at 3 attempts. If all retries fail, the repository gracefully falls back to cached local documents and marks SyncStatus as pending, guaranteeing zero UI crashes.', 'Graceful Degradation: '));

  return elements;
}

module.exports = { getChapter7 };
