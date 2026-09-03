// lib/features/dashboard/presentation/widgets/smart_coach_banner.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes.dart';
import '../../../../core/models/health_insight.dart';

class SmartCoachBanner extends StatefulWidget {
  const SmartCoachBanner({
    super.key,
    required this.insights,
  });

  final List<HealthInsight> insights;

  @override
  State<SmartCoachBanner> createState() => _SmartCoachBannerState();
}

class _SmartCoachBannerState extends State<SmartCoachBanner> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onAction(BuildContext context, HealthInsight insight) {
    if (insight.type == InsightType.elevatedRhr ||
        insight.type == InsightType.optimalRecovery) {
      context.go(AppRoute.heart);
    } else if (insight.type == InsightType.sleepDebt) {
      context.go(AppRoute.sleep);
    } else if (insight.type == InsightType.streakKeeper) {
      context.go(AppRoute.activity);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Color(0xFF818CF8),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Smart Health Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (widget.insights.length > 1)
              Row(
                children: List.generate(widget.insights.length, (index) {
                  final isSelected = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSelected ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF818CF8)
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Carousel / Cards
        SizedBox(
          height: 175,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.insights.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final item = widget.insights[index];
              return _InsightCard(
                insight: item,
                onTapAction: () => _onAction(context, item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.insight,
    required this.onTapAction,
  });

  final HealthInsight insight;
  final VoidCallback onTapAction;

  @override
  Widget build(BuildContext context) {
    final accent = insight.accentColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Tag and Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  insight.metricTag.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Icon(insight.icon, color: accent, size: 20),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            insight.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Message
          Expanded(
            child: Text(
              insight.message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Action if present
          if (insight.actionLabel != null)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onTapAction,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      insight.actionLabel!,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: accent,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
