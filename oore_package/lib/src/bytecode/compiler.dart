import 'dart:io';
import 'dart:typed_data';

import '../protocol/frames.dart';

/// Result of a bytecode compilation.
class CompileResult {
  const CompileResult.success(this.bytecode)
      : success = true,
        errors = const [];

  const CompileResult.failure(this.errors)
      : success = false,
        bytecode = null;

  final bool success;
  final Uint8List? bytecode;
  final List<CompileError> errors;
}

/// Wraps the `dart_eval` CLI compiler as a subprocess.
class BytecodeCompiler {
  /// Compiles the current project to .evc bytecode.
  ///
  /// Calls: `dart pub run dart_eval compile -k program -o .oore/out.evc`
  static Future<CompileResult> compile({
    String outputPath = '.oore/out.evc',
  }) async {
    // Ensure output directory exists
    await Directory('.oore').create(recursive: true);

    final result = await Process.run(
      'dart',
      ['pub', 'run', 'dart_eval', 'compile', '-k', 'program', '-o', outputPath],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      final errors = _parseErrors(result.stderr as String);
      return CompileResult.failure(errors);
    }

    final bytes = await File(outputPath).readAsBytes();
    return CompileResult.success(Uint8List.fromList(bytes));
  }

  static List<CompileError> _parseErrors(String stderr) {
    // Parse dart analyzer error format:
    // lib/main.dart:42:8: Error: The method 'foo' isn't defined
    final pattern = RegExp(
        r'(.+\.dart):(\d+):(\d+):\s+(?:Error|Warning):\s+(.+)',
        multiLine: true);

    return pattern.allMatches(stderr).map((m) {
      return CompileError(
        file: m.group(1)!,
        line: int.parse(m.group(2)!),
        col: int.parse(m.group(3)!),
        message: m.group(4)!,
      );
    }).toList();
  }
}
