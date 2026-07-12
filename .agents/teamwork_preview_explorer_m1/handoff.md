# Handoff Report — Exploration & System Design (R1-R4)

This report details the architectural exploration and proposed designs for implementing R1, R2, R3, and R4 within the PrivateAgent Android AI Agent application.

---

## 1. Observation
We have read and analyzed the following codebase files:
- `lib/screens/home_screen.dart` (Line 1-402): Manages chat interface, voice actions, and execution callbacks.
- `lib/screens/settings_screen.dart` (Line 1-608): Contains configuration fields for AI settings, Telegram service, system permissions, Accessibility Service, and Shizuku.
- `lib/services/task_executor.dart` (Line 1-232): Handles the multi-step execution loop guided by LLM screen dumps.
- `lib/services/action_handler.dart` (Line 1-174): Dispatches actions to appropriate services and triggers the `TaskExecutor`.
- `lib/services/ai_service.dart` (Line 1-250): Manages API settings, prompt construction, and conversation history.
- `lib/services/app_launcher_service.dart` (Line 1-68): Retrieves and launches installed applications.
- `lib/models/agent_action.dart` (Line 1-34): Defines the action schemas and the list of available actions.
- `lib/models/chat_message.dart` (Line 1-28): Model representing chat messages and action results.
- `lib/widgets/message_bubble.dart` (Line 1-118): Renders individual chat items in the interface.

---

## 2. Logic Chain
The proposed implementation designs follow directly from observations of the codebase:
1. **Approve/YOLO Mode**:
   - *Observation*: `AiService` loads key settings from `SharedPreferences` (lines 57-64). `TaskExecutor` executes actions step-by-step in a loop (lines 75-220).
   - *Logic*: To persist YOLO/Approve state, we should store a boolean flag in `SharedPreferences` managed via `AiService` (similar to `disableMaxSteps`). To block the loop, `TaskExecutor` can accept a callback `Future<bool> Function(AgentAction action)? onConfirmAction`. When Approve Mode is enabled, the loop awaits this callback. If it resolves to `false`, execution is aborted. In `HomeScreen`, the callback is implemented using a Flutter Dialog or a `BottomSheet` combined with a `Completer<bool>` to suspend execution until user action.
2. **App Permission Management**:
   - *Observation*: `AppLauncherService` retrieves installed apps using `InstalledApps.getInstalledApps()` (line 10) and handles searches/opens (lines 20-52).
   - *Logic*: We can store a whitelist/blacklist of package names in `SharedPreferences`. `AppLauncherService` should filter apps matching these blocked package names in `searchApps` and block access in `openApp`, preventing the AI from knowing about or interacting with restricted apps.
3. **Tabbed Settings UI**:
   - *Observation*: `SettingsScreen` (line 186) currently stacks all settings into a single long `ListView`.
   - *Logic*: To partition this logically, we will wrap the Scaffold in a `DefaultTabController(length: 4)` and use a `TabBarView` to render four separate tab views: 
     - **Tab 1: AI Config** (API key, models, max steps, tool-calling format).
     - **Tab 2: Security & App Permissions** (YOLO/Approve mode, checklist of installed apps).
     - **Tab 3: System Permissions** (Runtime permissions, Accessibility Service, Shizuku).
     - **Tab 4: Telegram & About** (Remote control settings, links).
4. **Token Counter & Context Compressor**:
   - *Observation*: `AiService` maintains history via `_conversationHistory` (line 15) and prunes it with a sliding window of the last 20 messages (line 129). Large screen dumps quickly bloat context size.
   - *Logic*: A character-based token estimation heuristic (`chars ~/ 4`) is lightweight and appropriate for the client. We will add a small status bar containing a token counter and a "Compress" button right above the chat input bar in `HomeScreen`. The auto-compressor will trigger when estimated tokens exceed a threshold (e.g., 4000). It will call `AiService` to request a summary of older messages, delete them, and prepend the summary as a system message in the history.
5. **Plan UI & Animations**:
   - *Observation*: There is no `/plan` command currently. `TaskExecutor` posts raw text steps to the chat UI via `onProgress` callback (line 228), which appends cluttering message bubbles in `HomeScreen`.
   - *Logic*: We will intercept `/plan` in `HomeScreen` and request a structured JSON plan from the AI. We will add a `planSteps` field to `ChatMessage` to represent steps (with statuses: `pending`, `active`, `completed`, `failed`). `TaskExecutor` will report progress by updating step statuses. `MessageBubble` will check for the presence of `planSteps` and render a custom vertical stepper widget with animated transitions, green arrows/checkmarks, and expandable detailed step accordions.

