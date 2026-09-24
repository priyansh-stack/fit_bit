// lib/features/ai_coach/cubit/ai_coach_cubit.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/models/health_daily.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/weekly_comparison.dart';
import '../../../repositories/health_repository.dart';
import '../data/gemini_chat_service.dart';
import 'ai_coach_state.dart';

export 'ai_coach_state.dart';

class AiCoachCubit extends Cubit<AiCoachState> {
  AiCoachCubit({
    required HealthRepository healthRepository,
    GeminiChatService? chatService,
  })  : _healthRepository = healthRepository,
        _chatService = chatService ?? GeminiChatService(),
        super(const AiCoachState()) {
    _init();
  }

  final HealthRepository _healthRepository;
  final GeminiChatService _chatService;

  Future<void> _init() async {
    final key = await _chatService.getApiKey();
    final hasKey = key != null && key.isNotEmpty;

    // Initial greeting
    final welcomeMessage = ChatMessage(
      text: "👋 Hi Priyanshu! I'm your **Fitbit AI Health Coach** powered by Google Gemini. "
          "I have live access to your wearable biometrics, recovery metrics, and step trends. "
          "How can I assist your health and fitness today?",
      isUser: false,
      timestamp: DateTime.now(),
    );

    emit(state.copyWith(
      hasApiKey: hasKey,
      messages: [welcomeMessage],
    ));
  }

  Future<void> saveApiKey(String key) async {
    await _chatService.saveApiKey(key);
    emit(state.copyWith(hasApiKey: key.trim().isNotEmpty));
  }

  Future<bool> testApiKey(String key) async {
    return _chatService.testApiKey(key);
  }

  void toggleModel() {
    emit(state.copyWith(isProModel: !state.isProModel));
  }

  void clearConversation() {
    final welcomeMessage = ChatMessage(
      text: "Conversation cleared. How can I help you next with your fitness and recovery goals?",
      isUser: false,
      timestamp: DateTime.now(),
    );
    emit(state.copyWith(messages: [welcomeMessage]));
  }

  Future<void> sendMessage(String text) async {
    final userPrompt = text.trim();
    if (userPrompt.isEmpty) return;

    final userMessage = ChatMessage(
      text: userPrompt,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final updatedMessages = List<ChatMessage>.from(state.messages)..add(userMessage);

    emit(state.copyWith(
      status: AiCoachStatus.loading,
      messages: updatedMessages,
      errorMessage: null,
    ));

    try {
      // Gather latest telemetry for context
      final recentSummaries = await _healthRepository.getRecentDailySummaries(days: 14);
      final todayIso = HealthDateUtils.todayIso();
      final today = recentSummaries[todayIso];
      final sortedDays = recentSummaries.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final systemInstruction = _buildSystemInstruction(today, sortedDays);

      final reply = await _chatService.sendMessage(
        prompt: userPrompt,
        history: updatedMessages.sublist(0, updatedMessages.length - 1),
        systemInstruction: systemInstruction,
        usePro: state.isProModel,
      );

      final aiMessage = ChatMessage(
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );

      emit(state.copyWith(
        status: AiCoachStatus.success,
        messages: List<ChatMessage>.from(state.messages)..add(aiMessage),
      ));
    } catch (e) {
      debugPrint('[AiCoachCubit] sendMessage error: $e');
      final errMessage = e.toString().replaceFirst('Exception: ', '');
      emit(state.copyWith(
        status: AiCoachStatus.failure,
        errorMessage: errMessage,
      ));
    }
  }

  String _buildSystemInstruction(HealthDaily? today, List<HealthDaily> recentDays) {
    final weeklyTrend = WeeklyComparison.compare(days: recentDays);

    final todaySteps = today?.steps ?? 0;
    final todayCalories = today?.calories ?? 0;
    final todayActiveMin = today?.activeMinutes ?? 0;
    final todayRhr = today?.restingHeartRate ??
        recentDays.reversed
            .where((d) => d.restingHeartRate != null && d.restingHeartRate! > 0)
            .map((d) => d.restingHeartRate!)
            .firstOrNull;

    final todaySleepMin = today?.sleepMinutes ??
        recentDays.reversed
            .where((d) => d.sleepMinutes != null && d.sleepMinutes! > 0)
            .map((d) => d.sleepMinutes!)
            .firstOrNull;
    final sleepHours = todaySleepMin != null ? (todaySleepMin / 60.0).toStringAsFixed(1) : 'Unknown';

    final sb = StringBuffer();
    sb.writeln("You are the Fitbit AI Health Coach, an empathetic, certified clinical fitness and cardiovascular wellness coach.");
    sb.writeln("You provide personalized, scientifically grounded exercise, recovery, and lifestyle recommendations.");
    sb.writeln("Always format responses clearly using Markdown (bullet points, bold text for key metrics).");
    sb.writeln("Keep responses concise, motivating, and actionable. Do not output excessively verbose disclaimers unless relevant.");
    sb.writeln();
    sb.writeln("CURRENT USER GROUND TRUTH TELEMETRY:");
    sb.writeln("- User: Priyanshu Kumar (Age: 22, Male Vitality Cohort)");
    sb.writeln("- Today's Date: ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}");
    sb.writeln("- Today's Steps: $todaySteps steps (Canonical Google Health Daily Rollup)");
    sb.writeln("- Today's Active Zone Minutes: $todayActiveMin minutes");
    sb.writeln("- Today's Estimated Calorie Burn: $todayCalories kcal");
    sb.writeln("- Latest Resting Heart Rate: ${todayRhr != null ? '$todayRhr bpm' : 'Measuring / not available'}");
    sb.writeln("- Latest Sleep Duration: $sleepHours hours");
    sb.writeln("- 7-Day Average Steps: ${weeklyTrend.avgStepsThisWeek} steps/day");
    sb.writeln("- Step Delta vs Previous Week: ${weeklyTrend.stepDeltaPercent > 0 ? '+' : ''}${weeklyTrend.stepDeltaPercent.toStringAsFixed(1)}%");
    sb.writeln();
    sb.writeln("Use these exact metrics to personalize every answer. When asked about recovery, training volume, or health scores, quote their actual numbers.");

    return sb.toString();
  }
}
