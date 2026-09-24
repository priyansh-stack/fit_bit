import 'package:equatable/equatable.dart';
import '../data/gemini_chat_service.dart';
import '../data/fitbit_chat_library_repository.dart';

enum AiCoachStatus { initial, loading, success, failure }

class AiCoachState extends Equatable {
  const AiCoachState({
    this.status = AiCoachStatus.initial,
    this.messages = const [],
    this.errorMessage,
    this.hasApiKey = false,
    this.isProModel = false,
    this.currentUserName = 'Athlete',
    this.currentSessionId,
    this.sessions = const [],
    this.isLoadingLibrary = false,
  });

  final AiCoachStatus status;
  final List<ChatMessage> messages;
  final String? errorMessage;
  final bool hasApiKey;
  final bool isProModel;
  final String currentUserName;
  final String? currentSessionId;
  final List<AiCoachSession> sessions;
  final bool isLoadingLibrary;

  AiCoachState copyWith({
    AiCoachStatus? status,
    List<ChatMessage>? messages,
    String? errorMessage,
    bool? hasApiKey,
    bool? isProModel,
    String? currentUserName,
    String? currentSessionId,
    List<AiCoachSession>? sessions,
    bool? isLoadingLibrary,
  }) {
    return AiCoachState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      isProModel: isProModel ?? this.isProModel,
      currentUserName: currentUserName ?? this.currentUserName,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      sessions: sessions ?? this.sessions,
      isLoadingLibrary: isLoadingLibrary ?? this.isLoadingLibrary,
    );
  }

  @override
  List<Object?> get props => [
        status,
        messages,
        errorMessage,
        hasApiKey,
        isProModel,
        currentUserName,
        currentSessionId,
        sessions,
        isLoadingLibrary,
      ];
}
