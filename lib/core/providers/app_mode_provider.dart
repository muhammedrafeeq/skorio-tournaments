import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/color_scheme.dart';

// Tournament app is always in tournament mode
enum AppMode { fan, tournament }

class AppModeState {
  final AppMode mode;
  AppModeState({required this.mode});
}

class AppModeNotifier extends Notifier<AppModeState> {
  @override
  AppModeState build() => AppModeState(mode: AppMode.tournament);

  Color get accentColor => SkorioColors.secondary;
}

final appModeProvider = NotifierProvider<AppModeNotifier, AppModeState>(
  () => AppModeNotifier(),
);
