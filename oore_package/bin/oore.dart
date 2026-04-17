import 'dart:io';
import 'package:args/args.dart';
import '../lib/oore_flutter.dart';

/// CLI wrapper for Oore Flutter SDK. (V1)
/// 
/// Usage:
///   dart run oore_flutter:oore serve
///   dart run oore_flutter:oore compile
void main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('serve', ArgParser()
      ..addOption('port', abbr: 'p', defaultsTo: '7777')
      ..addOption('watch', abbr: 'w', defaultsTo: 'lib/')
    )
    ..addCommand('compile');

  if (args.isEmpty) {
    _printUsage(parser);
    return;
  }

  final results = parser.parse(args);

  switch (results.command?.name) {
    case 'serve':
      final cmd = results.command!;
      final port = int.tryParse(cmd['port']) ?? 7777;
      final watch = cmd['watch'] as String;

      print('\x1B[32m[oore]\x1B[0m Starting Development Server...');
      
      // We run a mock app as OoreDevServer expects an entry point
      await OoreDevServer.run(
        app: null, 
        config: OoreConfig(
          port: port,
          watchPath: watch,
          enableHotReload: true,
          showQrInTerminal: true,
        ),
      );
      break;

    case 'compile':
      print('\x1B[32m[oore]\x1B[0m Compiling project to bytecode...');
      final result = await BytecodeCompiler.compile();
      if (result.success) {
        print('\x1B[32m[oore]\x1B[0m Success! Bytecode generated.');
      } else {
        print('\x1B[31m[oore]\x1B[0m Compile failed.');
      }
      break;

    default:
      _printUsage(parser);
  }
}

void _printUsage(ArgParser parser) {
  print('Oore CLI v1.0.0');
  print('Usage: dart run oore_flutter:oore <command> [options]');
  print('\nCommands:');
  print('  serve     Start the dev server with hot-reload and QR pairing');
  print('  compile   Force compile the project to .evc bytecode');
}
