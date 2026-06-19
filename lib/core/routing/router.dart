import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/notification_settings_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/contests/presentation/tournament_dashboard_screen.dart';
import '../../features/contests/presentation/tournaments_list_screen.dart';
import '../../features/contests/presentation/create_tournament_screen.dart';
import '../../features/contests/presentation/tournament_detail_screen.dart';
import '../../features/contests/presentation/live_match_screen.dart';
import '../../features/contests/presentation/join_tournament_screen.dart';
import '../../features/contests/presentation/player_profile_screen.dart';
import '../../features/contests/presentation/player_registration_screen.dart';
import '../../features/contests/presentation/head_to_head_screen.dart';
import '../../features/contests/presentation/match_checkin_screen.dart';
import '../../features/contests/presentation/scoring/scoring_screen_router.dart';
import '../widgets/main_shell.dart';

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      final reverseTween = Tween(
        begin: Offset.zero,
        end: const Offset(-0.25, 0.0),
      ).chain(CurveTween(curve: Curves.easeInCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: SlideTransition(
          position: secondaryAnimation.drive(reverseTween),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.value != null;
      final goingToLogin = state.matchedLocation == '/login';
      if (!isLoggedIn && !goingToLogin) return '/login';
      if (isLoggedIn && goingToLogin) return '/tournaments/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (ctx, s) => _slidePage(s, const LoginScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/tournaments/dashboard', pageBuilder: (ctx, s) => _slidePage(s, const TournamentDashboardScreen())),
          GoRoute(path: '/tournaments',           pageBuilder: (ctx, s) => _slidePage(s, const TournamentsListScreen())),
          GoRoute(path: '/tournaments/standings', pageBuilder: (ctx, s) => _slidePage(s, const TournamentsListScreen())),
          GoRoute(path: '/tournaments/teams',     pageBuilder: (ctx, s) => _slidePage(s, const TournamentsListScreen())),
          GoRoute(path: '/profile',               pageBuilder: (ctx, s) => _slidePage(s, const ProfileScreen())),
        ],
      ),
      GoRoute(path: '/notifications', pageBuilder: (ctx, s) => _slidePage(s, const NotificationSettingsScreen())),
      GoRoute(path: '/tournaments/create', pageBuilder: (ctx, s) => _slidePage(s, const CreateTournamentScreen())),
      GoRoute(
        path: '/tournaments/:id',
        pageBuilder: (ctx, s) => _slidePage(s, TournamentDetailScreen(tournamentId: s.pathParameters['id'] ?? '')),
      ),
      GoRoute(
        path: '/tournaments/join',
        pageBuilder: (ctx, s) => _slidePage(s, const JoinTournamentScreen()),
      ),
      GoRoute(
        path: '/players/:name',
        pageBuilder: (ctx, s) => _slidePage(s, PlayerProfileScreen(
          playerName: Uri.decodeComponent(s.pathParameters['name'] ?? ''),
        )),
      ),
      GoRoute(
        path: '/tournaments/:id/live/:matchId',
        pageBuilder: (ctx, s) => _slidePage(s, LiveMatchScreen(
          tournamentId: s.pathParameters['id'] ?? '',
          matchId: s.pathParameters['matchId'] ?? '',
        )),
      ),
      GoRoute(
        path: '/tournaments/:id/register/:teamId',
        pageBuilder: (ctx, s) => _slidePage(s, PlayerRegistrationScreen(
          tournamentId: s.pathParameters['id'] ?? '',
          teamId: s.pathParameters['teamId'] ?? '',
        )),
      ),
      GoRoute(
        path: '/tournaments/:id/h2h/:teamA/:teamB',
        pageBuilder: (ctx, s) => _slidePage(s, HeadToHeadScreen(
          tournamentId: s.pathParameters['id'] ?? '',
          teamAId: s.pathParameters['teamA'] ?? '',
          teamBId: s.pathParameters['teamB'] ?? '',
        )),
      ),
      GoRoute(
        path: '/tournaments/:id/matches/:matchId/qr',
        pageBuilder: (ctx, s) => _slidePage(s, MatchQRScreen(
          tournamentId: s.pathParameters['id'] ?? '',
          matchId: s.pathParameters['matchId'] ?? '',
        )),
      ),
      GoRoute(
        path: '/tournaments/:id/matches/:matchId/scan',
        pageBuilder: (ctx, s) => _slidePage(s, MatchScanScreen(
          tournamentId: s.pathParameters['id'] ?? '',
          matchId: s.pathParameters['matchId'] ?? '',
        )),
      ),
      GoRoute(
        path: '/tournaments/:id/matches/:matchId/score',
        pageBuilder: (ctx, s) => _slidePage(s, ScoringScreenRouter(
          tournamentId: s.pathParameters['id'] ?? '',
          matchId: s.pathParameters['matchId'] ?? '',
        )),
      ),
    ],
  );
});
