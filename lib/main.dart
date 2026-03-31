import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: NucleusRssApp(),
    ),
  );
}

import 'providers/providers.dart';

class NucleusRssApp extends ConsumerWidget {
  const NucleusRssApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Fallback colors if dynamic colors are not supported (e.g., older Androids)
        final lightTheme = ThemeData(
          colorScheme: lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        );
        final darkTheme = ThemeData(
          colorScheme: darkDynamic ?? ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
          useMaterial3: true,
        );

        return MaterialApp(
          title: 'Nucleus RSS',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
