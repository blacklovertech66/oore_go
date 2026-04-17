import 'dart:async';
import 'package:watcher/watcher.dart';

/// Watches source files for changes and triggers compilation.
class SourceWatcher {
  SourceWatcher({
    required this.watchPath,
    required this.onChanged,
    this.debounceMs = 200,
    this.extensions = const ['.dart'],
  });

  final String watchPath;
  final Future<void> Function(List<String> changedFiles) onChanged;
  final int debounceMs;
  final List<String> extensions;

  StreamSubscription? _subscription;
  Timer? _debounceTimer;
  final _pendingFiles = <String>{};

  Future<void> start() async {
    final watcher = DirectoryWatcher(watchPath);
    _subscription = watcher.events.listen(_onEvent);
  }

  Future<void> stop() async {
    _debounceTimer?.cancel();
    await _subscription?.cancel();
  }

  void _onEvent(WatchEvent event) {
    final path = event.path;

    // Only watch Dart files
    if (!extensions.any((ext) => path.endsWith(ext))) return;

    // Skip generated files
    if (path.contains('.g.dart') || path.contains('.freezed.dart')) return;

    _pendingFiles.add(path);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: debounceMs), _flush);
  }

  void _flush() {
    if (_pendingFiles.isEmpty) return;
    final files = List<String>.from(_pendingFiles);
    _pendingFiles.clear();
    onChanged(files);
  }
}
