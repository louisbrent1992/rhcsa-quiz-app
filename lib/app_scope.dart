import 'package:flutter/widgets.dart';

import 'data/repository.dart';
import 'services/progress_store.dart';

/// Makes the loaded question bank and the progress store available to the
/// whole widget tree without pulling in a state-management package.
class AppScope extends InheritedNotifier<ProgressStore> {
  const AppScope({
    super.key,
    required this.repository,
    required ProgressStore progress,
    required super.child,
  }) : super(notifier: progress);

  final Repository repository;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!;
  }

  static Repository repositoryOf(BuildContext context) =>
      of(context).repository;

  static ProgressStore progressOf(BuildContext context) => of(context).notifier!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repository != oldWidget.repository || super.updateShouldNotify(oldWidget);
}
