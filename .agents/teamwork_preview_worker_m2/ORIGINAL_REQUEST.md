## 2026-07-04T20:09:31Z

Your identity is: teamwork_preview_worker
Your working directory is: d:\private-agent\.agents\teamwork_preview_worker_m2
Your mission is to implement R1: Core Security & App Management.

MANDATORY INTEGRITY WARNING — include this verbatim:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Please implement the following changes in the codebase:

1. In `lib/services/ai_service.dart`:
   - Add a private field `bool _yoloMode = false;`.
   - Add getter `bool get yoloMode => _yoloMode;`.
   - Add a method `Future<void> saveYoloMode(bool value)` that updates `_yoloMode` and saves it to SharedPreferences under the key 'api_yolo_mode'.
   - In the `init()` method, load the value of `api_yolo_mode` from SharedPreferences, defaulting to `false`.

2. In `lib/services/app_launcher_service.dart`:
   - Add methods to retrieve and save the list of blocked app package names from SharedPreferences. Let's use the key 'blocked_apps_packages' (as List of Strings).
     - `Future<List<String>> getBlockedApps()`
     - `Future<void> saveBlockedApps(List<String> packages)`
   - Refactor `getInstalledApps({bool includeBlocked = false})`:
     - If `includeBlocked` is false, filter out any app whose `packageName` is in the blocked list.
     - Else, return all installed apps.
   - Refactor `searchApps` and `openApp` to check for blocked status. If blocked, `openApp` should return `Access Denied: The app "[app_name]" is blocked by security permissions.` and NOT execute the app launch.

3. In `lib/services/task_executor.dart`:
   - Add a callback field to the class: `final Future<bool> Function(Map<String, dynamic> action)? onConfirmAction;`.
   - Update the constructor to accept `this.onConfirmAction`.
   - In `executeTask(String userGoal)`:
     - Inside the step loop, before executing any native action (like `click_text`, `type_text`, `open_app`, etc. in the switch statement), check if `!_aiService.yoloMode` (Approve Mode is active).
     - If active and `onConfirmAction != null`, invoke `onConfirmAction` with the parsed action JSON:
       ```dart
       final approved = await onConfirmAction!({
         'action': action,
         'params': params,
         'reasoning': reasoning,
       });
       if (!approved) {
         results.add('Step ${step + 1}: Execution canceled by user.');
         _report('Task canceled by user.');
         return results.join('\n');
       }
       ```

4. In `lib/services/action_handler.dart`:
   - Update `execute` method signature to accept `Future<bool> Function(Map<String, dynamic> action)? onConfirmAction`.
   - Pass `onConfirmAction` to the `TaskExecutor` constructor in `case 'execute_task'`.
   - In `execute`, if `aiService != null && !aiService.yoloMode && onConfirmAction != null && action.action != 'general_query' && action.action != 'execute_task'`:
     - Invoke `onConfirmAction` with the action details before running the switch case.
     - If not approved, return `AgentActionResult(actionType: action.action, success: false, details: 'Execution canceled by user.')`.

5. In `lib/screens/home_screen.dart`:
   - Implement `Future<bool> _showActionApprovalDialog(Map<String, dynamic> action)` in the state:
     - Shows a Flutter dialog displaying the action name, parameters, and reasoning.
     - Has "Approve" (returns true) and "Cancel" (returns false) buttons.
   - In `_sendMessage`, pass `onConfirmAction: _showActionApprovalDialog` to `_actionHandler.execute`.

Verify all changes using `flutter analyze` and document the output in your handoff report.
Once complete, write your handoff report to `handoff.md` (strictly in English) in your working directory and reply to me in German using the standard messaging format.
