import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_agent/services/ai_service.dart';
import 'package:private_agent/services/app_launcher_service.dart';
import 'package:private_agent/services/telegram_service.dart';
import 'package:private_agent/services/action_handler.dart';
import 'package:private_agent/services/task_executor.dart';
import 'package:private_agent/services/screen_automation_service.dart';
import 'package:private_agent/models/agent_action.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiService YOLO Mode Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'api_yolo_mode': false,
      });
    });

    test('YOLO mode toggle and persistence', () async {
      final aiService = AiService();
      await aiService.init();
      expect(aiService.yoloMode, isFalse);

      await aiService.saveYoloMode(true);
      expect(aiService.yoloMode, isTrue);

      final aiService2 = AiService();
      await aiService2.init();
      expect(aiService2.yoloMode, isTrue);
    });
  });

  group('AppLauncherService Blocked Apps & Exceptions Tests', () {
    const channel = MethodChannel('installed_apps');

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'blocked_apps_packages': ['com.blocked.app'],
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getInstalledApps') {
          return [
            {
              'name': 'BlockedApp',
              'packageName': 'com.blocked.app',
              'package_name': 'com.blocked.app',
            },
            {
              'name': 'NormalApp',
              'packageName': 'com.normal.app',
              'package_name': 'com.normal.app',
            }
          ];
        }
        if (methodCall.method == 'startApp') {
          return true;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Blocked apps configuration and filtering', () async {
      final appLauncher = AppLauncherService();
      
      // Test getBlockedApps
      final blocked = await appLauncher.getBlockedApps();
      expect(blocked, contains('com.blocked.app'));

      // Test saveBlockedApps
      await appLauncher.saveBlockedApps(['com.blocked.app', 'com.blocked.app2']);
      final blocked2 = await appLauncher.getBlockedApps();
      expect(blocked2, contains('com.blocked.app2'));
    });

    test('AppNotFoundException throwing when app does not exist', () async {
      final appLauncher = AppLauncherService();
      
      expect(
        () => appLauncher.openApp('NonExistentApp12345'),
        throwsA(isA<AppNotFoundException>()),
      );
    });

    test('AppBlockedException throwing when app is blocked', () async {
      final appLauncher = AppLauncherService();
      
      expect(
        () => appLauncher.openApp('BlockedApp'),
        throwsA(isA<AppBlockedException>()),
      );
    });

    test('openApp returns Opened when app is normal and not blocked', () async {
      final appLauncher = AppLauncherService();
      final result = await appLauncher.openApp('NormalApp');
      expect(result, equals('Opened NormalApp'));
    });
  });

  group('TelegramService Whitelist & Approve Mode Tests', () {
    late AiService aiService;
    late ActionHandler actionHandler;
    late TelegramService telegramService;
    final List<Map<String, dynamic>> sentMessages = [];

    setUp(() async {
      sentMessages.clear();
      SharedPreferences.setMockInitialValues({
        'telegram_bot_token': 'mock_token',
        'telegram_enabled': true,
        'telegram_chat_id_whitelist': '12345,67890',
        'api_yolo_mode': false,
      });

      aiService = AiService();
      await aiService.init();

      actionHandler = ActionHandler();
      telegramService = TelegramService(actionHandler, aiService);
      
      telegramService.httpClient = MockClient((request) async {
        return http.Response(jsonEncode({'ok': true, 'result': []}), 200);
      });
      
      await telegramService.init();
    });

    tearDown(() {
      telegramService.httpClient = http.Client();
      telegramService.stopPolling();
    });

    test('Unauthorized chat ID is blocked and notified', () async {
      telegramService.stopPolling(); // Stop setup's polling
      sentMessages.clear();

      bool isFirstPoll = true;
      telegramService.httpClient = MockClient((request) async {
        final urlStr = request.url.toString();
        final body = request.body;
        if (urlStr.contains('getUpdates')) {
          if (isFirstPoll) {
            isFirstPoll = false;
            return http.Response(jsonEncode({
              'ok': true,
              'result': [
                {
                  'update_id': 5,
                  'message': {
                    'text': 'some command',
                    'chat': {'id': 99999} // Not in whitelist (12345, 67890)
                  }
                }
              ]
            }), 200);
          }
          return http.Response(jsonEncode({'ok': true, 'result': []}), 200);
        } else if (urlStr.contains('sendMessage')) {
          final payload = jsonDecode(body);
          sentMessages.add(payload);
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      telegramService.startPolling();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sentMessages, isNotEmpty);
      final unauthorizedMsg = sentMessages.firstWhere(
        (m) => m['chat_id'] == '99999',
        orElse: () => {},
      );
      expect(unauthorizedMsg, isNotEmpty);
      expect(unauthorizedMsg['text'], contains('Unauthorized Chat ID'));
    });

    test('Approve Mode blocks command execution if YOLO is false', () async {
      telegramService.stopPolling(); // Stop setup's polling
      sentMessages.clear();

      bool isFirstPoll = true;
      telegramService.httpClient = MockClient((request) async {
        final urlStr = request.url.toString();
        final body = request.body;
        if (urlStr.contains('getUpdates')) {
          if (isFirstPoll) {
            isFirstPoll = false;
            return http.Response(jsonEncode({
              'ok': true,
              'result': [
                {
                  'update_id': 10,
                  'message': {
                    'text': 'do something',
                    'chat': {'id': 12345} // Whitelisted
                  }
                }
              ]
            }), 200);
          }
          return http.Response(jsonEncode({'ok': true, 'result': []}), 200);
        } else if (urlStr.contains('sendMessage')) {
          final payload = jsonDecode(body);
          sentMessages.add(payload);
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      expect(aiService.yoloMode, isFalse);

      telegramService.startPolling();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sentMessages, isNotEmpty);
      final blockedMsg = sentMessages.firstWhere(
        (m) => m['chat_id'] == '12345',
        orElse: () => {},
      );
      expect(blockedMsg, isNotEmpty);
      expect(blockedMsg['text'], contains('blocked in Approve Mode'));
    });
  });

  group('Foreground App Blocking Tests (TaskExecutor & ActionHandler)', () {
    const channel = MethodChannel('com.privateagent/accessibility');
    late ScreenAutomationService screenService;
    late AppLauncherService appLauncher;
    late AiService aiService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'blocked_apps_packages': ['com.blocked.app'],
        'api_yolo_mode': true,
      });

      screenService = ScreenAutomationService();
      appLauncher = AppLauncherService();
      aiService = AiService();
      await aiService.init();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isServiceRunning') {
          return true;
        }
        if (methodCall.method == 'getCurrentPackage') {
          return 'com.blocked.app';
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('TaskExecutor throws AppBlockedException when foreground app is blocked', () async {
      final executor = TaskExecutor(
        aiService: aiService,
        screenService: screenService,
        appLauncher: appLauncher,
      );

      expect(
        () => executor.executeTask('test goal'),
        throwsA(isA<AppBlockedException>()),
      );
    });

    test('ActionHandler execution returns failure result with AppBlockedException when app is blocked', () async {
      final actionHandler = ActionHandler();
      final action = AgentAction(
        action: 'read_screen',
        params: {},
        response: 'Reading screen...',
      );

      final result = await actionHandler.execute(action, aiService: aiService);
      expect(result.success, isFalse);
      expect(result.details, contains('AppBlockedException'));
    });

    test('TaskExecutor throws AccessibilityServiceException when accessibility service is disabled', () async {
      // Temporarily change isServiceRunning mock return value
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isServiceRunning') {
          return false;
        }
        return null;
      });

      final executor = TaskExecutor(
        aiService: aiService,
        screenService: screenService,
        appLauncher: appLauncher,
      );

      expect(
        () => executor.executeTask('test goal'),
        throwsA(isA<AccessibilityServiceException>()),
      );

      // Restore mock handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isServiceRunning') {
          return true;
        }
        if (methodCall.method == 'getCurrentPackage') {
          return 'com.blocked.app';
        }
        return null;
      });
    });

    test('ActionHandler execution maps ShizukuNotRunningException to success: false', () async {
      final actionHandler = ActionHandler();
      final action = AgentAction(
        action: 'run_adb_command',
        params: {'command': 'pm list packages'},
        response: 'Running command...',
      );

      final result = await actionHandler.execute(action, aiService: aiService);
      expect(result.success, isFalse);
      expect(result.details, contains('ShizukuNotRunningException'));
    });
  });
}
