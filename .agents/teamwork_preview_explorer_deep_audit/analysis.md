# PrivateAgent Deep System Audit Report

**Date:** July 12, 2026  
**Auditor:** Teamwork Preview Explorer  
**Status:** Completed  

---

## Executive Summary
This report presents the findings of a deep and exhaustive system audit of the `PrivateAgent` Android assistant codebase. The audit was conducted on the entire Dart codebase (`lib/`), native Kotlin files, configuration files (`AndroidManifest.xml`), and the test suite (`test/`).

Multiple vulnerabilities were identified, including critical native memory leaks in the accessibility service, state caching errors, potential context-lookup crashes, whitelist security bypasses, and minor project rule violations.

---

## 1. Bugs & Crashes

### 1.1 Critical Memory Leaks of `AccessibilityNodeInfo` (Native Kotlin)
* **File:** `android/app/src/main/kotlin/com/orailnoor/privateagent/AgentAccessibilityService.kt`
* **Methods:** `findAndClickNode(...)` (Lines 145-174) and `findEditableNode(...)` (Lines 202-228)
* **Description:** 
  In Android, the accessibility framework requires manual recycling of `AccessibilityNodeInfo` references obtained via `getChild(i)` or `parent`. 
  - In `findAndClickNode`, when walking up the tree to find a clickable element via `clickTarget = clickTarget.parent`, a new node reference is returned. The code overwrites the variable without recycling the intermediate nodes, and never recycles the final parent node.
  - In `findEditableNode`, if a matching node is found deep in the tree, the intermediate child nodes are returned without being recycled. Only the mismatched sibling branches are recycled (`child.recycle()`).
* **Impact:** 
  Native memory leaks. Leaking accessibility nodes eventually exhausts the system binder limit (typically 500-1000 active references), causing the native accessibility service or the host app to freeze or crash, especially on pages with large view hierarchies.
* **Suggested Fix:**
  Ensure that every `parent` lookup and every successfully found node along the recursive path is registered for recycling or properly recycled once its work is done.

### 1.2 State Caching Bug (Dart Service)
* **File:** `lib/services/app_launcher_service.dart`
* **Method:** `getInstalledApps(...)` (Lines 51-65)
* **Description:**
  The method uses a cache variable `_cachedApps`:
  ```dart
  try {
    _cachedApps ??= await InstalledApps.getInstalledApps();
  } catch (e) {
    developer.log('Error fetching installed apps: $e', name: 'AppLauncherService', error: e);
    _cachedApps = [];
  }
  ```
  If `InstalledApps.getInstalledApps()` throws an exception on its first run (e.g., due to background permission delay or system service unavailability), the exception is caught, and `_cachedApps` is set to `[]` (an empty list). Because of the `??=` operator, subsequent calls will see that `_cachedApps` is not `null` (since it is `[]`), and will never attempt to reload the apps from the OS.
* **Impact:** 
  The app launcher service gets permanently stuck in an empty state. Any subsequent app open or query will fail with an `AppNotFoundException`, even if permissions are corrected, until the app is killed and restarted.
* **Suggested Fix:**
  Do not assign `_cachedApps = []` in the catch block, or clear the cache variable to `null` on errors so that the next invocation attempts a reload.

### 1.3 Context Lookup across Async Boundary (Dart UI)
* **File:** `lib/screens/home_screen.dart`
* **Method:** `_showActionApprovalDialog(...)` (Lines 77-138)
* **Description:**
  This method is passed as a callback `onConfirmAction` to the `ActionHandler.execute(...)` method. It calls `showDialog` directly using the widget's `context`. If the AI completes execution of a background task or a remote Telegram command after the user has navigated away from the `HomeScreen` (or if the home screen is disposed), the `context` is no longer active in the widget tree.
* **Impact:** 
  A crash: `Assertion failed: ... "Looking up a deactivated widget's ancestor is unsafe."`
* **Suggested Fix:**
  Add a mounted check inside the method before calling `showDialog`:
  ```dart
  if (!mounted) return false;
  ```

---

## 2. Logic Errors

### 2.1 Unimplemented `read_notifications` Action
* **File:** `lib/models/agent_action.dart` and `lib/services/action_handler.dart`
* **Description:**
  The action `read_notifications` is registered in `availableActions` (Line 36 of `agent_action.dart`) and exposed to the LLM. However, `ActionHandler.execute(...)` does not have a switch-case block for `read_notifications`. 
* **Impact:** 
  If the LLM attempts to read notifications, the action falls through to the `default` case, which simply returns the LLM's raw response without performing any device interaction.
* **Suggested Fix:**
  Implement the notification reading logic in `ScreenAutomationService` or a dedicated service, and add the corresponding case block in `ActionHandler`.

### 2.2 Silenced Errors and Ambiguity in `ContactsService`
* **File:** `lib/services/contacts_service.dart`
* **Methods:** `searchContacts(...)` (Lines 5-19) and `getPhoneNumber(...)` (Lines 21-30)
* **Description:**
  - If contact permission is denied, `searchContacts` silently catches it and returns `[]`. The user is shown a generic "No contacts found matching..." message. The app does not explain that it lacks permission to read contacts.
  - In `getPhoneNumber`, if there are multiple matches (e.g. searching for "John" returns "John Doe" and "John Smith"), it returns `matches.first` blindly.
* **Impact:** 
  - Poor user experience: Users are misled into thinking a contact does not exist when the actual problem is a lack of system permissions.
  - Logic bug: The agent might call or text the wrong person if a contact name query matches multiple people.
