import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/repository.dart';
import 'screens/home_screen.dart';
import 'services/progress_store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RhcsaQuizApp());
}

class RhcsaQuizApp extends StatefulWidget {
  const RhcsaQuizApp({super.key});

  @override
  State<RhcsaQuizApp> createState() => _RhcsaQuizAppState();
}

class _RhcsaQuizAppState extends State<RhcsaQuizApp> {
  late final Future<(Repository, ProgressStore)> _boot =
      Future.wait([Repository.load(), ProgressStore.load()])
          .then((r) => (r[0] as Repository, r[1] as ProgressStore));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RHCSA Quiz',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: FutureBuilder<(Repository, ProgressStore)>(
        future: _boot,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _BootError(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final (repository, progress) = snapshot.data!;
          return AppScope(
            repository: repository,
            progress: progress,
            child: const HomeScreen(),
          );
        },
      ),
    );
  }
}

class _BootError extends StatelessWidget {
  const _BootError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Could not load the question bank.'),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
