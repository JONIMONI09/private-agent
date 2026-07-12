# PrivateAgent – Learning Log

## Discoveries from Build Finalization (2026-07-04)

### Environment
- **Flutter SDK**: Extracted from `flutter_windows_3.44.4-stable.zip` in the project root.
- **Android SDK**: Located at `D:\Android\sdk`.
- **Missing Tools**: The `cmdline-tools` (sdkmanager) were missing in the standard Android SDK location. Found alternative tools in `D:\unityEDITOR\6000.4.0f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\cmdline-tools` and copied them to `D:\Android\sdk\cmdline-tools\latest`.
- **Licenses**: All Android licenses were accepted via `flutter doctor --android-licenses`.
- **Setup Script**: Created `setup_env.bat` in the project root to automate environment variable configuration.

### Environment & Emulator Fixes (2026-07-04)
- **ANDROID_SDK_ROOT**: Added `ANDROID_SDK_ROOT` to the environment to resolve emulator startup issues.
- **AVD Configuration**: Fixed `Pixel_10_Pro_XL` AVD which was pointing to a non-existent `android-36.1` system image. Updated its `config.ini` to use the available `android-35` image.
- **IDE Integration**: Added `.vscode/settings.json` to explicitly define Flutter and Dart SDK paths, resolving "Dart executable not found" errors in IDE plugins.
- **Path Prioritization**: Updated `setup_env.bat` to prioritize the local Flutter SDK's Dart version over system-wide Dart installations.

### Architecture
- The application uses a **Command-Dispatcher pattern** where the LLM acts as the intent classifier.
- **Two competing system prompts** exist: one in `AiService` (general assistant actions) and one in `TaskExecutor` (multi-step agent tasks). These can conflict within the shared conversation history.
- **CommunicationService** instantiates its own copy of `ContactsService()` instead of sharing the instance from `ActionHandler`. This causes duplicate permission requests.
- **NotificationService** is instantiated dynamically inside `TaskExecutor` instead of acting as a shared singleton service.

### CodeGraph Status
- CodeGraph indexed: 272 Nodes, 528 Edges (32 files).
- `codegraph explore` works perfectly for this codebase.
- `.codegraph/` configuration is active and saved in the workspace.

### Detected Bugs and Code Smells
- Operations return descriptive error strings (`'Error: $e'`) instead of letting exceptions bubble up or wrapping them in a result type.
- Logical failures still return `success: true` status indicators.
- Native communication errors in `screen_automation_service.dart` are silently caught and ignored (`catch (e) { return false; }`).
- `_handleIncomingMessage` inside `TelegramService` runs asynchronously without being awaited, creating potential race conditions.

### Performance Notes
- `TaskExecutor` appends complete accessibility text dumps to the shared message history at every iteration, resulting in rapid token utilization.
- Chat history is hard-limited to the last 20 messages via a sliding window.
- The contacts service loads all contacts into memory and searches client-side, which has a performance impact for large directories.
- App configurations and packages are cached, but contact details are retrieved dynamically on every lookup.
