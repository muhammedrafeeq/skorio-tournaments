import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../providers/career_stats_provider.dart';

class PlayerProfileScreen extends ConsumerWidget {
  final String playerName;

  const PlayerProfileScreen({super.key, required this.playerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.read(careerStatsProvider.notifier).getCareerStats(playerName);

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      appBar: AppBar(
        backgroundColor: SkorioColors.surface,
        title: Text(playerName, style: SkorioTextStyles.labelMd),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Player avatar + name header
            _PlayerHeader(stats: stats),
            const SizedBox(height: 20),

            // Career totals grid
            Text('Career Statistics', style: SkorioTextStyles.headlineMd),
            const SizedBox(height: 12),
            _CareerTotalsGrid(stats: stats),
            const SizedBox(height: 24),

            // Per-tournament breakdown
            if (stats.byTournament.isNotEmpty) ...[
              Text('Tournament History', style: SkorioTextStyles.headlineMd),
              const SizedBox(height: 12),
              ...stats.byTournament.map((line) => _TournamentStatRow(line: line)),
            ],

            if (stats.byTournament.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      const Text('🏃', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('No tournament history yet',
                          style: SkorioTextStyles.bodyMd.copyWith(color: SkorioColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  final PlayerCareerStats stats;
  const _PlayerHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SkorioColors.primaryContainer.withValues(alpha: 0.3),
              border: Border.all(color: SkorioColors.primaryContainer, width: 2),
            ),
            child: Center(
              child: Text(
                stats.playerName.isNotEmpty ? stats.playerName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: SkorioColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stats.playerName, style: SkorioTextStyles.headlineMd),
                const SizedBox(height: 4),
                Text(
                  '${stats.tournamentsPlayed} tournament${stats.tournamentsPlayed != 1 ? "s" : ""}  ·  ${stats.totalAppearances} appearances',
                  style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerTotalsGrid extends StatelessWidget {
  final PlayerCareerStats stats;
  const _CareerTotalsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _StatTile(emoji: '⚽', label: 'Goals', value: stats.totalGoals, color: SkorioColors.secondary),
        _StatTile(emoji: '🎯', label: 'Assists', value: stats.totalAssists, color: SkorioColors.primary),
        _StatTile(emoji: '🏆', label: 'MOTM', value: stats.totalMotm, color: SkorioColors.tertiary),
        _StatTile(emoji: '🟨', label: 'Cards', value: stats.totalCards, color: SkorioColors.errorContainer),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;
  final Color color;

  const _StatTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toString(),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
              ),
              Text(label, style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TournamentStatRow extends StatelessWidget {
  final TournamentStatLine line;
  const _TournamentStatRow({required this.line});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.tournamentName, style: SkorioTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SkorioColors.surfaceBright,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  line.sport.toUpperCase(),
                  style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(emoji: '⚽', value: line.goals),
              _MiniStat(emoji: '🎯', value: line.assists),
              _MiniStat(emoji: '🏆', value: line.motm),
              _MiniStat(emoji: '🟨', value: line.cards),
              const Spacer(),
              Text(
                '${line.appearances} apps',
                style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String emoji;
  final int value;
  const _MiniStat({required this.emoji, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            value.toString(),
            style: SkorioTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
