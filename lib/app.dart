import 'package:flutter/material.dart';

import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widget_bridge/widget_sync_service.dart';

class NuaaTimetableApp extends StatefulWidget {
  const NuaaTimetableApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<NuaaTimetableApp> createState() => _NuaaTimetableAppState();
}

class _NuaaTimetableAppState extends State<NuaaTimetableApp>
    with WidgetsBindingObserver {
  DateTime? _lastDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastDate = _today();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = _today();
    if (_lastDate != today) {
      _lastDate = today;
      // 跨天后小组件需要重新计算"今天剩余几门课"。
      WidgetSyncService.instance.refresh();
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[controller, controller.theme]),
      builder: (context, _) {
        return MaterialApp(
          title: '南航课程表',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(seed: controller.theme.seed),
          darkTheme: AppTheme.dark(seed: controller.theme.seed),
          themeMode: controller.theme.mode,
          home: AppScope(
            controller: controller,
            child: controller.hasData ? const HomePage() : const LoginPage(),
          ),
          builder: (context, child) {
            // 锁定文字缩放上限，避免课程块在超大字号下溢出。
            final media = MediaQuery.of(context);
            final scale = media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.25,
            );
            return MediaQuery(
              data: media.copyWith(textScaler: scale),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
