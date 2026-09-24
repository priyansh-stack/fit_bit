// lib/features/ai_coach/presentation/ai_coach_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../repositories/health_repository.dart';
import '../cubit/ai_coach_cubit.dart';
import '../data/gemini_chat_service.dart';
import 'widgets/ai_key_dialog.dart';

class AiCoachScreen extends StatelessWidget {
  const AiCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AiCoachCubit(
        healthRepository: context.read<HealthRepository>(),
      ),
      child: const _AiCoachView(),
    );
  }
}

class _AiCoachView extends StatefulWidget {
  const _AiCoachView();

  @override
  State<_AiCoachView> createState() => _AiCoachViewState();
}

class _AiCoachViewState extends State<_AiCoachView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _quickPrompts = [
    "📊 How is my recovery today based on my resting HR?",
    "🏃 Suggest a workout tailored to my 6,139 steps today",
    "💤 What can I do tonight to improve my deep sleep?",
    "📈 Analyze my 7-day activity consistency and trends",
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendPrompt(String prompt) {
    if (prompt.trim().isEmpty) return;
    context.read<AiCoachCubit>().sendMessage(prompt);
    _textController.clear();
    _scrollToBottom();
  }

  void _openKeyDialog() {
    showDialog(
      context: context,
      builder: (_) => AiKeyDialog(cubit: context.read<AiCoachCubit>()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF10B981)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fitbit AI Coach',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  BlocBuilder<AiCoachCubit, AiCoachState>(
                    builder: (context, state) {
                      return Text(
                        state.isProModel ? 'Powered by Gemini Pro' : 'Powered by Gemini Flash',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<AiCoachCubit, AiCoachState>(
            builder: (context, state) {
              return TextButton(
                onPressed: () => context.read<AiCoachCubit>().toggleModel(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.isProModel
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
                        : const Color(0xFF0284C7).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: state.isProModel ? const Color(0xFFA78BFA) : const Color(0xFF38BDF8),
                    ),
                  ),
                  child: Text(
                    state.isProModel ? 'PRO' : 'FLASH',
                    style: TextStyle(
                      color: state.isProModel ? const Color(0xFFA78BFA) : const Color(0xFF38BDF8),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined, color: Colors.white70, size: 20),
            tooltip: 'Gemini API Key',
            onPressed: _openKeyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            tooltip: 'Clear Chat',
            onPressed: () => context.read<AiCoachCubit>().clearConversation(),
          ),
        ],
      ),
      body: BlocConsumer<AiCoachCubit, AiCoachState>(
        listener: (context, state) {
          if (state.status == AiCoachStatus.success || state.status == AiCoachStatus.loading) {
            _scrollToBottom();
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: const Color(0xFFEF4444),
                action: SnackBarAction(
                  label: 'Set Key',
                  textColor: Colors.white,
                  onPressed: _openKeyDialog,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // API Key Missing Warning Banner
              if (!state.hasApiKey)
                GestureDetector(
                  onTap: _openKeyDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap here to add your Google Gemini API key to activate live responses.',
                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Color(0xFF38BDF8), size: 18),
                      ],
                    ),
                  ),
                ),

              // Chat Messages Stream
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: state.messages.length + (state.status == AiCoachStatus.loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length && state.status == AiCoachStatus.loading) {
                      return _buildThinkingBubble();
                    }
                    final msg = state.messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),

              // Quick prompt suggestions
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF1E293B),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      label: Text(
                        _quickPrompts[i],
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      onPressed: () => _sendPrompt(_quickPrompts[i]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Input bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          textInputAction: TextInputAction.send,
                          onSubmitted: _sendPrompt,
                          decoration: InputDecoration(
                            hintText: 'Ask your coach about steps, recovery, sleep...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF10B981)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                        onPressed: () => _sendPrompt(_textController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.2)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF38BDF8),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Analyzing wearable metrics & coaching...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                )
              : null,
          color: isUser ? null : const Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: Border.all(
            color: isUser
                ? Colors.transparent
                : const Color(0xFF38BDF8).withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9.5,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message copied to clipboard.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final a = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $a';
  }
}