---

## 3. Caveats
- Character-based token estimation (`chars ~/ 4`) is an approximation and might vary slightly from the actual tokenizer of DeepSeek or other models. However, it is fully sufficient for triggering history compression.
- App permission management relies on packages returned by the `installed_apps` package. System packages that are hidden or not exposed by this package might not show in the settings menu, but the primary target is user/installed apps.

---

## 4. Conclusion
Below is the precise architectural design for R1, R2, R3, R4 implementation:

### R1. Core Security & App Management
- **YOLO/Approve Mode**:
  - Add `bool get yoloMode` and `Future<void> setYoloMode(bool value)` to `AiService`.
  - Update `ActionHandler.execute` and `TaskExecutor.executeTask` to check `yoloMode`. If false, trigger `onConfirmAction` callback.
  - Implement `onConfirmAction` in `HomeScreen` by showing a modal approval sheet and returning a `Future<bool>` using a `Completer`.
- **App Permissions**:
  - Add blocked package names storage (`blocked_apps_packages` list of strings) to `AppLauncherService` settings.
  - In `AppLauncherService.searchApps`, filter out blocked apps:
    ```dart
    final blocked = await getBlockedApps();
    return apps.where((app) => !blocked.contains(app.packageName) && ...).toList();
    ```
  - In `AppLauncherService.openApp`, block direct access:
    ```dart
    if (blocked.contains(target.packageName)) return 'Access denied by App Permissions.';
    ```

### R2. Settings Revamp (Tabbed UI)
- Refactor `SettingsScreen` to use a `DefaultTabController` with 4 tabs:
  1. **AI Config Tab**: API Key, Base URL, Fetch/select Model, Max Steps slider, Tool format (JSON/XML).
  2. **Security Tab**: YOLO/Approve toggle, Checklist of installed apps for permission management (retrieved from `AppLauncherService`).
  3. **System Tab**: Runtime permissions (Mic, Contacts, etc.), Accessibility Service Status, Shizuku Status.
  4. **Telegram & About Tab**: Bot settings, about links.

### R3. Token Management & History Compressor
- **Token Estimation**: Heuristic formula inside `AiService`:
  ```dart
  int estimateTokens(String text) => (text.length / 4).round();
  ```
- **UI Integration**:
  - A small container row in `HomeScreen` right above the chat input field showing:
    - Left: `Context: ~X tokens`
    - Right: `Compress Context` text button.
- **Auto-Compress History**:
  - Set threshold `maxTokens = 4000`.
  - When threshold is exceeded, extract history from index 0 to `length - 5`.
  - Send compression prompt to AI: `"Summarize the key discussion points and tasks from the following history under 200 words: [History]"`
  - Replace the compressed messages with a single summary message: `{"role": "system", "content": "Summary of previous conversation: $summary"}`.

### R4. Plan UI & Animations
- **Slash Command**: Intercept commands starting with `/plan` in `HomeScreen._sendMessage`.
- **Step Model**: Add `List<PlanStep>? planSteps` inside `ChatMessage`.
  ```dart
  class PlanStep {
    final String description;
    PlanStepStatus status; // pending, active, completed, failed
    String? details;
  }
  ```
- **TaskExecutor Reporting**:
  - Instead of string progress messages, report updates to step index: `onStepUpdate?.call(stepIndex, status, details)`.
- **Stepper UI Widget**:
  - A vertical column of steps. Each step has a leading icon matching status (e.g., grey circle, spinning progress indicator, green checkmark).
  - Expandable detail container using `AnimatedCrossFade` to show action reasoning or ADB output when a step is tapped or active.

---

## 5. Verification Method
1. **Settings Persistence**: Verify that changing YOLO mode and app permissions writes to and reads from `SharedPreferences` correctly.
2. **Execution Block**: In Approve Mode, trigger a multi-step command and verify the prompt blocks execution until approved/rejected.
3. **App Filtering**: Block "YouTube" in App Permissions. Send "Open YouTube" to the agent and verify it fails to locate or open the app.
4. **Token Compression**: Set the compression threshold to a low value (e.g. 500 characters) and verify the auto-compressor triggers, calls the summary prompt, updates `_conversationHistory`, and resumes execution.
5. **Plan UI**: Trigger a `/plan` command, verify the vertical animated step UI compiles, shows correct stepper state transitions, and displays expandable step details.
6. **Code Quality**: Verify the app complies with Dart formatting and runs `flutter analyze` without errors.
