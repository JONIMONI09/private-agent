import 'dart:convert';
import 'dart:developer' as developer;
import 'ai_service.dart';
import 'screen_automation_service.dart';
import 'app_launcher_service.dart';
import 'notification_service.dart';
import '../models/plan_step.dart';

class AccessibilityServiceException implements Exception {
  final String message;
  AccessibilityServiceException(this.message);
  @override
  String toString() => 'AccessibilityServiceException: $message';
}

/// Executes multi-step UI automation tasks using LLM-guided screen reading.
/// 
/// Flow: User gives high-level goal → LLM reads screen → decides next action → 
/// executes → reads screen again → repeats until goal is complete.
class TaskExecutor {
  final AiService _aiService;
  final ScreenAutomationService _screenService;
  final AppLauncherService _appLauncher;
  final NotificationService _notificationService = NotificationService();

  /// Callback to report progress and updated plan steps
  final void Function(String message, {int? stepIndex, PlanStepStatus? status})? onStepProgress;

  /// Callback to report progress messages to the UI
  final void Function(String message)? onProgress;

  /// Callback to confirm sensitive actions before execution
  final Future<bool> Function(Map<String, dynamic> action)? onConfirmAction;

  TaskExecutor({
    required AiService aiService,
    required ScreenAutomationService screenService,
    required AppLauncherService appLauncher,
    this.onProgress,
    this.onStepProgress,
    this.onConfirmAction,
  })  : _aiService = aiService,
        _screenService = screenService,
        _appLauncher = appLauncher;

  bool _isCancelled = false;

  /// Cancels the ongoing task execution loop
  void cancel() {
    _isCancelled = true;
  }

  String _getTaskSystemPrompt() {
    final formatStr = _aiService.toolCallingFormat == 'XML'
        ? '''
Use the <thought> block followed by clean XML outside the thought tags:
<thought>
[Your internal reasoning here]
</thought>
<action name="action_name">
  <params>
    <key>value</key>
  </params>
  <reasoning>why you chose this action</reasoning>
  <is_complete>false</is_complete>
</action>'''
        : '''
Use the <thought> block followed by clean JSON outside the thought tags:
<thought>
[Your internal reasoning here]
</thought>
{
  "action": "action_name",
  "params": {"key": "value"},
  "reasoning": "why you chose this action",
  "is_complete": false
}''';

    final actionsStr = _aiService.toolCallingFormat == 'XML'
        ? '''
- click_text: <params><text>exact text to click</text></params> - Click an element by its visible text
- click_at: <params><x>540</x><y>960</y></params> - Click at screen coordinates (use center coordinates from screen dump)
- type_text: <params><text>hello</text><field_hint>optional hint</field_hint></params> - Type into the focused/first edit field
- scroll: <params><direction>down</direction></params> - Scroll down/up on the current view
- press_back: <params></params> - Press the back button
- press_home: <params></params> - Press the home button
- open_app: <params><app_name>WhatsApp</app_name></params> - Open an app
- wait: <params></params> - Wait a moment for content to load
- done: <params></params> - Task is complete'''
        : '''
- click_text: {"text": "exact text to click"} - Click an element by its visible text
- click_at: {"x": 540, "y": 960} - Click at screen coordinates (use center coordinates from screen dump)
- type_text: {"text": "hello", "field_hint": "optional hint"} - Type into the focused/first edit field
- scroll: {"direction": "down"} - Scroll down/up on the current view
- press_back: {} - Press the back button
- press_home: {} - Press the home button
- open_app: {"app_name": "WhatsApp"} - Open an app
- wait: {} - Wait a moment for content to load
- done: {} - Task is complete''';

    return '''
You are a phone automation agent. You are given a TASK and the current SCREEN content.
You must decide what single action to take next to accomplish the task.

$formatStr

Available actions:
$actionsStr

Rules:
- ALWAYS provide the <thought> block first.
- ALWAYS use the text dump to decide your next action.
- If you need to click something, prefer using `click_text`. If the element does not have text, use `click_at` with the coordinates provided in the text dump.
- When typing in a search box, you MUST click it first, wait a step, and THEN type.
- Set is_complete=true ONLY when the task is fully done.
- If stuck after 3 attempts, set is_complete=true and explain in reasoning.
''';
  }

