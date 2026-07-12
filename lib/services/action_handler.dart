import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/agent_action.dart';
import '../models/chat_message.dart';
import '../models/plan_step.dart';
import 'app_launcher_service.dart';
import 'contacts_service.dart';
import 'communication_service.dart';
import 'alarm_service.dart';
import 'system_control_service.dart';
import 'shizuku_service.dart';
import 'screen_automation_service.dart';
import 'task_executor.dart';
import 'ai_service.dart';

class McpToolCallException implements Exception {
  final String message;
  McpToolCallException(this.message);
  @override
  String toString() => 'McpToolCallException: $message';
}

class ActionHandler {
  final AppLauncherService _appLauncher = AppLauncherService();
  final ContactsService _contacts = ContactsService();
  final CommunicationService _communication = CommunicationService();
  final AlarmService _alarm = AlarmService();
  final SystemControlService _systemControl = SystemControlService();
  final ShizukuService _shizuku = ShizukuService();
  final ScreenAutomationService _screenAutomation = ScreenAutomationService();

  TaskExecutor? _currentExecutor;

  ShizukuService get shizuku => _shizuku;
  ScreenAutomationService get screenAutomation => _screenAutomation;

  void cancelCurrentTask() {
    _currentExecutor?.cancel();
  }

  /// Execute an action and return the result
  Future<AgentActionResult> execute(
    AgentAction action, {
    AiService? aiService,
    void Function(String)? onProgress,
    void Function(String, {int? stepIndex, PlanStepStatus? status})? onStepProgress,
    Future<bool> Function(Map<String, dynamic> action)? onConfirmAction,
  }) async {
    try {
      if (aiService != null &&
          !aiService.yoloMode &&
          onConfirmAction != null &&
          action.action != 'general_query' &&
          action.action != 'execute_task') {
        final approved = await onConfirmAction({
          'action': action.action,
          'params': action.params,
          'reasoning': action.response,
        });
        if (!approved) {
          return AgentActionResult(
            actionType: action.action,
            success: false,
            details: 'Execution canceled by user.',
          );
        }
      }

      // Check if the current foreground package is blocked for screen automation actions
      final screenActions = {
        'read_screen',
        'click_element',
        'type_on_screen',
        'scroll_screen',
        'press_back',
      };
      if (screenActions.contains(action.action)) {
        final pkg = await _screenAutomation.getCurrentPackage();
        final blocked = await _appLauncher.getBlockedApps();
        if (pkg != null && blocked.contains(pkg)) {
          throw AppBlockedException('The active foreground application "$pkg" is blocked by security permissions.');
        }
      }

      String result;

      switch (action.action) {
        case 'open_app':
          result = await _appLauncher.openApp(
            action.params['app_name'] as String? ?? '',
          );
          break;

        case 'make_call':
          result = await _communication.makeCall(
            contactName: action.params['contact_name'] as String?,
            phoneNumber: action.params['phone_number'] as String?,
          );
          break;

        case 'send_sms':
          result = await _communication.sendSms(
            contactName: action.params['contact_name'] as String?,
            phoneNumber: action.params['phone_number'] as String?,
            message: action.params['message'] as String? ?? '',
          );
          break;

        case 'search_contact':
          result = await _contacts.searchAndFormat(
            action.params['query'] as String? ?? '',
          );
          break;

        case 'set_alarm':
          result = await _alarm.setAlarm(
            hour: (action.params['hour'] as num?)?.toInt() ?? 0,
            minute: (action.params['minute'] as num?)?.toInt() ?? 0,
            label: action.params['label'] as String?,
          );
          break;

        case 'set_timer':
          result = await _alarm.setTimer(
            seconds: (action.params['seconds'] as num?)?.toInt() ?? 60,
            label: action.params['label'] as String?,
          );
          break;

        case 'set_volume':
          result = await _systemControl.setVolume(
            (action.params['level'] as num?)?.toInt() ?? 50,
          );
          break;

        case 'set_brightness':
          result = await _systemControl.setBrightness(
            (action.params['level'] as num?)?.toInt() ?? 50,
          );
          break;

        case 'read_notifications':
          final success = await _screenAutomation.openNotifications();
          result = success ? 'Opened notifications panel. Use read_screen to read them.' : 'Failed to open notifications panel.';
          break;

        case 'run_adb_command':
          result = await _shizuku.runCommand(
            action.params['command'] as String? ?? '',
          );
          break;

        case 'send_email':
          result = await _communication.sendEmail(
            to: action.params['to'] as String? ?? '',
            subject: action.params['subject'] as String?,
            body: action.params['body'] as String?,
          );
          break;

        case 'open_url':
          result = await _appLauncher.openUrl(
            action.params['url'] as String? ?? '',
          );
          break;

        // ─── Screen Automation Actions ────────────────────────

        case 'read_screen':
          result = await _screenAutomation.getScreenDescription();
          break;

        case 'click_element':
          final text = action.params['text'] as String? ?? '';
          final success = await _screenAutomation.clickByText(text);
          result = success ? 'Clicked "$text"' : 'Could not find "$text" to click';
          break;

        case 'type_on_screen':
          final text = action.params['text'] as String? ?? '';
          final hint = action.params['field_hint'] as String?;
          final success = await _screenAutomation.typeText(text, fieldHint: hint);
          result = success ? 'Typed "$text"' : 'Could not type into field';
          break;

        case 'scroll_screen':
          final direction = action.params['direction'] as String? ?? 'down';
          final success = await _screenAutomation.scroll(direction);
          result = success ? 'Scrolled $direction' : 'Could not scroll';
          break;

        case 'press_back':
          final success = await _screenAutomation.pressBack();
          result = success ? 'Pressed back' : 'Could not press back';
          break;

        // ─── Multi-Step Task Execution ────────────────────────

        case 'execute_task':
          final goal = action.params['goal'] as String? ?? action.response;
          if (aiService == null) {
            result = 'AI service not available for task execution.';
            break;
          }
          final executor = TaskExecutor(
            aiService: aiService,
            screenService: _screenAutomation,
            appLauncher: _appLauncher,
            onProgress: onProgress,
            onStepProgress: onStepProgress,
            onConfirmAction: onConfirmAction,
          );
          _currentExecutor = executor;
          try {
            result = await executor.executeTask(goal);
          } finally {
            _currentExecutor = null;
          }
          break;

        case 'mcp_tool_call':
          if (aiService == null || !aiService.mcpEnabled) {
            throw McpToolCallException('MCP is not enabled or AI service is unavailable.');
          }
          final mcpUrl = aiService.mcpUrl;
          final serverName = action.params['server_name'] as String? ?? 'mcp';
          final toolName = action.params['tool_name'] as String? ?? '';
          final arguments = action.params['arguments'] ?? {};
          
          try {
            final url = mcpUrl.endsWith('/') ? '${mcpUrl}tools/execute' : '$mcpUrl/tools/execute';
            final response = await http.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'server_name': serverName,
                'tool_name': toolName,
                'arguments': arguments,
              }),
            ).timeout(const Duration(seconds: 15));
            
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              result = data['result']?.toString() ?? 'Executed $toolName successfully.';
            } else {
              throw McpToolCallException('MCP Error (${response.statusCode}): ${response.body}');
            }
          } catch (e) {
            throw McpToolCallException('Failed to execute MCP tool: $e');
          }
          break;

        default:
          result = action.response;
      }

      return AgentActionResult(
        actionType: action.action,
        success: true,
        details: result,
      );
    } on AppBlockedException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on AppNotFoundException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on AccessibilityServiceException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on AppLaunchException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on UrlOpenException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on ContactNotFoundException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on CallFailedException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on SmsFailedException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on EmailFailedException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on AlarmFailedException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on TimerFailedException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on SystemControlException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on ShizukuNotRunningException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on ShizukuPermissionException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on AdbCommandException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } on McpToolCallException catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    } catch (e) {
      return AgentActionResult(
        actionType: action.action,
        success: false,
        details: 'Error: $e',
      );
    }
  }
}
