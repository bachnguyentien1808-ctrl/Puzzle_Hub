import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_hub/core/audio/music_player.dart';
import 'package:puzzle_hub/core/audio/sfx_player.dart';
import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:puzzle_hub/core/router/app_router.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/theme/app_theme.dart';
import 'package:puzzle_hub/core/theme/day_phase.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';

class PuzzleHubApp extends ConsumerStatefulWidget {
  const PuzzleHubApp({super.key});

  @override
  ConsumerState<PuzzleHubApp> createState() => _PuzzleHubAppState();
}

class _PuzzleHubAppState extends ConsumerState<PuzzleHubApp>
    with WidgetsBindingObserver {
  late DayPhase _clock = DayPhase.at(ref.read(todayProvider)());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRouter.routerDelegate.addListener(_syncMusic);
    appRouter.routeInformationProvider.addListener(_syncMusic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMusic());
    // Che do tu dong: moi phut kiem tra lai gio de doi sang / chieu / toi.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final p = DayPhase.at(ref.read(todayProvider)());
      if (mounted && p != _clock) setState(() => _clock = p);
    });
  }

  /// Chọn bài nhạc theo màn hình: mỗi game một bài, các trang khác là sảnh chờ.
  void _syncMusic() {
    final path = appRouter.routeInformationProvider.value.uri.path;
    String track;
    if (path.startsWith('/play/')) {
      track = MusicEngine.trackForGame(path.substring('/play/'.length));
    } else if (path == '/daily/play') {
      track = MusicEngine.trackForGame(dailyGameFor(ref.read(todayProvider)()));
    } else {
      track = 'lobby';
    }
    MusicEngine.instance.setTrack(track);
    SfxEngine.setTheme(track);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    MusicEngine.instance.setForeground(
      foreground: state == AppLifecycleState.resumed,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouter.routerDelegate.removeListener(_syncMusic);
    appRouter.routeInformationProvider.removeListener(_syncMusic);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    // Sang -> ban ngay, Toi -> ban dem, Tu dong -> theo gio thuc (sang/chieu/toi).
    final phase = switch (s.themeMode) {
      ThemeMode.light => DayPhase.day,
      ThemeMode.dark => DayPhase.night,
      ThemeMode.system => _clock,
    };
    return MaterialApp.router(
      title: 'Puzzle Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(s.seed, Brightness.light),
      darkTheme: AppTheme.build(s.seed, Brightness.dark),
      themeMode: phase.isDark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 300),
      builder: (context, child) => BackdropPhaseScope(
        phase: phase,
        child: BackdropPreloader(
          phase: phase,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => MusicEngine.instance.kick(),
            child: CandyBackground(
              light: !phase.isDark,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
