## 2026-07-05T12:26:36Z
You are a Worker agent.
Your working directory is d:\private-agent\.agents\worker_task_executor\

Task: Optimize task executor parsing, align prompts, standardize error handling with exceptions across all core services, update `action_handler.dart` to translate these exceptions, and update/verify tests.

Requirements:
1. Prompt & Parsing in `task_executor.dart`:
   - Align `_getTaskSystemPrompt()` to instruct the model to use the `<thought>` block followed by clean JSON/XML outside the thought tags, removing any redundant instructions.
   - Refactor parsing inside `executeTask` loop: first extract and strip the `<thought>...</thought>` block.
   - For XML: parse action name flexibly (allowing quotes/spaces) and parameters robustly (allowing '<', '>', attributes in tags) just like `ai_service.dart`.
   - For JSON: parse using clean jsonDecode on the remaining JSON block.
2. Standardize Error Handling with Exceptions:
   - Refactor the following services to THROW typed exceptions instead of returning descriptive error strings on failure:
     - `lib/services/task_executor.dart` (throw `AccessibilityServiceException` if accessibility service is disabled).
     - `lib/services/app_launcher_service.dart` (throw `AppLaunchException` or `UrlOpenException` on failure instead of error strings).
     - `lib/services/communication_service.dart` (define and throw `ContactNotFoundException`, `CallFailedException`, `SmsFailedException`, `EmailFailedException` instead of returning error strings).
     - `lib/services/alarm_service.dart` (define and throw `AlarmFailedException` / `TimerFailedException` instead of returning error strings).
     - `lib/services/system_control_service.dart` (define and throw `SystemControlException` instead of returning error strings).
     - `lib/services/shizuku_service.dart` (define and throw `ShizukuNotRunningException`, `ShizukuPermissionException`, `AdbCommandException` instead of returning error strings).
3. Update `action_handler.dart`:
   - Catch all of these custom exceptions in the `try-catch` blocks or individual `on` clauses.
   - Map them to `AgentActionResult(success: false, details: 'Error: ...')`.
   - Ensure `mcp_tool_call` handles failures by throwing exceptions or mapping HTTP errors properly so it returns `success: false` on failure.
4. Unit Tests in `test/security_test.dart`:
   - Update any tests that check error responses to expect the correct exceptions or test how `ActionHandler` maps exceptions to failed results.
   - Add/verify test cases for:
     - `TaskExecutor` throwing `AccessibilityServiceException` when accessibility service is disabled.
     - `ActionHandler` mapping these exceptions (e.g. `AppBlockedException`, `ShizukuNotRunningException`) to `success: false`.
5. Run tests and make sure all compile and pass. Run `flutter test test/security_test.dart`.

CRITICAL INSTRUCTIONS:
- FLAT HIERARCHY: You are FORBIDDEN from spawning any further subagents. Do not call invoke_subagent.
- MANDATORY INTEGRITY WARNING: DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
- Write your progress in `d:\private-agent\.agents\worker_task_executor\progress.md` and handoff report in `d:\private-agent\.agents\worker_task_executor\handoff.md`.
- Report your results back via message to parent conversation ID: 3889460b-ee6b-42d7-86ff-4e0057bac98a.
