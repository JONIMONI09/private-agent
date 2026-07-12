# Implementation Plan — Milestone 2 Core Security & App Management

## Objective
Implement custom exceptions, app launching security restrictions, remote execution restrictions in Approve Mode, foreground app checks during execution, actions registry updates, regex-based JSON parsing in AI service, styling refactoring to use semantic theme properties, and security unit tests.

## Steps

### Step 1: Define Custom Exceptions
- Define `AppBlockedException` and `AppNotFoundException` in `lib/services/app_launcher_service.dart`.
- Throw these exceptions in `openApp` instead of returning "Access Denied" or "Could not find app" strings.
- Replace any console prints in `app_launcher_service.dart` with `developer.log`.

### Step 2: Implement Whitelist & Approve Mode Checks in Telegram Service
- Load whitelisted chat IDs from SharedPreferences (`telegram_chat_id_whitelist`).
- Split by `,` to match the incoming `chatId`.
- If the whitelist is not empty and the sender is not whitelisted, log warning using `developer.log` and reply with `❌ Unauthorized Chat ID: $chatId`.
- In Approve Mode (`!_aiService.yoloMode`), reject remote command execution and return a descriptive message to Telegram.
- Replace standard `print` statements in `telegram_service.dart` with `developer.log`.

### Step 3: Integrate Blocked App & Formatting Fixes in Task Executor
- At the start of the step loop inside `executeTask`, fetch current foreground app package using `_screenService.getCurrentPackage()`.
- Fetch blocked package list from `_appLauncher.getBlockedApps()`.
- Throw `AppBlockedException` if active app is blocked.
- Fix dead null-aware check on `reasoning` on line 220.

### Step 4: Add Exception Catching & Blocked App Checks to Action Handler
- Catch `AppBlockedException` and `AppNotFoundException` inside `execute`.
- Before executing any screen automation gesture (`read_screen`, `click_element`, `type_on_screen`, `scroll_screen`, `press_back`), check if the current foreground app package is blocked and throw `AppBlockedException`.

### Step 5: Update Agent Action Registry
- Register `execute_task`, `click_element`, `type_on_screen`, `scroll_screen`, and `press_back` in `AgentAction.availableActions`.

### Step 6: Robust JSON Parsing & Logging in AI Service
- Update `parseAction` to use the same `RegExp(r'\{[\s\S]*\}')` parser as `TaskExecutor`.
- Replace any standard `print` statements in `ai_service.dart` with `developer.log`.

### Step 7: Refactor Screen Hardcoded Colors
- In `lib/screens/home_screen.dart` and `lib/screens/settings_screen.dart`, replace `Colors.green`, `Colors.orange`, `Colors.grey`, `Colors.red`, and `Colors.green[700]` with semantic theme properties like `Theme.of(context).colorScheme.primary`, `Theme.of(context).colorScheme.outline`, and `Theme.of(context).colorScheme.error`.

### Step 8: Add Security Unit Tests
- Create `test/security_test.dart` to verify AI Service YOLO toggle persistence, and AppLauncherService block list & custom exceptions.

### Step 9: Verify
- Run `dart analyze` to ensure no lint/compiler errors.
- Run `dart test` to verify unit tests pass.
