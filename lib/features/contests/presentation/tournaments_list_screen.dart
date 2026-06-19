import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pitch_background.dart';
import '../../../core/widgets/nav_drawer.dart';
import '../../../core/widgets/top_bar.dart';
import '../../../core/widgets/animations.dart';
import '../providers/tournaments_provider.dart';

class TournamentsListScreen extends ConsumerStatefulWidget {
  const TournamentsListScreen({super.key});

  @override
  ConsumerState<TournamentsListScreen> createState() => _TournamentsListScreenState();
}

class _TournamentsListScreenState extends ConsumerState<TournamentsListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedSportFilter = 'all'; // 'all', 'football', 'cricket'
  String _selectedFormatFilter = 'all'; // 'all', 'league', 'knockout'
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tournamentsProvider);

    // Apply Filters
    final filtered = state.tournaments.where((t) {
      final matchesSport = _selectedSportFilter == 'all' || t.sport == _selectedSportFilter;
      final matchesFormat = _selectedFormatFilter == 'all' || t.format == _selectedFormatFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          t.name.toLowerCase().contains(_searchQuery) ||
          t.location.toLowerCase().contains(_searchQuery);

      return matchesSport && matchesFormat && matchesSearch;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: SkorioColors.baseBg,
      appBar: TopBar(scaffoldKey: _scaffoldKey, activeTab: 'tournaments'),
      endDrawer: const NavDrawer(activeTab: 'tournaments'),
      body: Stack(
        children: [
          const PitchBackground(child: SizedBox.expand()),

          // Ambient Background Glows
          Positioned(
            bottom: 100,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkorioColors.secondary.withValues(alpha: 0.03),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: SkorioColors.secondary.withValues(alpha: 0.03)),
              ),
            ),
          ),

          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: SkorioColors.secondary),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      // Search & Filters Panel
                      _buildSearchAndFilters(context),

                      // Tournaments List
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyResultsState()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final tour = filtered[idx];
                                  return StaggeredEntrance(
                                    delay: Duration(milliseconds: 100 + (idx * 50)),
                                    child: _buildTournamentCard(context, tour),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search tournaments by name or city...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Join with invite code
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/tournaments/join'),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
              label: const Text('Join with Invite Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SkorioColors.secondary,
                side: BorderSide(color: SkorioColors.secondary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Sport Filters Row
          Row(
            children: [
              _buildFilterChip("ALL SPORTS", _selectedSportFilter == 'all', () {
                setState(() => _selectedSportFilter = 'all');
              }),
              const SizedBox(width: 8),
              _buildFilterChip("FOOTBALL ⚽", _selectedSportFilter == 'football', () {
                setState(() => _selectedSportFilter = 'football');
              }),
              const SizedBox(width: 8),
              _buildFilterChip("CRICKET 🏏", _selectedSportFilter == 'cricket', () {
                setState(() => _selectedSportFilter = 'cricket');
              }),
            ],
          ),
          const SizedBox(height: 8),

          // Format Filters Row
          Row(
            children: [
              _buildFilterChip("ALL FORMATS", _selectedFormatFilter == 'all', () {
                setState(() => _selectedFormatFilter = 'all');
              }),
              const SizedBox(width: 8),
              _buildFilterChip("LEAGUE 📊", _selectedFormatFilter == 'league', () {
                setState(() => _selectedFormatFilter = 'league');
              }),
              const SizedBox(width: 8),
              _buildFilterChip("KNOCKOUT 🏆", _selectedFormatFilter == 'knockout', () {
                setState(() => _selectedFormatFilter = 'knockout');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? SkorioColors.secondary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? SkorioColors.secondary : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: SkorioTextStyles.labelSm.copyWith(
            color: isSelected ? SkorioColors.secondary : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: Colors.white24, size: 40),
          const SizedBox(height: 12),
          Text(
            "No Matching Tournaments",
            style: SkorioTextStyles.labelMd.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            "Try adjusting your filters or search keywords.",
            style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(BuildContext context, Tournament tour) {
    final liveMatches = tour.matches.where((m) => m.status == 'live').length;
    final completedMatches = tour.matches.where((m) => m.status == 'completed').length;
    final totalMatches = tour.matches.length;

    String statusText = "UPCOMING";
    Color statusColor = SkorioColors.secondary;

    if (liveMatches > 0) {
      statusText = "LIVE NOW";
      statusColor = Colors.redAccent;
    } else if (totalMatches > 0 && completedMatches == totalMatches) {
      statusText = "COMPLETED";
      statusColor = Colors.white54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/tournaments/${tour.id}'),
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          borderColor: statusText == "LIVE NOW" ? Colors.redAccent.withValues(alpha: 0.15) : Colors.white10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      statusText,
                      style: SkorioTextStyles.labelSm.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    tour.format.toUpperCase(),
                    style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 8),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SkorioColors.secondary.withValues(alpha: 0.04),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.emoji_events, color: SkorioColors.secondary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tour.name,
                          style: SkorioTextStyles.labelMd.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${tour.sport.toUpperCase()} · ${tour.teams.length} Teams · ${tour.location}",
                          style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
                ],
              ),
              if (tour.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  tour.description,
                  style: SkorioTextStyles.labelSm.copyWith(color: Colors.white54, fontSize: 13, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
