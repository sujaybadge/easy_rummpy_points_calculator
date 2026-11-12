import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/game_screen.dart';
import 'screens/setup_screen.dart';
import 'storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RummyApp());
}

class RummyApp extends StatelessWidget {
  const RummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rummy Points',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green.shade800,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green.shade800,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeLoader(),
    );
  }
}

/// Resumes a saved game if there is one, otherwise shows setup.
class HomeLoader extends StatefulWidget {
  const HomeLoader({super.key});

  @override
  State<HomeLoader> createState() => _HomeLoaderState();
}

class _HomeLoaderState extends State<HomeLoader> {
  late final Future<Game?> _future = GameStorage.loadCurrent();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Game?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final game = snap.data;
        if (game != null) return GameScreen(game: game);
        return const SetupScreen();
      },
    );
  }
}
