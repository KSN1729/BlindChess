import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'services/lichess_service.dart';

void main() async {
  // Ensure framework services are initialized before accessing local storage
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.loadSettings();
  await LichessService.instance.init();
  runApp(const MyApp());
}

/// [MyApp]
/// The entry point application widget. It instantiates the [MaterialApp] configuration,
/// customizes the theme properties, and determines the initial [HomeScreen] route.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the isDarkMode state to dynamically switch themes
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService.instance.isDarkModeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'BlindChess',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const HomeScreen(),
          onGenerateRoute: (settings) {
            final name = settings.name ?? '';
            if (name.startsWith('/?') || name.contains('code=')) {
              try {
                final uri = Uri.parse(
                  name.startsWith('/')
                      ? 'org.blindchess.app://oauth-callback$name'
                      : name,
                );
                LichessService.instance.handleIncomingUri(uri);
              } catch (e) {
                debugPrint('Failed to parse incoming deep link route: $e');
              }
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              );
            }
            return null;
          },
          onUnknownRoute: (settings) {
            return MaterialPageRoute(builder: (context) => const HomeScreen());
          },
        );
      },
    );
  }
}
