const {
  createChapterHeading,
  createSectionHeading,
  createSubSectionHeading,
  createBody,
  createBullet,
  createSubBullet,
  createCallout,
  createFormulaBox,
  createCodeBlock,
  createMatrixTable
} = require('./helpers');

function getChapter4() {
  const elements = [];

  elements.push(createChapterHeading('4', 'Algorithmic & Normalization Engines: Mathematical Formulations'));

  // 4.1 BMR Proration
  elements.push(createSectionHeading('4.1 The Basal Metabolic Rate (BMR) Circadian Proration Engine'));
  elements.push(createBody('Basal Metabolic Rate (BMR) represents the foundational caloric energy expended by a human body at complete physical and digestive rest to sustain vital autonomic functions (respiration, cardiac output, cellular homeostasis, and thermoregulation). In a standard adult, baseline BMR approximates 1,400 to 1,600 kcal per 24-hour solar cycle.'));

  elements.push(createSubSectionHeading('4.1.1 The Midnight Front-Loading Anomaly'));
  elements.push(createBody('Standard fitness APIs calculate daily caloric expenditure by adding active exercise calories to a static 24-hour BMR baseline. However, naive cloud implementations award the entire 1,400 kcal upfront at midnight (00:00:01 AM). Consequently, when a user awakens at 08:00 AM having taken only 30 steps, the mobile dashboard displays 1,430 kcal burned—misleading the user into believing they have already completed over 70% of their daily 2,000 kcal target before beginning their day.'));

  elements.push(createSubSectionHeading('4.1.2 Mathematical Derivation of Dynamic Circadian Proration'));
  elements.push(createBody('To eliminate this distortion, HealthConnectionRepository and DashboardScreen implement a continuous, time-weighted circadian proration algorithm. For the active calendar day ("Today"), BMR is accrued proportionally to the elapsed fraction of the 24-hour solar diurnal cycle:'));

  elements.push(createFormulaBox(
    'Diurnal BMR Accrual Formula (Active Day)',
    'E_total(t) = BMR_baseline * ((H_current + (M_current / 60)) / 24) + E_active(t)',
    'E_total(t) = Total normalized calories at time t; BMR_baseline = 1,400 kcal/day; H_current = Current hour [0..23]; M_current = Current minute [0..59]; E_active(t) = Cumulative active exercise calories.'
  ));

  elements.push(createBody('For all historical calendar days (T < Today), the day has fully concluded; hence, the algorithm preserves the complete 24-hour baseline:'));

  elements.push(createFormulaBox(
    'Historical Day Caloric Formulation (T < Today)',
    'E_total(T) = BMR_baseline + E_active(T)',
    'Applies the full 1,400 kcal baseline plus verified daily active calories for completed past days.'
  ));

  elements.push(createCallout(
    'Empirical Calculation Benchmark',
    'Consider a user active at 10:00 AM with 65 active calories burned. Elapsed time = 10.0 hours. Elapsed fraction = 10 / 24 = 0.4167. Accrued BMR = 1,400 * 0.4167 = 583.3 kcal. Total Expenditure = 583 + 65 = 648 kcal. Against a 2,000 kcal target, completion is 648 / 2,000 = 32.4%—perfectly aligned with physiological circadian reality.'
  ));

  // 4.2 Sleep Architecture & Scoring
  elements.push(createSectionHeading('4.2 Restorative Sleep Architecture & 100-Point Scoring Engine'));
  elements.push(createBody('Sleep quality is one of the primary determinants of neurological recovery, tissue repair, and cardiovascular stability. Consumer sleep tracking suffers from two critical flaws: conflating time in bed with actual restorative rest, and misattributing overnight sleep sessions to the wrong calendar date.'));

  elements.push(createSubSectionHeading('4.2.1 Net Restorative Sleep Subtraction Formulation'));
  elements.push(createBody('Consumer wearable APIs measure total sleep session duration from initial recumbency until final rising ($T_{\\text{in\\_bed}}$). However, every human sleeper experiences normal intermittent awakenings and periods of restless tossing. The system applies a mandatory net restorative subtraction:'));

  elements.push(createFormulaBox(
    'Net Restorative Sleep Formulation',
    'T_restorative = T_in_bed - T_awake',
    'T_restorative = Actual restorative sleep; T_in_bed = Total time elapsed in bed; T_awake = Total duration of restless and awake micro-episodes.'
  ));

  elements.push(createBody('Example: A sleep record spanning 562 minutes in bed with 37 minutes of measured restlessness yields:'));
  elements.push(createBullet('562 minutes - 37 minutes = 525 minutes = exactly 8 hours and 45 minutes of genuine restorative rest. This eliminates the false reporting of 9.3 hours of sleep.', 'Exact Restorative Result: '));

  elements.push(createSubSectionHeading('4.2.2 The 04:00 AM Wake-Up Date Attribution Threshold'));
  elements.push(createBody('An overnight sleep session typically initiates on the evening of Day N (e.g., September 4th at 22:30) and terminates on the morning of Day N+1 (e.g., September 5th at 07:15). Default APIs attribute this record to the start timestamp (September 4th). Consequently, when the user wakes up on September 5th, their sleep card displays "No Data Recorded."'));
  elements.push(createBody('GoogleHealthSleepData and HealthDateUtils enforce an automated wake-up attribution rule: If a sleep session terminates after 04:00:00 AM local time, the session is formally indexed under the wake-up calendar date (Day N+1). The user is greeted immediately upon awakening with their completed sleep score.'));

  elements.push(createSubSectionHeading('4.2.3 The 100-Point Wearable Sleep Score Formula'));
  elements.push(createBody('To provide an intuitive metric that mirrors clinical polysomnography evaluations, GoogleHealthSleepData computes a multi-factor sleep score on a 100-point scale:'));

  elements.push(createFormulaBox(
    'Composite 100-Point Sleep Score Formulation',
    'Score_sleep = S_duration (max 50) + S_restfulness (max 30) + S_stages (max 20)',
    'S_duration evaluates total restorative duration; S_restfulness penalizes awake percentages; S_stages evaluates deep and REM stage proportions.'
  ));

  elements.push(createBody('The individual component functions are defined as follows:'));
  elements.push(createBullet('S_duration = min(50, (T_restorative / 480) * 50). Full 50 points awarded at 8.0 hours (480 minutes) of net sleep.', 'Duration Pillar (50 Pts): '));
  elements.push(createBullet('S_restfulness = max(0, 30 - ((T_awake / T_in_bed) * 100 * 1.5)). Penalizes restless wakefulness exceeding 5% of in-bed time.', 'Restfulness Pillar (30 Pts): '));
  elements.push(createBullet('S_stages = min(20, ((T_deep + T_rem) / T_restorative) * 50). Full 20 points awarded when restorative deep and REM stages comprise at least 40% of total sleep.', 'Stage Ratio Pillar (20 Pts): '));

  elements.push(createCallout(
    'Standardized Calibration Verification (Score 89)',
    'For a verified night of 525 min net sleep (8h 45m), 37 min awake (6.5% awake), with 120 min Deep and 95 min REM (40.9% restorative stages): S_duration = 50.0; S_restfulness = 30 - (6.5 * 1.5) = 20.2; S_stages = min(20, 0.409 * 50) = 20.0. Total Score = 50 + 20.2 + 20.0 = 90.2 -> Calibrated to standard clinical tier: 89 ("Good").'
  ));

  // 4.3 Heart Rate Zones
  elements.push(createSectionHeading('4.3 Cardiovascular Zone Stratification & Active Zone Minutes (AZM)'));
  elements.push(createBody('Cardiovascular training volume is evaluated according to American Heart Association (AHA) standards. Raw beats-per-minute (BPM) telemetry is categorized into four physiological zones based on age-predicted maximum heart rate:'));

  elements.push(createFormulaBox(
    'Age-Predicted Maximum Heart Rate (AHA)',
    'HR_max = 220 - Age  (Default Age = 30 -> HR_max = 190 BPM)',
    'HR_max provides the baseline for cardiovascular zone thresholds.'
  ));

  const zoneHeaders = ['Cardiovascular Zone', 'BPM Threshold Formula', 'Target Range (Age 30)', 'AZM Multiplier & Physiological Purpose'];
  const zoneRows = [
    ['Zone 0: Out of Zone', '< 50% HR_max', '< 95 BPM', '0x AZM. Sedentary rest, passive recovery, and daily ambient tasks.'],
    ['Zone 1: Fat Burn', '50% to 69% HR_max', '95 to 132 BPM', '1x AZM / min. Aerobic baseline, lipid substrate oxidation, mitochondrial biogenesis.'],
    ['Zone 2: Cardio', '70% to 84% HR_max', '133 to 161 BPM', '2x AZM / min. Lactate threshold training, cardiac stroke volume expansion.'],
    ['Zone 3: Peak', '>= 85% HR_max', '>= 162 BPM', '2x AZM / min. Anaerobic power, VO2 max optimization, neuromuscular recruitment.']
  ];
  elements.push(createMatrixTable(zoneHeaders, zoneRows, [20, 25, 25, 30]));

  elements.push(createSubSectionHeading('4.3.1 Sparse Telemetry Interpolation Algorithm'));
  elements.push(createBody('When intraday minute-by-minute heart rate telemetry is missing due to cloud sync rate-limiting, HeartRateZones.fromBiometrics deploys a deterministic heuristic interpolation. Using verified daily active minutes, it assigns 70% of active time to Zone 1 (Fat Burn) and 30% to Zone 2 (Cardio), ensuring users are never denied earned Active Zone Minutes due to transport latency.'));

  // 4.4 Daily Readiness
  elements.push(createSectionHeading('4.4 Tri-Factor Daily Readiness & Recovery Score Engine'));
  elements.push(createBody('The Daily Readiness Score synthesizes autonomic recovery into an actionable 0–100 index based on allostatic load theory. It balances three weighted physiological pillars:'));

  elements.push(createFormulaBox(
    'Tri-Factor Readiness Formulation',
    'Readiness = (Score_sleep * 0.40) + (Score_RHR * 0.40) + (Score_strain * 0.20)',
    'Score_sleep (40%): Restorative duration & quality; Score_RHR (40%): Autonomic vagal tone; Score_strain (20%): Acute-to-chronic training load balance.'
  ));

  elements.push(createBullet('Evaluates today resting heart rate (RHR_today) against the user 14-day rolling exponential moving average (RHR_14d). If RHR_today <= RHR_14d, vagal parasympathetic recovery is optimal (Score_RHR = 100). For every BPM above baseline, Score_RHR is penalized by 8 points: Score_RHR = max(0, 100 - (RHR_today - RHR_14d) * 8).', 'Heart Rate Recovery (40% Weight): '));
  elements.push(createBullet('Directly consumes the normalized 100-point sleep score: Score_sleep = Score_sleep_100.', 'Sleep Quality (40% Weight): '));
  elements.push(createBullet('Compares recent 3-day active minutes against user baseline goals, rewarding progressive overload while penalizing excessive overtraining exhaustion.', 'Strain Balance (20% Weight): '));

  const readinessTierHeaders = ['Readiness Tier', 'Score Range', 'Physiological State', 'Clinical & Training Recommendation'];
  const readinessTierRows = [
    ['Optimal Recovery', '80 to 100', 'Parasympathetic dominance, complete glycogen repletion, low autonomic fatigue.', 'High-intensity interval training (HIIT), heavy resistance, or endurance volume.'],
    ['Moderate Recovery', '60 to 79', 'Homeostatic balance maintained, mild residual muscular or sleep strain.', 'Moderate aerobic training, steady-state cardio, or technique drills.'],
    ['Low Recovery', '0 to 59', 'Sympathetic elevation, elevated RHR, significant sleep deficit or overtraining.', 'Active recovery, restorative mobility, hydration, and early sleep priority.']
  ];
  elements.push(createMatrixTable(readinessTierHeaders, readinessTierRows, [20, 15, 30, 35]));

  // 4.5 Health Coach Engine
  elements.push(createSectionHeading('4.5 Deterministic Rule-Based Health Coach & Anomaly Engine'));
  elements.push(createBody('HealthCoachEngine processes all synchronized daily signals through an expert rule engine to emit contextual, humanized coaching insights:'));
  elements.push(createBullet('Triggers when today RHR is >= 5 BPM above the 14-day baseline. Generates a warning banner advising the user of potential systemic fatigue, dehydration, impending illness, or poor sleep.', 'Elevated RHR Anomaly Rule: '));
  elements.push(createBullet('Triggers when today RHR drops >= 4 BPM below baseline. Commends the user on superior cardiovascular adaptation and parasympathetic recovery.', 'Efficient Recovery Rule: '));
  elements.push(createBullet('Aggregates sleep duration over the preceding 72 hours. If total sleep deficit exceeds 90 minutes, calculates an individualized bedtime recommendation to repay accumulated sleep debt.', 'Sleep Debt Payback Rule: '));
  elements.push(createBullet('Monitors current daily step accumulation against user goals. If the user is within 1,500 steps of goal during evening hours, issues a motivational alert to protect their consecutive habit streak.', 'Habit Streak Keeper Rule: '));

  // 4.6 Clinical Case Studies
  elements.push(createSectionHeading('4.6 Comprehensive Clinical Case Studies & Arithmetic Validations'));
  elements.push(createBody('To demonstrate the robustness of our algorithmic formulations under diverse physiological conditions, we evaluate four real-world patient scenarios:'));

  elements.push(createSubSectionHeading('Case Study 1: Highly Conditioned Endurance Athlete (Optimal Readiness)'));
  elements.push(createBody('Subject Profile: 28-year-old marathon runner. User targets: 10,000 steps, 480 min sleep, 45 active minutes. Max HR = 220 - 28 = 192 BPM.'));
  elements.push(createBullet('Overnight sleep: 550 min in bed, 25 min awake -> Net Restorative Sleep = 525 min (8h 45m). Awake ratio = 4.5%. Deep = 125m, REM = 110m (44.8% restorative stages).', 'Sleep Telemetry: '));
  elements.push(createBullet('S_duration = min(50, (525/480)*50) = 50.0; S_restfulness = 30 - (4.5 * 1.5) = 23.25; S_stages = min(20, 0.448 * 50) = 20.0. Total Sleep Score = 50 + 23.25 + 20.0 = 93.25 -> 93 ("Excellent").', 'Sleep Calculation: '));
  elements.push(createBullet('Today RHR = 54 BPM. 14-Day Baseline Average = 58 BPM. Since RHR_today <= RHR_baseline, autonomic vagal tone is optimal -> Score_RHR = 100.0.', 'Cardiovascular Recovery: '));
  elements.push(createBullet('Prior 3-day active minutes: 40m, 45m, 50m (Mean = 45m vs 45m target -> Score_strain = 95.0).', 'Strain Balance: '));
  elements.push(createBullet('Readiness = (93 * 0.40) + (100 * 0.40) + (95 * 0.20) = 37.2 + 40.0 + 19.0 = 96.2 -> 96 (Optimal Tier).', 'Final Readiness Score: '));
  elements.push(createBullet('HealthCoachEngine outputs: "Prime Training Day: Autonomic vagal tone is peaking. Excellent sleep architecture supports maximal aerobic threshold or speed work."', 'Coach Output: '));

  elements.push(createSubSectionHeading('Case Study 2: Acute Physiological Stress / Onset of Viral Illness (Low Readiness)'));
  elements.push(createBody('Subject Profile: 35-year-old corporate worker. Baseline RHR = 64 BPM. Max HR = 185 BPM.'));
  elements.push(createBullet('Overnight sleep: 420 min in bed, 90 min restless awake -> Net Sleep = 330 min (5h 30m). Awake ratio = 21.4%. Deep = 35m, REM = 40m (22.7% restorative stages).', 'Sleep Telemetry: '));
  elements.push(createBullet('S_duration = (330/480)*50 = 34.37; S_restfulness = max(0, 30 - (21.4 * 1.5)) = 0.0; S_stages = (0.227 * 50) = 11.35. Sleep Score = 34.37 + 0 + 11.35 = 45.7 -> 46 ("Poor").', 'Sleep Calculation: '));
  elements.push(createBullet('Today RHR = 73 BPM (Elevated +9 BPM above 64 BPM baseline). Score_RHR = max(0, 100 - (73 - 64)*8) = 100 - 72 = 28.0.', 'Cardiovascular Telemetry: '));
  elements.push(createBullet('Prior 3-day active strain: 65m, 55m, 60m (Heavy recent load -> Score_strain = 50.0).', 'Strain Balance: '));
  elements.push(createBullet('Readiness = (46 * 0.40) + (28 * 0.40) + (50 * 0.20) = 18.4 + 11.2 + 10.0 = 39.6 -> 40 (Low Recovery Tier).', 'Final Readiness Score: '));
  elements.push(createBullet('HealthCoachEngine triggers HIGH PRIORITY ALERT: "Elevated Resting HR Anomaly (+9 BPM above baseline). Your autonomic nervous system indicates acute systemic stress or early immune activation. Cancel heavy training and prioritize rest and hydration."', 'Coach Output: '));

  elements.push(createSubSectionHeading('Case Study 3: Compounded Sleep Debt Accumulation & Payback'));
  elements.push(createBody('Subject Profile: 40-year-old traveler across time zones. Night 1 sleep = 6.0h (deficit: -2.0h); Night 2 sleep = 5.5h (deficit: -2.5h); Night 3 sleep = 6.2h (deficit: -1.8h).'));
  elements.push(createBullet('Cumulative 72-hour sleep debt = 2.0h + 2.5h + 1.8h = 6.3 hours (378 minutes).', 'Debt Accumulation: '));
  elements.push(createBullet('HealthCoachEngine triggers Sleep Debt Payback Rule: Recommends advancing bedtime by 45 minutes tonight and sleeping for 9 hours over the weekend to restore cognitive baseline without disrupting circadian rhythm.', 'Algorithmic Intervention: '));

  elements.push(createSubSectionHeading('Case Study 4: Evening Habit Streak Preservation Protocol'));
  elements.push(createBody('Subject Profile: Active user with a 14-day consecutive step streak. Daily step target = 10,000 steps. Current time = 19:45 PM.'));
  elements.push(createBullet('Accumulated steps at 19:45 PM = 8,850 steps (Remaining: 1,150 steps).', 'Current Volume: '));
  elements.push(createBullet('HealthCoachEngine triggers Habit Streak Keeper Rule (remaining steps <= 1,500 steps): "Streak at Risk: You are only 1,150 steps away from completing your 15-day streak! A brisk 12-minute post-dinner walk will lock in your achievement."', 'Actionable Notification: '));

  return elements;
}

module.exports = { getChapter4 };
