import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../providers/tournaments_provider.dart';

class JoinTournamentScreen extends ConsumerStatefulWidget {
  const JoinTournamentScreen({super.key});

  @override
  ConsumerState<JoinTournamentScreen> createState() => _JoinTournamentScreenState();
}

class _JoinTournamentScreenState extends ConsumerState<JoinTournamentScreen> {
  final _codeController = TextEditingController();
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter a valid 6-character code');
      return;
    }

    setState(() { _searching = true; _error = null; });

    final state = ref.read(tournamentsProvider);
    final match = state.tournaments.firstWhere(
      (t) => t.inviteCode == code,
      orElse: () => Tournament(
        id: '', name: '', sport: '', format: '', description: '',
        location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0,
        teams: [], matches: [], prizes: '', creatorId: '',
      ),
    );

    if (match.id.isNotEmpty) {
      setState(() => _searching = false);
      if (mounted) context.push('/tournaments/${match.id}');
      return;
    }

    // Try Supabase lookup if not in local cache
    try {
      final client = sb.Supabase.instance.client;
      final response = await client
          .from('tournaments')
          .select('id')
          .eq('invite_code', code)
          .maybeSingle();

      setState(() => _searching = false);
      if (response != null && mounted) {
        context.push('/tournaments/${response['id']}');
      } else {
        setState(() => _error = 'No tournament found with that code');
      }
    } catch (e) {
      setState(() { _searching = false; _error = 'Could not connect. Check local tournaments.'; });
      // Fallback: already checked local cache above
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      appBar: AppBar(
        backgroundColor: SkorioColors.surface,
        title: Text('Join Tournament', style: SkorioTextStyles.labelMd),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Enter Invite Code', style: SkorioTextStyles.headlineMd),
            const SizedBox(height: 8),
            Text(
              'Ask the tournament admin for the 6-character invite code.',
              style: SkorioTextStyles.bodyMd.copyWith(color: SkorioColors.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '· · · · · ·',
                hintStyle: TextStyle(
                  fontSize: 28,
                  color: SkorioColors.outline,
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: SkorioColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                errorText: _error,
                counterText: '',
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _searching ? null : _join,
                style: FilledButton.styleFrom(
                  backgroundColor: SkorioColors.secondary,
                  foregroundColor: SkorioColors.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _searching
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Join', style: SkorioTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
