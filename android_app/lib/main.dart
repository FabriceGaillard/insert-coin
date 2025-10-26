import 'package:flutter/material.dart';
// import 'page/apps_list_page.dart';
import 'theme/app_theme.dart';
import 'page/copy_daijisho_config_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: const CopyRetroarchCoresPage(),
    );
  }
}