  /// Execute a multi-step task with LLM guidance
  Future<String> executeTask(String userGoal) async {
    _isCancelled = false; // Reset cancellation flag
    final isRunning = await _screenService.isServiceRunning();
    if (!isRunning) {
      throw AccessibilityServiceException('Accessibility service is not enabled. Go to Settings → Accessibility → PrivateAgent Screen Control and enable it.');
    }

    final results = <String>[];
    results.add('Starting task: $userGoal');
    _report('Starting task: $userGoal');

    for (int step = 0; step < _aiService.maxSteps; step++) {
      if (_isCancelled) {
        developer.log('Task execution cancelled by user.', name: 'PrivateAgent');
        results.add('Task stopped by user.');
        _report('Task stopped.');
        await _notificationService.showTaskCompleteNotification('Task Stopped', 'Execution was stopped manually.');
        return results.join('\n');
      }

      // Small delay to let UI settle
      await Future.delayed(const Duration(milliseconds: 500));

      // Fetch foreground app and check blocked list
      final pkg = await _screenService.getCurrentPackage();
      final blocked = await _appLauncher.getBlockedApps();
      if (pkg != null && blocked.contains(pkg)) {
        developer.log('Aborting execution: The active foreground application "$pkg" is blocked.', name: 'PrivateAgent');
        throw AppBlockedException('The active foreground application "$pkg" is blocked by security permissions.');
      }

      // 1. Read the current screen text
      final screenContent = await _screenService.getScreenDescription();
      developer.log('=== SCREEN DUMP (Step ${step + 1}) ===\n$screenContent', name: 'PrivateAgent');

      // Build the complete history of previous actions executed so far to prevent loops.
      final List<String> previousSteps = results.skip(1).toList();
      final historyBuffer = StringBuffer();
      if (previousSteps.isNotEmpty) {
        historyBuffer.writeln('EXECUTION HISTORY OF PRIOR STEPS:');
        for (final prevStep in previousSteps) {
          historyBuffer.writeln('  $prevStep');
        }
      }

      // 2. Ask LLM what to do next
      final prompt = '''TASK: $userGoal

${historyBuffer.toString()}
CURRENT SCREEN TEXT DUMP:
$screenContent

Step ${step + 1}/${_aiService.maxSteps}. Look at the text dump and coordinates. What is the next action?''';

      developer.log('=== AI PROMPT ===\n$prompt', name: 'PrivateAgent');

      String response;
      try {
        response = await _aiService.sendStatelessMessage(_getTaskSystemPrompt(), prompt);
        developer.log('=== RAW AI RESPONSE ===\n$response', name: 'PrivateAgent');
      } catch (e) {
        results.add('AI error: $e');
        _report('Error: $e');
        await _notificationService.showTaskCompleteNotification('Task Error', 'AI encountered an error.');
        return results.join('\n');
      }

      // 3. Parse the action
      String action = 'done';
      Map<String, dynamic> params = {};
      String reasoning = '';
      bool isComplete = false; // Default to false (same as JSON)

      try {
        String dataStr = response.trim();
        
        // Extract thought block if present to remove it from parsing
        final thoughtMatch = RegExp(r'<thought>([\s\S]*?)</thought>').firstMatch(dataStr);
        if (thoughtMatch != null) {
          developer.log('AI Internal Thought: ${thoughtMatch.group(1)!.trim()}', name: 'PrivateAgent');
          dataStr = dataStr.replaceFirst(thoughtMatch.group(0)!, '').trim();
        } else {
          developer.log('Warning: No <thought> block found in AI response.', name: 'PrivateAgent');
        }

        if (_aiService.toolCallingFormat == 'XML') {
          // Anchored tag check to avoid matching random attributes in reasoning
          final nameMatch = RegExp('<action\\s+name\\s*=\\s*["\']([^"\']+)["\']').firstMatch(dataStr);
          if (nameMatch != null) action = nameMatch.group(1)!;
          
          final reasonMatch = RegExp(r'<reasoning>([\s\S]*?)</reasoning>').firstMatch(dataStr);
          if (reasonMatch != null) reasoning = reasonMatch.group(1)!.trim();

          final completeMatch = RegExp(r'<is_complete>([\s\S]*?)</is_complete>').firstMatch(dataStr);
          if (completeMatch != null) {
            isComplete = completeMatch.group(1)!.trim().toLowerCase() == 'true';
          }

          final paramsMatch = RegExp(r'<params>([\s\S]*?)</params>').firstMatch(dataStr);
          if (paramsMatch != null) {
            final paramEntries = RegExp(r'<([a-zA-Z0-9_\-]+)(?:\s+[^>]*)?>([\s\S]*?)</\1>').allMatches(paramsMatch.group(1)!);
            for (final m in paramEntries) {
              final key = m.group(1)!;
              final val = m.group(2)!.trim(); // Trim spaces/newlines to prevent invalid input payloads
              if (key == 'x' || key == 'y') {
                params[key] = double.tryParse(val) ?? 0.0;
              } else if (val.toLowerCase() == 'true' || val.toLowerCase() == 'false') {
                params[key] = val.toLowerCase() == 'true';
              } else {
                params[key] = val;
              }
            }
          }
        } else {
          // JSON parsing
          int startIdx = dataStr.indexOf('{');
          int endIdx = dataStr.lastIndexOf('}');
          if (startIdx != -1 && endIdx != -1 && startIdx < endIdx) {
            final jsonStr = dataStr.substring(startIdx, endIdx + 1);
            final actionJson = jsonDecode(jsonStr) as Map<String, dynamic>;
            action = actionJson['action'] as String? ?? 'done';
            params = actionJson['params'] as Map<String, dynamic>? ?? {};
            reasoning = actionJson['reasoning'] as String? ?? '';
            isComplete = actionJson['is_complete'] == true;
          }
        }
      } catch (_) {
        results.add('Step ${step + 1}: Invalid action format response');
        _report('Error: AI did not return a valid action code.');
        await _notificationService.showTaskCompleteNotification('Task Error', 'AI formatting error.');
        return results.join('\n');
      }

      developer.log('=== PARSED ACTION ===\nAction: $action\nParams: $params\nReasoning: $reasoning\nIs Complete: $isComplete', name: 'PrivateAgent');

      _report('Step ${step + 1}: $reasoning');
      onStepProgress?.call(reasoning, stepIndex: step, status: PlanStepStatus.active);

      // 4. Execute the action
      if (!_aiService.yoloMode && onConfirmAction != null) {
        final approved = await onConfirmAction!({
          'action': action,
          'params': params,
          'reasoning': reasoning,
        });
        if (!approved) {
          results.add('Step ${step + 1}: Execution canceled by user.');
          _report('Task canceled by user.');
          onStepProgress?.call('Canceled', stepIndex: step, status: PlanStepStatus.failed);
          return results.join('\n');
        }
      }

      bool success = false;
      String actionResult = '';

      try {
        switch (action) {
          case 'click_text':
            final text = params['text'] as String? ?? '';
            success = await _screenService.clickByText(text);
            actionResult = success ? 'Clicked "$text"' : 'Could not find "$text" to click';
            break;

          case 'click_at':
            final x = (params['x'] as num?)?.toDouble() ?? 0;
            final y = (params['y'] as num?)?.toDouble() ?? 0;
            success = await _screenService.clickAt(x, y);
            actionResult = success ? 'Clicked at ($x, $y)' : 'Click failed';
            break;

          case 'type_text':
            final text = params['text'] as String? ?? '';
            final hint = params['field_hint'] as String?;
            success = await _screenService.typeText(text, fieldHint: hint);
            actionResult = success ? 'Typed "$text"' : 'Could not type text';
            break;

          case 'scroll':
            final direction = params['direction'] as String? ?? 'down';
            success = await _screenService.scroll(direction);
            actionResult = success ? 'Scrolled $direction' : 'Scroll failed';
            break;

          case 'press_back':
            success = await _screenService.pressBack();
            actionResult = 'Pressed back';
            break;

          case 'press_home':
            success = await _screenService.pressHome();
            actionResult = 'Pressed home';
            break;

          case 'open_app':
            final appName = params['app_name'] as String? ?? '';
            actionResult = await _appLauncher.openApp(appName);
            success = actionResult.startsWith('Opened');
            break;

          case 'wait':
            await Future.delayed(const Duration(seconds: 1));
            actionResult = 'Waited';
            success = true;
            break;

          case 'done':
            results.add('Task complete: $reasoning');
            _report('Task complete: $reasoning');
            onStepProgress?.call(reasoning, stepIndex: step, status: PlanStepStatus.done);
            await _notificationService.showTaskCompleteNotification('Task Completed', reasoning.isEmpty ? 'Agent finished its goal.' : reasoning);
            return results.join('\n');

          default:
            actionResult = 'Unknown action: $action';
        }
      } on AppBlockedException {
        rethrow;
      } catch (e) {
        success = false;
        actionResult = 'Error: $e';
      }

      developer.log('=== NATIVE EXECUTION RESULT ===\n$actionResult', name: 'PrivateAgent');

      results.add('Step ${step + 1}: $actionResult ($reasoning)');
      onStepProgress?.call(actionResult, stepIndex: step, status: success ? PlanStepStatus.done : PlanStepStatus.failed);

      if (isComplete) {
        results.add('Task complete.');
        _report('Task complete.');
        onStepProgress?.call('Goal reached', stepIndex: step, status: PlanStepStatus.done);
        await _notificationService.showTaskCompleteNotification('Task Completed', 'Agent finished its goal.');
        return results.join('\n');
      }
    }

    results.add('Reached maximum steps (${_aiService.maxSteps}). Task may be incomplete.');
    _report('Reached maximum steps.');
    await _notificationService.showTaskCompleteNotification('Task Stopped', 'Reached maximum steps (${_aiService.maxSteps}).');
    return results.join('\n');
  }

  void _report(String message) {
    onProgress?.call(message);
  }
}