* **Suggested Fix:**
  - Throw a `PermissionDeniedException` (or similar typed exception) in `searchContacts` if permission is denied, and handle it gracefully in the UI.
  - Return a list of matches and prompt the user for clarification if multiple contacts are found.

### 2.3 Unawaited Futures in `TaskExecutor`
* **File:** `lib/services/task_executor.dart`
* **Description:**
  The `executeTask` method makes multiple calls to `_notificationService.showTaskCompleteNotification(...)` (e.g., Lines 154, 218, 299, 321, 328) without using `await` or wrapping it in `unawaited`. The method internally performs an asynchronous initialization of the local notifications plugin (`await init()`).
* **Impact:** 
  If the task executor thread completes and terminates shortly after triggering the notification, the notification might be aborted or fail to show due to unawaited initialization.
* **Suggested Fix:**
  Await the notification call: `await _notificationService.showTaskCompleteNotification(...)`.

### 2.4 Race Condition in `HomeScreen._initServices`
* **File:** `lib/screens/home_screen.dart`
* **Method:** `_initServices(...)` (Lines 47-75)
* **Description:**
  ```dart
  if (mounted) {
    final accessibilityEnabled =
        await _actionHandler.screenAutomation.isServiceRunning();

    setState(() { ... });
  }
  ```
  The code checks `if (mounted)` but then awaits `isServiceRunning()`. During this asynchronous wait, the widget could be popped/disposed. When it resumes, `setState` is called without checking `mounted` again.
* **Impact:**
  Uncaught framework exceptions when trying to call `setState` on an unmounted element.
* **Suggested Fix:**
  Add a second check after the await:
  ```dart
  final accessibilityEnabled = await _actionHandler.screenAutomation.isServiceRunning();
  if (mounted) {
    setState(() { ... });
  }
  ```

---

## 3. Security Risks

### 3.1 Telegram Whitelist Bypass (Major Security Gap)
* **File:** `lib/services/telegram_service.dart`
* **Method:** `_handleIncomingMessage(...)` (Lines 101-114)
* **Description:**
  If the `telegramWhitelist` preference is empty, the code prints a warning log but *allows all incoming messages* to proceed to LLM parsing and execution:
  ```dart
  } else {
    developer.log('Warning: Telegram Chat ID Whitelist is empty. Allowing all incoming messages.', name: 'TelegramService');
  }
  ```
  This violates the rule in `.agents/AGENTS.md`: *"Telegram Bot: Always validate the Chat ID against a whitelist."*
* **Impact:** 
  If a user configures a Telegram bot token but leaves the whitelist empty, anyone on Telegram can message the bot and execute shell commands or screen interactions on the user's phone.
* **Suggested Fix:**
  If the whitelist is empty, treat all incoming requests as unauthorized and block execution.

### 3.2 Unsanitized ADB Command Execution (ADB Injection)
* **File:** `lib/services/shizuku_service.dart`
* **Method:** `runCommand(...)` (Lines 59-76)
* **Description:**
  The service takes a raw command string from the LLM parameters and executes it via Shizuku (`await _shizuku.runCommand(command)`). There is no whitelisting or sanitization of the input.
* **Impact:** 
  Although YOLO mode requires verification by default, if a user enables YOLO mode, a prompt injection attack on the LLM could execute arbitrary shell commands (e.g., deleting user files, installing unauthorized APKs, or resetting settings).
* **Suggested Fix:**
  Maintain a strict whitelist of allowed command templates (e.g., `am force-stop`, `pm clear`, `svc wifi`) and reject any commands containing shell metacharacters (e.g., `;`, `&`, `|`, `` ` ``).

---

## 4. UI/Layout Analysis
* **Result:** No layout traps or rendering bugs found.
* **Details:**
  - Layouts in `home_screen.dart`, `settings_screen.dart`, and `app_permissions_screen.dart` are correctly designed.
  - Lists (`ListView.builder`) inside `Column` layouts are properly wrapped in `Expanded` or bounded structures, preventing standard Flutter layout crashes (unbounded vertical constraints).
  - Component styling respects `Theme.of(context)` values (e.g., `Theme.of(context).colorScheme.primary`). No hardcoded colors are defined.

---

## 5. Compliance with Project Rules (`.agents/AGENTS.md`)

| Rule | Status | Findings |
|---|---|---|
| All code comments in English | **Compliant** | All comments in the code are in English. |
| German communication (messages), English files | **Compliant** | Auditing documentation is in English; coordination messages are in German. |
| Never use hardcoded colors | **Compliant** | Colors are resolved from `Theme.of(context)`. |
| Handle errors with Exceptions | **Non-Compliant** | `ContactsService.searchContacts` returns `[]` on denial. `SystemControlService.getVolume`/`getBrightness` return `-1` on errors. `VoiceService` silently fails. |
| Set timeouts on all HTTP requests | **Non-Compliant** | `TelegramService` has no client-side timeouts on HTTP requests. |
| Use proper Logger instead of print() | **Compliant** | No `print()` statements found. All logs use `developer.log`. |
| Verify `mounted` state before `setState` | **Non-Compliant** | HomeScreen has a race condition in `_initServices` where it calls `setState` after an async wait. |
| Telegram Bot whitelist validation | **Non-Compliant** | Whitelist validation is bypassed if the whitelist configuration string is empty. |
| Background tasks use `sendStatelessMessage` | **Compliant** | `TaskExecutor` uses `sendStatelessMessage`. |
| Natively support JSON and XML formats | **Compliant** | Both formats are supported in prompts and parsers. |
