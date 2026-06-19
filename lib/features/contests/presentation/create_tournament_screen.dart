import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pitch_background.dart';
import '../providers/tournaments_provider.dart';

class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends ConsumerState<CreateTournamentScreen> {
  int _currentStep = 1;
  final int _totalSteps = 6;

  // Step 1
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locController = TextEditingController();
  String _selectedSport = 'football'; // football, cricket, basketball, tennis, badminton, custom
  String _tournamentType = 'teams'; // teams, individual, doubles

  // Step 2 - Format
  String _selectedFormat = 'league'; // league, knockout, league_knockout, groups_knockout, custom

  // Step 3 - Rules
  int _winPts = 3;
  int _drawPts = 1;
  int _lossPts = 0;
  final TextEditingController _prizesController = TextEditingController();

  // Series length per round (number of matches per matchup)
  final Map<String, int> _legsPerRound = {
    'final': 1,
    'third_place': 1,
    'semi': 2,
    'quarter': 1,
    'r16': 1,
    'r32': 1,
    'r64': 1,
  };

  // Step 4 - Teams
  final List<TournamentTeam> _teams = [
    const TournamentTeam(id: 't_mock_1', name: 'Red Panthers', logoUrl: '🐆', primaryColor: '0xFFEF4444', secondaryColor: '0xFF131318', players: []),
    const TournamentTeam(id: 't_mock_2', name: 'Blue Falcons', logoUrl: '🦅', primaryColor: '0xFF3B82F6', secondaryColor: '0xFF131318', players: []),
    const TournamentTeam(id: 't_mock_3', name: 'Green Vipers', logoUrl: '🐍', primaryColor: '0xFF10B981', secondaryColor: '0xFF131318', players: []),
    const TournamentTeam(id: 't_mock_4', name: 'Golden Eagles', logoUrl: '🦅', primaryColor: '0xFFFFD700', secondaryColor: '0xFF131318', players: []),
  ];

  final TextEditingController _teamNameController = TextEditingController();
  String _teamLogoEmoji = '⚽';
  final Color _teamPrimaryColor = SkorioColors.secondary;

