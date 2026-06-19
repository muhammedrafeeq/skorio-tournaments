import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../providers/tournaments_provider.dart';

class PlayerRegistrationScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String teamId;

  const PlayerRegistrationScreen({
    super.key,
    required this.tournamentId,
    required this.teamId,
  });

  @override
  ConsumerState<PlayerRegistrationScreen> createState() => _PlayerRegistrationScreenState();
}

class _PlayerRegistrationScreenState extends ConsumerState<PlayerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _jerseyController = TextEditingController();
  String _position = 'MID';
  bool _submitting = false;
  bool _done = false;

  static const _positions = ['GK', 'DEF', 'MID', 'FWD'];

  @override
  void dispose() {
    _nameController.dispose();
    _jerseyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final newPlayer = TournamentPlayer(
      id: 'player_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      jerseyNumber: int.tryParse(_jerseyController.text.trim()) ?? 0,
      position: _position,
    );

    final ok = await ref.read(tournamentsProvider.notifier)
        .addPlayerToTeam(widget.tournamentId, widget.teamId, newPlayer);

    setState(() { _submitting = false; if (ok) _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    final tournament = ref.watch(tournamentsProvider).tournaments.firstWhere(
      (t) => t.id == widget.tournamentId,
      orElse: () => Tournament(id: '', name: '', sport: '', format: '', description: '',
          location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0, teams: [], matches: [], prizes: '', creatorId: ''),
    );

    final team = tournament.teams.firstWhere(
      (t) => t.id == widget.teamId,
      orElse: () => TournamentTeam(id: '', name: 'Unknown Team', logoUrl: '⚽', primaryColor: '', secondaryColor: '', players: []),
    );

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _done ? _buildSuccess(context, team, tournament) : _buildForm(context, team, tournament),
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context, TournamentTeam team, Tournament tournament) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        const Text('✅', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 24),
        Text('You\'re registered!', style: SkorioTextStyles.headlineLg.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        Text(
          'Welcome to ${team.name} in ${tournament.name}.',
          textAlign: TextAlign.center,
          style: SkorioTextStyles.bodyMd.copyWith(color: SkorioColors.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: SkorioColors.secondary,
              foregroundColor: SkorioColors.onSecondary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => context.go('/tournaments/${widget.tournamentId}'),
            child: const Text('View Tournament', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, TournamentTeam team, Tournament tournament) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 4),
              Text('Player Registration', style: SkorioTextStyles.headlineMd.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text('${team.logoUrl} ${team.name} · ${tournament.name}',
              style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
          ),
          const SizedBox(height: 32),
          _buildField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _jerseyController,
            label: 'Jersey Number',
            icon: Icons.tag,
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1 || n > 99) return 'Enter a number 1–99';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text('Position', style: SkorioTextStyles.labelMd.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: _positions.map((pos) {
              final selected = _position == pos;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _position = pos),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? SkorioColors.secondary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? SkorioColors.secondary : Colors.white12,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      pos,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? SkorioColors.secondary : Colors.white54,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SkorioColors.secondary,
                foregroundColor: SkorioColors.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Register', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SkorioColors.secondary),
        ),
      ),
    );
  }
}
