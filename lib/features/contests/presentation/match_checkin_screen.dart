import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../providers/tournaments_provider.dart';

// ─── Check-in state per match ────────────────────────────────────────────────

class CheckInState {
  final String matchId;
  final List<String> checkedInPlayers; // player names
  CheckInState({required this.matchId, this.checkedInPlayers = const []});

  CheckInState copyWith({List<String>? checkedInPlayers}) =>
      CheckInState(matchId: matchId, checkedInPlayers: checkedInPlayers ?? this.checkedInPlayers);
}

// matchId -> list of checked-in player names
class CheckInNotifier extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() => {};

  void checkIn(String matchId, String playerName) {
    final current = Map<String, List<String>>.from(state);
    current[matchId] = [...(current[matchId] ?? []), playerName];
    state = current;
  }

  List<String> playersFor(String matchId) => state[matchId] ?? [];
}

final checkInProvider = NotifierProvider<CheckInNotifier, Map<String, List<String>>>(
  CheckInNotifier.new,
);

// ─── QR Generator (Admin) ────────────────────────────────────────────────────

class MatchQRScreen extends ConsumerWidget {
  final String tournamentId;
  final String matchId;

  const MatchQRScreen({super.key, required this.tournamentId, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournament = ref.watch(tournamentsProvider).tournaments.firstWhere(
      (t) => t.id == tournamentId,
      orElse: () => Tournament(id: '', name: '', sport: '', format: '', description: '',
          location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0, teams: [], matches: [], prizes: '', creatorId: ''),
    );
    final match = tournament.matches.firstWhere(
      (m) => m.id == matchId,
      orElse: () => TournamentMatch(id: '', homeTeamId: '', awayTeamId: '', date: DateTime.now(), status: '', venue: ''),
    );

    final homeTeam = tournament.teams.firstWhere(
      (t) => t.id == match.homeTeamId,
      orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '', primaryColor: '', secondaryColor: '', players: []),
    );
    final awayTeam = tournament.teams.firstWhere(
      (t) => t.id == match.awayTeamId,
      orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '', primaryColor: '', secondaryColor: '', players: []),
    );

    // QR payload encodes tournament+match IDs
    final qrData = jsonEncode({'t': tournamentId, 'm': matchId, 'ts': DateTime.now().millisecondsSinceEpoch});
    final checkedIn = ref.watch(checkInProvider)[matchId] ?? [];

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Match Check-in QR',
                      style: SkorioTextStyles.headlineMd.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text('${homeTeam.name} vs ${awayTeam.name}',
                      style: SkorioTextStyles.headlineLg.copyWith(color: Colors.white),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(match.venue,
                      style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Players scan this code to check in',
                      style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    if (checkedIn.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('CHECKED IN (${checkedIn.length})',
                          style: SkorioTextStyles.labelSm.copyWith(
                            color: SkorioColors.secondary, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      ),
                      const SizedBox(height: 8),
                      ...checkedIn.map((name) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: SkorioColors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SkorioColors.secondary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: SkorioColors.secondary, size: 16),
                            const SizedBox(width: 10),
                            Text(name, style: SkorioTextStyles.labelMd.copyWith(color: Colors.white)),
                          ],
                        ),
                      )),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: SkorioColors.secondary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => context.push(
                          '/tournaments/$tournamentId/matches/$matchId/scan'),
                        icon: const Icon(Icons.qr_code_scanner, color: SkorioColors.secondary),
                        label: Text('Scan Player QR',
                          style: SkorioTextStyles.labelMd.copyWith(
                            color: SkorioColors.secondary, fontWeight: FontWeight.w700)),
                      ),
                    ),
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

// ─── QR Scanner (Player self check-in) ──────────────────────────────────────

class MatchScanScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;

  const MatchScanScreen({super.key, required this.tournamentId, required this.matchId});

  @override
  ConsumerState<MatchScanScreen> createState() => _MatchScanScreenState();
}

class _MatchScanScreenState extends ConsumerState<MatchScanScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _scanned = false;
  String? _scannedPlayer;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _scanner.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['t'] == widget.tournamentId && data['m'] == widget.matchId) {
        setState(() => _scanned = true);
        _scanner.stop();
        _showNameEntry();
      }
    } catch (_) {}
  }

  void _showNameEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SkorioColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: SkorioColors.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('✅', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('QR Verified!', style: SkorioTextStyles.headlineMd.copyWith(color: SkorioColors.secondary)),
            const SizedBox(height: 4),
            Text('Enter your name to complete check-in.',
              style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Your Name',
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: SkorioColors.surfaceBright,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: SkorioColors.secondary,
                  foregroundColor: SkorioColors.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  ref.read(checkInProvider.notifier).checkIn(widget.matchId, name);
                  Navigator.pop(ctx);
                  setState(() => _scannedPlayer = name);
                },
                child: const Text('Confirm Check-in', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (!_scanned) _scanner.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_scannedPlayer != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text('Checked in!',
                      style: SkorioTextStyles.headlineLg.copyWith(color: SkorioColors.secondary)),
                    const SizedBox(height: 8),
                    Text(_scannedPlayer!,
                      style: SkorioTextStyles.headlineMd.copyWith(color: Colors.white)),
                    const SizedBox(height: 32),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: SkorioColors.secondary,
                        foregroundColor: SkorioColors.onSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.pop(),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              )
            else ...[
              MobileScanner(controller: _scanner, onDetect: _onDetect),
              // Overlay
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: SkorioColors.secondary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 12,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0, right: 0,
                child: Text('Point camera at match QR code',
                  textAlign: TextAlign.center,
                  style: SkorioTextStyles.labelMd.copyWith(color: Colors.white70)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
