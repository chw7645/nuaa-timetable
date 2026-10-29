import 'package:flutter/material.dart';

import 'app.dart';
import 'data/local/prefs_store.dart';
import 'features/notifications/notification_service.dart';
import 'state/app_controller.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await PrefsStore.open();
  final themeController = ThemeController(prefs);
  final controller = AppController(prefs: prefs, theme: themeController);

  await NotificationService.instance.init();
  await controller.bootstrap();

  runApp(NuaaTimetableApp(controller: controller));
}
