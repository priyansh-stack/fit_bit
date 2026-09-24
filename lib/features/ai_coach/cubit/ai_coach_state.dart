// lib/features/ai_coach/cubit/ai_coach_state.dart

import 'package:equatable/equatable.dart';
import '../data/gemini_chat_service.dart';

enum AiCoachStatus { initial, loading, success, failure }

class AiCoachState extends Equatable {
  const AiCoachState({
    this.status = AiCoachStatus.initial,
    this.messages = const [],
    this.errorMessage,
    this.hasApiKey = false,
    this.isProModel = false,
  });

  final AiCoachStatus status;
  final List<ChatMessage> messages;
  final String? errorMessage;
  final bool hasApiKey;
  final bool isProModel;

  AiCoachState copyWith({
    AiCoachStatus? status,
    List<ChatMessage>? messages,
    String? errorMessage,
    bool? hasApiKey,
    bool? isProModel,
  }) {
    return AiCoachState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      isProModel: isProModel ?? this.isProModel,
    );
  }

  @override
  List<Object?> get props => [status, messages, errorMessage, hasApiKey, isProModel];
}
