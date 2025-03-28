import 'dart:async';
import 'dart:io' as io;

import 'package:dispose_scope/dispose_scope.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patrol_cli/src/crossplatform/flutter_tool.dart';
import 'package:patrol_cli/src/runner/flutter_command.dart';
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import '../src/mocks.dart';

void main() {
  const flutterCommand = FlutterCommand('flutter');

  late FlutterTool flutterTool;
  late MockProcessManager processManager;
  late Platform platform;
  late StreamController<List<int>> stdinController;

  setUp(() {
    final disposeScope = DisposeScope();
    stdinController = StreamController<List<int>>();
    processManager = MockProcessManager();
    platform = FakePlatform();

    flutterTool = FlutterTool(
      logger: MockLogger(),
      parentDisposeScope: disposeScope,
      processManager: processManager,
      platform: platform,
      stdin: stdinController.stream,
    );
  });

  tearDown(() {
    stdinController.close();
  });

  group(
    'FlutterTool',
    () {
      test(
        'attach passes deviceId correctly',
        () {
          final process = MockProcess();
          when(() => process.stdout)
              .thenAnswer((_) => Stream<List<int>>.fromIterable([]));
          when(() => process.stderr)
              .thenAnswer((_) => Stream<List<int>>.fromIterable([]));
          when(() => processManager.start(any()))
              .thenAnswer((_) async => process);

          flutterTool.attach(
            flutterCommand: flutterCommand,
            deviceId: 'testDeviceId',
            target: 'target',
            appId: 'appId',
            dartDefines: {},
            openBrowser: false,
          );

          verify(
            () => processManager.start(any(that: contains('testDeviceId'))),
          );
        },
      );

      test(
        'quits and cleans up when q is pressed',
        () async {
          final process = MockProcess();
          final completer = Completer<void>();
          var uninstallCalled = false;

          when(() => process.stdout)
              .thenAnswer((_) => Stream<List<int>>.fromIterable([]));
          when(() => process.stderr)
              .thenAnswer((_) => Stream<List<int>>.fromIterable([]));
          when(() => process.stdin)
              .thenReturn(io.IOSink(StreamController<List<int>>().sink));
          when(() => process.kill()).thenAnswer((_) {
            completer.complete();
            return true;
          });
          when(() => processManager.start(any()))
              .thenAnswer((_) async => process);

          // Start the attach process
          final future = flutterTool.attach(
            flutterCommand: flutterCommand,
            deviceId: 'testDeviceId',
            target: 'target',
            appId: 'appId',
            dartDefines: {},
            openBrowser: false,
            onQuit: () async {
              uninstallCalled = true;
            },
          );

          // Simulate pressing 'q'
          stdinController.add('q'.codeUnits);

          // Wait for the process to be killed
          await completer.future;

          // Verify the process was killed
          verify(() => process.kill()).called(1);

          // Verify the uninstall function was called
          expect(uninstallCalled, isTrue);

          // The future should complete
          await future;
        },
      );
    },
  );
}