  // Step 5 - Draw
  String _drawMethod = 'random'; // random, seeded, random_seeded, manual
  bool _isDrawing = false;
  bool _drawCompleted = false;
  List<TournamentTeam> _drawnOrder = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _locController.dispose();
    _prizesController.dispose();
    _teamNameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tournament Name is required"),
          backgroundColor: SkorioColors.errorContainer,
        ),
      );
      return;
    }
    if (_currentStep == 4 && _teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add at least 2 teams"),
          backgroundColor: SkorioColors.errorContainer,
        ),
      );
      return;
    }
    if (_currentStep == 5 && !_drawCompleted && _drawMethod != 'manual') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please complete the draw first"),
          backgroundColor: SkorioColors.errorContainer,
        ),
      );
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  void _prevStep() {
    setState(() {
      _currentStep--;
    });
  }

  void _addTeam() {
    final name = _teamNameController.text.trim();
    if (name.isEmpty) return;

    final argb = _teamPrimaryColor.toARGB32();
    final hexColor = '0xFF${argb.toRadixString(16).substring(2).toUpperCase()}';

    final mockPlayers = [
      TournamentPlayer(id: 'p_${name}_1', name: 'Player A', jerseyNumber: 10, position: 'FWD'),
      TournamentPlayer(id: 'p_${name}_2', name: 'Player B', jerseyNumber: 8, position: 'MID'),
      TournamentPlayer(id: 'p_${name}_3', name: 'Player C', jerseyNumber: 4, position: 'DEF'),
      TournamentPlayer(id: 'p_${name}_4', name: 'Player D', jerseyNumber: 1, position: 'GK'),
    ];

    setState(() {
      _teams.add(
        TournamentTeam(
          id: 'team_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          logoUrl: _teamLogoEmoji,
          primaryColor: hexColor,
          secondaryColor: '0xFF131318',
          players: mockPlayers,
        ),
      );
      _teamNameController.clear();
      _teamLogoEmoji = '⚽';
    });
  }

  void _removeTeam(int index) {
    setState(() {
      _teams.removeAt(index);
    });
  }

  Future<void> _handlePublish() async {
    final orderedTeams = _drawnOrder.isNotEmpty ? _drawnOrder : _teams;
    final tournament = Tournament(
      id: 'tour_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      sport: _selectedSport,
      format: _selectedFormat,
      description: _descController.text.trim(),
      location: _locController.text.trim(),
      bannerUrl: '',
      winPts: _winPts,
      drawPts: _drawPts,
      lossPts: _lossPts,
      teams: orderedTeams,
      matches: const [],
      prizes: _prizesController.text.trim(),
      creatorId: '',
    );

    final success = await ref.read(tournamentsProvider.notifier).createTournament(tournament);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tournament published successfully!"),
          backgroundColor: SkorioColors.onSecondaryContainer,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: Stack(
        children: [
          const PitchBackground(child: SizedBox.expand()),

          // Ambient Background Glows
          Positioned(
            top: 40,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkorioColors.secondary.withValues(alpha: 0.03),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: SkorioColors.secondary.withValues(alpha: 0.03)),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildProgressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      borderColor: SkorioColors.secondary.withValues(alpha: 0.1),
                      child: _buildStepContent(),
                    ),
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Text(
            "CREATE TOURNAMENT",
            style: SkorioTextStyles.labelMd.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Step $_currentStep of $_totalSteps",
                style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.secondary, fontWeight: FontWeight.bold),
              ),
              Text(
                "${(_currentStep / _totalSteps * 100).round()}% Completed",
                style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: _currentStep / _totalSteps,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(SkorioColors.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Info();
      case 2:
        return _buildStep2Format();
      case 3:
        return _buildStep3Rules();
      case 4:
        return _buildStep4Teams();
      case 5:
        return _buildStep5Draw();
      case 6:
        return _buildStep6Confirm();
      default:
        return Container();
    }
  }

  // ─── Step 1: Basic Info ────────────────────────────────────────────────────

  Widget _buildStep1Info() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("BASIC INFO", "Enter the naming and location details."),
        const SizedBox(height: 18),
        _buildLabel("Tournament Name"),
        _buildTextField(_nameController, "e.g., Sunday Champions League"),
        const SizedBox(height: 16),
        _buildLabel("Description"),
        _buildTextField(_descController, "e.g., Local tournament for sector 5 clubs.", maxLines: 2),
        const SizedBox(height: 16),
        _buildLabel("City / Region"),
        _buildTextField(_locController, "e.g., Mumbai, India"),
        const SizedBox(height: 16),
        _buildLabel("Sport Type"),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip("⚽ FOOTBALL", _selectedSport == 'football', () {
              setState(() => _selectedSport = 'football');
            }),
            _buildChoiceChip("🏏 CRICKET", _selectedSport == 'cricket', () {
              setState(() => _selectedSport = 'cricket');
            }),
            _buildChoiceChip("🏀 BASKETBALL", _selectedSport == 'basketball', () {
              setState(() => _selectedSport = 'basketball');
            }),
            _buildChoiceChip("🎾 TENNIS", _selectedSport == 'tennis', () {
              setState(() => _selectedSport = 'tennis');
            }),
            _buildChoiceChip("🏸 BADMINTON", _selectedSport == 'badminton', () {
              setState(() => _selectedSport = 'badminton');
            }),
            _buildChoiceChip("🎯 CUSTOM", _selectedSport == 'custom', () {
              setState(() => _selectedSport = 'custom');
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildLabel("Tournament Type"),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip("👥 TEAMS", _tournamentType == 'teams', () {
              setState(() => _tournamentType = 'teams');
            }),
            _buildChoiceChip("👤 INDIVIDUAL", _tournamentType == 'individual', () {
              setState(() => _tournamentType = 'individual');
            }),
            _buildChoiceChip("🤝 DOUBLES", _tournamentType == 'doubles', () {
              setState(() => _tournamentType = 'doubles');
            }),
          ],
        ),
      ],
    );
  }

  // ─── Step 2: Format ────────────────────────────────────────────────────────

  Widget _buildStep2Format() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("TOURNAMENT FORMAT", "Choose how teams compete."),
        const SizedBox(height: 18),
        _buildFormatOption(
          'league',
          'Round Robin League',
          'All teams play each other. Auto-generates full fixture list.',
          Icons.grid_view_outlined,
        ),
        const SizedBox(height: 6),
        _buildFormatOption(
          'knockout',
          'Knockout / Elimination',
          'Lose once and you\'re out. Ideal for cups & esports.',
          Icons.account_tree_outlined,
        ),
        const SizedBox(height: 6),
        _buildFormatOption(
          'league_knockout',
          'League + Knockout',
          'Group stage league feeding into a knockout final.',
          Icons.merge_outlined,
        ),
        const SizedBox(height: 6),
        _buildFormatOption(
          'groups_knockout',
          'Groups + Knockout',
          'Teams split into groups. Top teams advance to knockout.',
          Icons.table_chart_outlined,
        ),
        const SizedBox(height: 6),
        _buildFormatOption(
          'custom',
          'Custom Format',
          'Define your own rules. Mix stages as needed.',
          Icons.tune_outlined,
        ),
      ],
    );
  }

  // ─── Step 3: Scoring Rules ─────────────────────────────────────────────────

  Widget _buildStep3Rules() {
    final rounds = [
      ('final',       'Final'),
      ('third_place', '3rd Place Match'),
      ('semi',        'Semifinals'),
      ('quarter',     'Quarter Finals'),
      ('r16',         'Round of 16'),
      ('r32',         'Round of 32'),
      ('r64',         'Round of 64'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("SCORING CONFIG", "Determine points awarded per match outcome."),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPointsConfigTile("WIN POINTS", _winPts, (val) => setState(() => _winPts = val)),
            _buildPointsConfigTile("DRAW POINTS", _drawPts, (val) => setState(() => _drawPts = val)),
            _buildPointsConfigTile("LOSS POINTS", _lossPts, (val) => setState(() => _lossPts = val)),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader("SERIES LENGTH", "Matches per matchup in each round."),
        const SizedBox(height: 12),
        ...rounds.map((r) {
          final key = r.$1;
          final label = r.$2;
          final legs = _legsPerRound[key]!;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: SkorioTextStyles.labelSm.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                _buildLegsToggle(key, legs),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        _buildLabel("Prizes Description"),
        _buildTextField(_prizesController, "e.g., Trophy + ₹10,000 Shop Voucher"),
      ],
    );
  }

  Widget _buildLegsToggle(String roundKey, int current) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [1, 2, 3].map((n) {
        final isActive = current == n;
        return GestureDetector(
          onTap: () => setState(() => _legsPerRound[roundKey] = n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 28,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? SkorioColors.secondary.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive
                    ? SkorioColors.secondary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Center(
              child: Text(
                '$n',
                style: TextStyle(
                  color: isActive ? SkorioColors.secondary : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Step 4: Add Teams ─────────────────────────────────────────────────────

  Widget _buildStep4Teams() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("PARTICIPATING TEAMS", "Add teams to compete (min 2)."),
        const SizedBox(height: 14),
        Row(
          children: [
            DropdownButton<String>(
              value: _teamLogoEmoji,
              dropdownColor: const Color(0xFF131318),
              underline: Container(),
              onChanged: (val) {
                if (val != null) setState(() => _teamLogoEmoji = val);
              },
              items: ['⚽', '🐆', '🦅', '🐍', '🦁', '🛡️', '⚔️']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 20))))
                  .toList(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTextField(_teamNameController, "Team Name", height: 42),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: SkorioColors.secondary, size: 28),
              onPressed: _addTeam,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 12),
        _teams.isEmpty
            ? Center(
                child: Text(
                  "No teams added yet",
                  style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24),
                ),
              )
            : SizedBox(
                height: 240,
                child: ListView.builder(
                  itemCount: _teams.length,
                  itemBuilder: (context, index) {
                    final team = _teams[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        children: [
                          Text(team.logoUrl, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              team.name,
                              style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            onPressed: () => _removeTeam(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  // ─── Step 5: Draw & Schedule ───────────────────────────────────────────────

  Widget _buildStep5Draw() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("DRAW & SCHEDULE", "Choose how match fixtures are generated."),
        const SizedBox(height: 18),

        // Draw method option cards
        _buildDrawOption('random', '🎲', 'Random Draw', 'Teams drawn randomly into the bracket.', isRecommended: true),
        const SizedBox(height: 6),
        _buildDrawOption('seeded', '🏆', 'By Seeding', 'Higher ranked teams get favorable bracket positions.'),
        const SizedBox(height: 6),
        _buildDrawOption('random_seeded', '🔀', 'Random + Seeded', 'Random draw but top seeds are protected.'),
        const SizedBox(height: 6),
        _buildDrawOption('manual', '✏️', 'Manual Assignment', 'You decide who plays who.'),

        const SizedBox(height: 20),

        // START DRAW button
        if (!_drawCompleted)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isDrawing
                  ? null
                  : () {
                      setState(() {
                        _isDrawing = true;
                        _drawnOrder = [];
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: SkorioColors.secondary,
                disabledBackgroundColor: SkorioColors.secondary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _isDrawing ? "DRAWING..." : "START DRAW",
                style: SkorioTextStyles.labelSm.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),

        // Draw animation or completed result
        if (_isDrawing || _drawCompleted) ...[
          const SizedBox(height: 16),
          _buildDrawAnimation(),
        ],
      ],
    );
  }

  Widget _buildDrawOption(String value, String emoji, String title, String desc, {bool isRecommended = false}) {
    final isSelected = _drawMethod == value;
    return GestureDetector(
      onTap: () {
        if (!_isDrawing) {
          setState(() {
            _drawMethod = value;
            _drawCompleted = false;
            _drawnOrder = [];
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? SkorioColors.secondary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? SkorioColors.secondary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: SkorioTextStyles.labelSm.copyWith(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: SkorioColors.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: SkorioTextStyles.labelSm.copyWith(
                              color: SkorioColors.secondary,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: SkorioTextStyles.labelSm.copyWith(
                      color: Colors.white30,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: SkorioColors.secondary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawAnimation() {
    if (_drawCompleted && _drawnOrder.isNotEmpty) {
      // Show final drawn order list
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SkorioColors.secondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SkorioColors.secondary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: SkorioColors.secondary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "DRAW COMPLETED",
                      style: SkorioTextStyles.labelSm.copyWith(
                        color: SkorioColors.secondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._drawnOrder.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final team = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: SkorioColors.secondary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${idx + 1}',
                            style: SkorioTextStyles.labelSm.copyWith(
                              color: SkorioColors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(team.logoUrl, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          team.name,
                          style: SkorioTextStyles.labelSm.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      );
    }

    // Show animation widget
    return _DrawAnimationWidget(
      teams: List<TournamentTeam>.from(_teams),
      onComplete: (drawn) {
        setState(() {
          _drawnOrder = drawn;
          _isDrawing = false;
          _drawCompleted = true;
        });
      },
    );
  }

  // ─── Step 6: Confirm ───────────────────────────────────────────────────────

  Widget _buildStep6Confirm() {
    final formatNames = {
      'league': 'Round Robin League',
      'knockout': 'Knockout / Elimination',
      'league_knockout': 'League + Knockout',
      'groups_knockout': 'Groups + Knockout',
      'custom': 'Custom Format',
    };
    final typeNames = {
      'teams': 'Teams',
      'individual': 'Individual',
      'doubles': 'Doubles',
    };
    final drawNames = {
      'random': 'Random Draw',
      'seeded': 'By Seeding',
      'random_seeded': 'Random + Seeded',
      'manual': 'Manual Assignment',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("PUBLISH TOURNAMENT", "Review details before going live."),
        const SizedBox(height: 18),
        _buildSummaryRow("Name", _nameController.text),
        _buildSummaryRow("Sport", _selectedSport.toUpperCase()),
        _buildSummaryRow("Format", formatNames[_selectedFormat] ?? _selectedFormat),
        _buildSummaryRow("Type", typeNames[_tournamentType] ?? _tournamentType),
        _buildSummaryRow("Draw Method", drawNames[_drawMethod] ?? _drawMethod),
        _buildSummaryRow("Rules", "Win: $_winPts PTS · Draw: $_drawPts PTS · Loss: $_lossPts PTS"),
        _buildSummaryRow("Total Teams", "${_teams.length} Teams"),
        if (_locController.text.isNotEmpty) _buildSummaryRow("City", _locController.text),
        if (_prizesController.text.isNotEmpty) _buildSummaryRow("Prizes", _prizesController.text),
        const SizedBox(height: 8),
        _buildSectionHeader("SERIES LENGTH", "Matches per round."),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ('final',       'Final'),
            ('third_place', '3rd Place'),
            ('semi',        'Semis'),
            ('quarter',     'QF'),
            ('r16',         'R16'),
            ('r32',         'R32'),
            ('r64',         'R64'),
          ].map((r) {
            final legs = _legsPerRound[r.$1]!;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                children: [
                  Text(r.$2, style: SkorioTextStyles.labelSm.copyWith(color: Colors.white38, fontSize: 9)),
                  const SizedBox(height: 2),
                  Text(
                    '$legs ${legs == 1 ? 'leg' : 'legs'}',
                    style: SkorioTextStyles.labelSm.copyWith(
                      color: SkorioColors.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: SkorioTextStyles.labelMd.copyWith(color: SkorioColors.secondary, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: SkorioTextStyles.labelSm.copyWith(color: Colors.white54, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, double? height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? SkorioColors.secondary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? SkorioColors.secondary : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: SkorioTextStyles.labelSm.copyWith(
            color: isSelected ? SkorioColors.secondary : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFormatOption(String value, String title, String desc, IconData icon) {
    final isSelected = _selectedFormat == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? SkorioColors.secondary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? SkorioColors.secondary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? SkorioColors.secondary : Colors.white24, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: SkorioTextStyles.labelSm.copyWith(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: SkorioColors.secondary, size: 13),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsConfigTile(String label, int value, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white54, size: 14),
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              Text(
                "$value",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white54, size: 14),
                onPressed: () => onChanged(value + 1),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final bool continueEnabled = _currentStep != 5 || _drawCompleted || _drawMethod == 'manual';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 1)
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("BACK", style: SkorioTextStyles.labelSm.copyWith(color: Colors.white70)),
            )
          else
            const SizedBox(),
          ElevatedButton(
            onPressed: continueEnabled ? (_currentStep == _totalSteps ? _handlePublish : _nextStep) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: SkorioColors.secondary,
              disabledBackgroundColor: SkorioColors.secondary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _currentStep == _totalSteps ? "PUBLISH" : "CONTINUE",
              style: SkorioTextStyles.labelSm.copyWith(color: Colors.black, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Draw Animation Widget ─────────────────────────────────────────────────────

class _DrawAnimationWidget extends StatefulWidget {
  final List<TournamentTeam> teams;
  final void Function(List<TournamentTeam> drawn) onComplete;

  const _DrawAnimationWidget({
    required this.teams,
    required this.onComplete,
  });

  @override
  State<_DrawAnimationWidget> createState() => _DrawAnimationWidgetState();
}

class _DrawAnimationWidgetState extends State<_DrawAnimationWidget> with TickerProviderStateMixin {
  late List<TournamentTeam> _pool;
  final List<TournamentTeam?> _slots = [];
  Timer? _timer;
  int _nextSlot = 0;

  // Per-slot animation controllers
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _scaleAnims = [];
  final List<Animation<double>> _fadeAnims = [];

  @override
  void initState() {
    super.initState();
    _pool = List<TournamentTeam>.from(widget.teams)..shuffle();
    for (int i = 0; i < widget.teams.length; i++) {
      _slots.add(null);
      final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
      _controllers.add(ctrl);
      _scaleAnims.add(Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: ctrl, curve: Curves.elasticOut)));
      _fadeAnims.add(Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeIn)));
    }

    _timer = Timer.periodic(const Duration(milliseconds: 400), _onTick);
  }

  void _onTick(Timer timer) {
    if (_nextSlot >= widget.teams.length) {
      timer.cancel();
      final drawn = _slots.whereType<TournamentTeam>().toList();
      widget.onComplete(drawn);
      return;
    }

    // Pick a random team from the remaining pool
    final idx = (_pool.length * (DateTime.now().microsecondsSinceEpoch % 1000) / 1000).floor().clamp(0, _pool.length - 1);
    final picked = _pool.removeAt(idx);

    setState(() {
      _slots[_nextSlot] = picked;
    });
    _controllers[_nextSlot].forward(from: 0);
    _nextSlot++;
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // DRAW POOL
        Text(
          "DRAW POOL",
          style: SkorioTextStyles.labelSm.copyWith(
            color: Colors.white30,
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.teams.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final team = widget.teams[i];
              final isPlaced = _slots.contains(team);
              return _buildTeamCard(team, isPlaced: isPlaced);
            },
          ),
        ),

        const SizedBox(height: 16),

        // DRAW ORDER
        Text(
          "DRAW ORDER",
          style: SkorioTextStyles.labelSm.copyWith(
            color: Colors.white30,
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _slots.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final team = _slots[i];
              if (team == null) {
                // Empty slot
                return Container(
                  width: 56,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${i + 1}',
                        style: SkorioTextStyles.labelSm.copyWith(
                          color: Colors.white12,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return FadeTransition(
                opacity: _fadeAnims[i],
                child: ScaleTransition(
                  scale: _scaleAnims[i],
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildTeamCard(team, isPlaced: false, showSlotNum: i + 1),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(TournamentTeam team, {required bool isPlaced, int? showSlotNum}) {
    return Container(
      width: 56,
      height: showSlotNum != null ? 72 : 60,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isPlaced
            ? Colors.white.withValues(alpha: 0.03)
            : SkorioColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPlaced
              ? Colors.white.withValues(alpha: 0.08)
              : SkorioColors.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSlotNum != null)
            Text(
              '$showSlotNum',
              style: SkorioTextStyles.labelSm.copyWith(
                color: SkorioColors.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          Text(
            team.logoUrl,
            style: TextStyle(
              fontSize: 18,
              color: isPlaced ? Colors.white.withValues(alpha: 0.3) : null,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            team.name,
            style: SkorioTextStyles.labelSm.copyWith(
              color: isPlaced ? Colors.white24 : Colors.white70,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
