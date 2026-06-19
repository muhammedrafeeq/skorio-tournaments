import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tournaments_provider.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class TournamentStatLine {
  final String tournamentId;
  final String tournamentName;
  final String sport;
  final int goals;
  final int assists;
  final int cards;
  final int motm;
  final int appearances;

  const TournamentStatLine({
    required this.tournamentId,
    required this.tournamentName,
    required this.sport,
    required this.goals,
    required this.assists,
    required this.cards,
    required this.motm,
    required this.appearances,
  });
}

class PlayerCareerStats {
  final String playerName;
  final int totalGoals;
  final int totalAssists;
  final int totalCards;
  final int totalMotm;
  final int totalAppearances;
  final int tournamentsPlayed;
  final List<TournamentStatLine> byTournament;

  const PlayerCareerStats({
    required this.playerName,
    required this.totalGoals,
    required this.totalAssists,
    required this.totalCards,
    required this.totalMotm,
    required this.totalAppearances,
    required this.tournamentsPlayed,
    required this.byTournament,
  });
}

// Top-N stat entry for leaderboards
class StatLeader {
  final String playerName;
  final String teamName;
  final String teamLogo;
  final int value;

  const StatLeader({
    required this.playerName,
    required this.teamName,
    required this.teamLogo,
    required this.value,
  });
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class CareerStatsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Builds career stats for a named player across all tournaments
  PlayerCareerStats getCareerStats(String playerName) {
    final tournaments = ref.read(tournamentsProvider).tournaments;
    final List<TournamentStatLine> lines = [];

    for (final t in tournaments) {
      // Find team this player belongs to
      TournamentTeam? playerTeam;
      TournamentPlayer? playerData;
      for (final team in t.teams) {
        final match = team.players.where((p) => p.name == playerName).toList();
        if (match.isNotEmpty) {
          playerTeam = team;
          playerData = match.first;
          break;
        }
      }
      if (playerData == null || playerTeam == null) continue;

      // Count appearances: matches where team played and match is completed
      final appearances = t.matches
          .where((m) =>
              m.status == 'completed' &&
              (m.homeTeamId == playerTeam!.id || m.awayTeamId == playerTeam.id))
          .length;

      lines.add(TournamentStatLine(
        tournamentId: t.id,
        tournamentName: t.name,
        sport: t.sport,
        goals: playerData.goals,
        assists: playerData.assists,
        cards: playerData.cards,
        motm: playerData.motm,
        appearances: appearances,
      ));
    }

    return PlayerCareerStats(
      playerName: playerName,
      totalGoals: lines.fold(0, (s, l) => s + l.goals),
      totalAssists: lines.fold(0, (s, l) => s + l.assists),
      totalCards: lines.fold(0, (s, l) => s + l.cards),
      totalMotm: lines.fold(0, (s, l) => s + l.motm),
      totalAppearances: lines.fold(0, (s, l) => s + l.appearances),
      tournamentsPlayed: lines.length,
      byTournament: lines,
    );
  }

  /// Top N goal scorers for a given tournament
  List<StatLeader> topScorers(String tournamentId, {int limit = 5}) {
    return _leaders(tournamentId, (p) => p.goals, limit: limit);
  }

  /// Top N assist providers for a given tournament
  List<StatLeader> topAssists(String tournamentId, {int limit = 5}) {
    return _leaders(tournamentId, (p) => p.assists, limit: limit);
  }

  /// Top N MOTM winners for a given tournament
  List<StatLeader> topMotm(String tournamentId, {int limit = 5}) {
    return _leaders(tournamentId, (p) => p.motm, limit: limit);
  }

  /// Top N most carded for a given tournament
  List<StatLeader> topCards(String tournamentId, {int limit = 5}) {
    return _leaders(tournamentId, (p) => p.cards, limit: limit);
  }

  List<StatLeader> _leaders(
    String tournamentId,
    int Function(TournamentPlayer) getValue, {
    required int limit,
  }) {
    final tournaments = ref.read(tournamentsProvider).tournaments;
    final t = tournaments.firstWhere((t) => t.id == tournamentId,
        orElse: () => Tournament(
              id: '', name: '', sport: '', format: '', description: '',
              location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0,
              teams: [], matches: [], prizes: '', creatorId: '',
            ));

    final List<StatLeader> leaders = [];
    for (final team in t.teams) {
      for (final player in team.players) {
        final v = getValue(player);
        if (v > 0) {
          leaders.add(StatLeader(
            playerName: player.name,
            teamName: team.name,
            teamLogo: team.logoUrl,
            value: v,
          ));
        }
      }
    }

    leaders.sort((a, b) => b.value.compareTo(a.value));
    return leaders.take(limit).toList();
  }
}

final careerStatsProvider =
    NotifierProvider<CareerStatsNotifier, void>(CareerStatsNotifier.new);
