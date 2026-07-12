## 2026-07-04T20:29:50Z
Your identity is: teamwork_preview_worker
Your working directory is: d:\private-agent\.agents\teamwork_preview_worker_m3
Your mission is to implement R2: Settings Revamp (Tabbed UI) and advanced settings options.

MANDATORY INTEGRITY WARNING — include this verbatim:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Please implement the following changes in the codebase:

1. **Register Missing Actions**:
   - In `lib/models/agent_action.dart`, add `'set_timer'`, `'send_email'`, and `'open_url'` to the `availableActions` static array list so it matches the actions supported by `ActionHandler`.

2. **Advanced Settings Fields in `AiService` (`lib/services/ai_service.dart`)**:
   - Add getters, setters, and loading in `init()` from SharedPreferences for:
     - `toolCallingFormat` (String, default: 'JSON'). Stored as 'api_tool_calling_format'.
     - `extremeThinkingDepth` (int, default: 0). Stored as 'api_thinking_depth'.
     - `autoCompressHistory` (bool, default: true). Stored as 'api_auto_compress_history'.
     - `mcpEnabled` (bool, default: false). Stored as 'api_mcp_enabled'.
     - `mcpUrl` (String, default: 'http://10.0.2.2:3000'). Stored as 'api_mcp_url'.
     - `telegramWhitelist` (String, default: ''). Stored as 'telegram_chat_id_whitelist'. (Ensure it is loaded and editable here, and checked in `TelegramService`.)

3. **Settings Screen Refactoring (`lib/screens/settings_screen.dart`)**:
   - Wrap the Scaffold in a `DefaultTabController(length: 4)`.
   - Update `AppBar` to contain a `bottom: const TabBar(...)` with 4 tabs:
     - AI Config (icon: `Icons.psychology`)
     - Security (icon: `Icons.security`)
     - System (icon: `Icons.settings_phone`)
     - Telegram & About (icon: `Icons.chat`)
   - Replace the single `ListView` body with a `TabBarView(children: [...])` containing:
     - **Tab 1: AI Configuration (ListView)**:
       - API Key text field (obscurable).
       - API Base URL text field + chips for quick fill (DeepSeek, OpenRouter, Groq, Local).
       - Model name text field + "Fetch" button.
       - Max Steps slider & "Disable Maximum Steps" toggle.
       - Tool Calling Format toggle (JSON/XML, e.g. using `SegmentedButton` or `DropdownButton`).
       - Extreme Thinking Mode depth slider (0 to 100). If depth > 0, show a prominent warning text: `⚠️ Extreme Thinking depth can increase token usage and response latency.` using the theme's warning/error color.
       - Auto-Compress History switch.
       - MCP Connector (Beta): Switch to enable, and text field for Server URL.
     - **Tab 2: Security & App Permissions (ListView)**:
       - YOLO Mode (Autonomous) vs Approve Mode (Manual) toggle.
       - Whitelisted Telegram Chat IDs text field (label: "Whitelisted Chat IDs (comma-separated)").
       - Blocked Apps list:
         - Display a list of all installed apps on the device (retrieved asynchronously using `AppLauncherService().getInstalledApps(includeBlocked: true)`).
         - Each app item should have its icon (if available or standard app icon), name, package name, and a Switch or Checkbox to toggle block status.
         - When toggled, update and persist the blocked package names list in SharedPreferences.
     - **Tab 3: System Permissions (ListView)**:
       - Microphones, Contacts, Phone, SMS, Notifications permissions list (each with Grant button / status).
       - Screen Control (Accessibility) Card.
       - Shizuku Card.
     - **Tab 4: Telegram & About (ListView)**:
       - Telegram Remote Access switch and Bot Token text field.
       - About section (repository link, YouTube link, version details).
   - Ensure a single "Save Settings" floating action button or action button in the AppBar (or save dynamically and show SnackBar). If you keep the "Save Settings" button, make sure it saves all the new fields to `AiService` and `SharedPreferences`.
   - All colors must use `Theme.of(context).colorScheme` (no hardcoded colors like `Colors.green`, `Colors.orange`, etc.).

Verify that all changes compile, analyze cleanly using `D:\Dart\dart-sdk\bin\dart.exe analyze`, and all unit tests in `test/security_test.dart` still pass.
Once complete, write your handoff report to `handoff.md` (strictly in English) in your working directory and reply to me in German using the standard messaging format.
