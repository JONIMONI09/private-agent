# Settings & State Audit Report

## 1. Traceability Matrix: Setting State Updates, Loads, and Saves

### 1.1 In `lib/screens/settings_screen.dart`
- **Initial State Loading (`initState`):**
  - Line 57: Loads `apiKey` from `widget.aiService.apiKey`.
  - Line 58: Loads `baseUrl` from `widget.aiService.baseUrl`.
  - Line 59: Loads `model` from `widget.aiService.model`.
  - Lines 60–62: Loads `botToken` from `widget.telegramService.botToken`.
  - Line 63: Loads `isEnabled` from `widget.telegramService.isEnabled` into `_telegramEnabled`.
  - Line 64: Loads `rawMaxSteps` from `widget.aiService.rawMaxSteps` into `_maxSteps`.
  - Line 65: Loads `disableMaxSteps` from `widget.aiService.disableMaxSteps` into `_disableMaxSteps`.
  - Line 68: Loads `yoloMode` from `widget.aiService.yoloMode` into `_yoloMode`.
  - Line 69: Loads `toolCallingFormat` from `widget.aiService.toolCallingFormat` into `_toolCallingFormat`.
  - Line 70: Loads `extremeThinkingDepth` from `widget.aiService.extremeThinkingDepth` into `_extremeThinkingDepth`.
  - Line 71: Loads `autoCompressHistory` from `widget.aiService.autoCompressHistory` into `_autoCompressHistory`.
  - Line 72: Loads `mcpEnabled` from `widget.aiService.mcpEnabled` into `_mcpEnabled`.
  - Line 73: Loads `mcpUrl` from `widget.aiService.mcpUrl` via `_mcpUrlController`.
  - Lines 74–76: Loads `telegramWhitelist` from `widget.aiService.telegramWhitelist` via `_telegramWhitelistController`.

- **State Local/Immediate Updates:**
  - Lines 298–300: `_telegramEnabled` switch updates local UI state.
  - Lines 375–380: `_yoloMode` switch updates UI and immediately calls `widget.aiService.saveYoloMode(val)`.
  - Lines 472–474: `_disableMaxSteps` switch updates local UI state.
  - Lines 487–489: `_maxSteps` slider updates local UI state.
  - Lines 610–615: `_toolCallingFormat` segmented button updates UI and immediately calls `widget.aiService.toolCallingFormat = val.first`.
  - Lines 680–687: `_extremeThinkingDepth` slider updates UI and immediately calls `widget.aiService.extremeThinkingDepth = val.toInt()`.
  - Lines 711–714: `_autoCompressHistory` switch updates UI and immediately calls `widget.aiService.autoCompressHistory = val`.
  - Lines 745–748: `_mcpEnabled` switch updates UI and immediately calls `widget.aiService.mcpEnabled = val`.
  - Lines 759–762: `_mcpUrlController` textfield `onChanged` immediately calls `widget.aiService.mcpUrl = val` on every keystroke.

- **Bulk Saving (`_saveAllSettings`):**
  - Lines 239–243: Saves API settings via `widget.aiService.saveSettings()`.
  - Lines 246–249: Saves Telegram settings via `widget.telegramService.saveSettings()`.
  - Line 252: Saves max steps via `widget.aiService.saveMaxSteps()`.
  - Line 253: Saves disable max steps toggle via `widget.aiService.saveDisableMaxSteps()`.
  - Line 254: Saves YOLO mode via `widget.aiService.saveYoloMode()`.
  - Line 255: Saves Telegram whitelist via `widget.aiService.telegramWhitelist = ...` setter.
  - Line 256: Saves tool calling format via `widget.aiService.toolCallingFormat = ...` setter.
  - Line 257: Saves extreme thinking depth via `widget.aiService.extremeThinkingDepth = ...` setter.
  - Line 258: Saves auto compress history via `widget.aiService.autoCompressHistory = ...` setter.
  - Line 259: Saves MCP enabled state via `widget.aiService.mcpEnabled = ...` setter.
  - Line 260: Saves MCP server URL via `widget.aiService.mcpUrl = ...` setter.

---

### 1.2 In `lib/services/ai_service.dart`
- **Initial State Loading (`init`):**
  - Lines 127–139: Loads `api_key`, `api_base_url`, `api_model`, `api_max_steps`, `api_disable_max_steps`, `api_yolo_mode`, `api_tool_calling_format`, `api_thinking_depth`, `api_auto_compress_history`, `api_mcp_enabled`, `api_mcp_url`, and `telegram_chat_id_whitelist` from `SharedPreferences`.

- **Setting Persisting (Save Methods & Setters):**
  - Lines 164–188: `saveSettings(...)` commits API properties to `SharedPreferences` (`api_key`, `api_base_url`, `api_model`).
  - Lines 190–194: `saveMaxSteps(...)` commits `api_max_steps`.
  - Lines 196–200: `saveDisableMaxSteps(...)` commits `api_disable_max_steps`.
  - Lines 202–206: `saveYoloMode(...)` commits `api_yolo_mode`.
  - Lines 218–221: `toolCallingFormat` setter writes `api_tool_calling_format` via `_saveStringSetting`.
  - Lines 224–227: `extremeThinkingDepth` setter writes `api_thinking_depth` via `_saveIntSetting`.
  - Lines 229–233: `autoCompressHistory` setter writes `api_auto_compress_history` via `_saveBoolSetting`.
  - Lines 235–244: `mcpEnabled` setter writes `api_mcp_enabled` via `_saveBoolSetting` and triggers `_fetchMcpTools()` immediately if `true`.
  - Lines 246–250: `mcpUrl` setter writes `api_mcp_url` via `_saveStringSetting`.
  - Lines 252–256: `telegramWhitelist` setter writes `telegram_chat_id_whitelist` via `_saveStringSetting`.

---

### 1.3 In `lib/services/telegram_service.dart`
- **Initial State Loading (`init`):**
  - Lines 26–28: Loads `telegram_bot_token` and `telegram_enabled` from `SharedPreferences`.
- **Setting Persisting (`saveSettings`):**
  - Lines 35–47: Saves `telegram_bot_token` and `telegram_enabled` to `SharedPreferences` and stops or starts background polling.

---

## 2. Issues and Logical Disconnects Identified

### 2.1 The MCP Server URL Keystroke Performance Issue
- **Location:** `lib/screens/settings_screen.dart`, lines 759–762.
- **Problem:** The `onChanged` callback of the `TextField` for MCP URL updates `widget.aiService.mcpUrl` on *every single keystroke*. Writing asynchronously to `SharedPreferences` on every key pressed introduces lag, freezes, and writes partially-typed (invalid) URLs to storage.
- **Propagation Impact:** Highly inefficient UI/disk operations.

### 2.2 The Extreme Thinking Depth Slider Drag Performance Issue
- **Location:** `lib/screens/settings_screen.dart`, lines 680–687.
- **Problem:** The slider's `onChanged` handler immediately sets `widget.aiService.extremeThinkingDepth = val.toInt()`. When a user drags a slider, this event fires dozens of times per second, flooding `SharedPreferences` with disk write calls.
- **Propagation Impact:** Severe frame drops and potential disk write bottlenecks.

### 2.3 Save Order Race Condition (MCP URL vs. Fetching Tools)
- **Location:** `lib/screens/settings_screen.dart`, lines 259–260.
- **Problem:** In `_saveAllSettings`, `widget.aiService.mcpEnabled = _mcpEnabled;` is set **before** `widget.aiService.mcpUrl = _mcpUrlController.text.trim();`.
  Inside `AiService`'s setter for `mcpEnabled` (line 235), if enabling MCP is set to `true`, it immediately calls `_fetchMcpTools()`. However, at this exact moment, `_mcpUrl` in `AiService` has not been updated yet to the user's new input because the next line in the settings screen (`mcpUrl = ...`) has not run. Thus, `_fetchMcpTools()` queries the **old/previous URL**. After that, `mcpUrl` is updated, but no refetch is triggered.
- **Propagation Impact:** The new MCP tools are never fetched during this run, leaving the AI using either the previous tools or no tools at all.

### 2.4 Hybrid Auto-Save vs. Manual-Save UX Inconsistency
- **Location:** `lib/screens/settings_screen.dart`.
- **Problem:** The UI implements two contradictory save models. Standard options (API Key, Base URL, Model, Telegram Whitelist, Max Steps, Disable Max Steps) only apply and persist when the user taps "Save All Settings". However, the advanced toggle switches and sliders immediately persist changes to disk. If a user alters these toggles and exits the screen using the back arrow without tapping "Save", they might think their changes were discarded, when in fact they were immediately committed.
- **Propagation Impact:** Fragmented settings logic and poor user experience.

---

## 3. Recommended Code Replacements

To fix these issues, we recommend:
1. Removing immediate service writes in all widget `onChanged` / `onSelectionChanged` callbacks. They should strictly update the local widget state (using `setState`).
2. Cleaning up the `onChanged` handler from the MCP URL textfield (letting the controller hold the text value until the user saves).
3. Ordering the assignments in `_saveAllSettings` so that `mcpUrl` is updated **before** `mcpEnabled`.
4. Awaiting all save calls or invoking them consistently.

Here is the exact suggested code replacement for `lib/screens/settings_screen.dart`.

### 3.1 Replacement for `_saveAllSettings` (lines 237–267)

**Before:**
```dart
  Future<void> _saveAllSettings() async {
    // API & General
    await widget.aiService.saveSettings(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );

    // Telegram
    await widget.telegramService.saveSettings(
      botToken: _telegramTokenController.text.trim(),
      isEnabled: _telegramEnabled,
    );

    // Advanced & Limits
    await widget.aiService.saveMaxSteps(_maxSteps.toInt());
    await widget.aiService.saveDisableMaxSteps(_disableMaxSteps);
    await widget.aiService.saveYoloMode(_yoloMode);
    widget.aiService.telegramWhitelist = _telegramWhitelistController.text.trim();
    widget.aiService.toolCallingFormat = _toolCallingFormat;
    widget.aiService.extremeThinkingDepth = _extremeThinkingDepth;
    widget.aiService.autoCompressHistory = _autoCompressHistory;
    widget.aiService.mcpEnabled = _mcpEnabled;
    widget.aiService.mcpUrl = _mcpUrlController.text.trim();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All Settings Saved!')),
      );
    }
  }
```

**After:**
```dart
  Future<void> _saveAllSettings() async {
    // API & General
    await widget.aiService.saveSettings(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );

    // Telegram
    await widget.telegramService.saveSettings(
      botToken: _telegramTokenController.text.trim(),
      isEnabled: _telegramEnabled,
    );

    // Advanced & Limits
    await widget.aiService.saveMaxSteps(_maxSteps.toInt());
    await widget.aiService.saveDisableMaxSteps(_disableMaxSteps);
    await widget.aiService.saveYoloMode(_yoloMode);
    widget.aiService.telegramWhitelist = _telegramWhitelistController.text.trim();
    widget.aiService.toolCallingFormat = _toolCallingFormat;
    widget.aiService.extremeThinkingDepth = _extremeThinkingDepth;
    widget.aiService.autoCompressHistory = _autoCompressHistory;
    
    // Crucial: Save MCP URL first, then enable MCP. This ensures the correct URL is queried for tools.
    widget.aiService.mcpUrl = _mcpUrlController.text.trim();
    widget.aiService.mcpEnabled = _mcpEnabled;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All Settings Saved!')),
      );
    }
  }
```

---

### 3.2 Replacement for UI Toggles / Sliders to prevent immediate writes and keystroke disk writes

#### 3.2.1 YOLO Mode switch (lines 369–381)
**Before:**
```dart
        SwitchListTile(
          title: const Text('YOLO Mode (Autonomous)'),
          subtitle: const Text(
            'When enabled, the agent executes all actions without asking for confirmation.',
          ),
          value: _yoloMode,
          onChanged: (val) {
            if (mounted) {
              setState(() => _yoloMode = val);
            }
            widget.aiService.saveYoloMode(val);
          },
        ),
```
**After:**
```dart
        SwitchListTile(
          title: const Text('YOLO Mode (Autonomous)'),
          subtitle: const Text(
            'When enabled, the agent executes all actions without asking for confirmation.',
          ),
          value: _yoloMode,
          onChanged: (val) {
            if (mounted) {
              setState(() => _yoloMode = val);
            }
          },
        ),
```

#### 3.2.2 Tool Calling Format SegmentedButton (lines 596–616)
**Before:**
```dart
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'JSON',
              label: Text('JSON'),
              icon: Icon(Icons.code),
            ),
            ButtonSegment(
              value: 'XML',
              label: Text('XML'),
              icon: Icon(Icons.data_object),
            ),
          ],
          selected: {_toolCallingFormat},
          onSelectionChanged: (val) {
            if (mounted) {
              setState(() => _toolCallingFormat = val.first);
            }
            widget.aiService.toolCallingFormat = val.first;
          },
        ),
```
**After:**
```dart
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'JSON',
              label: Text('JSON'),
              icon: Icon(Icons.code),
            ),
            ButtonSegment(
              value: 'XML',
              label: Text('XML'),
              icon: Icon(Icons.data_object),
            ),
          ],
          selected: {_toolCallingFormat},
          onSelectionChanged: (val) {
            if (mounted) {
              setState(() => _toolCallingFormat = val.first);
            }
          },
        ),
```

#### 3.2.3 Extreme Thinking Depth Slider (lines 674–688)
**Before:**
```dart
                    Slider(
                      value: _extremeThinkingDepth.toDouble(),
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: _extremeThinkingDepth.toString(),
                      onChanged: (val) {
                        if (mounted) {
                          setState(
                            () => _extremeThinkingDepth = val.toInt(),
                          );
                        }
                        widget.aiService.extremeThinkingDepth = val.toInt();
                      },
                    ),
```
**After:**
```dart
                    Slider(
                      value: _extremeThinkingDepth.toDouble(),
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: _extremeThinkingDepth.toString(),
                      onChanged: (val) {
                        if (mounted) {
                          setState(
                            () => _extremeThinkingDepth = val.toInt(),
                          );
                        }
                      },
                    ),
```

#### 3.2.4 Auto-Compress History SwitchListTile (lines 704–715)
**Before:**
```dart
        SwitchListTile(
          title: const Text('Auto-Compress History'),
          subtitle: const Text(
            'Automatically compress chat history when token limits are reached '
            'to prevent context overflow.',
          ),
          value: _autoCompressHistory,
          onChanged: (val) {
            if (mounted) setState(() => _autoCompressHistory = val);
            widget.aiService.autoCompressHistory = val;
          },
        ),
```
**After:**
```dart
        SwitchListTile(
          title: const Text('Auto-Compress History'),
          subtitle: const Text(
            'Automatically compress chat history when token limits are reached '
            'to prevent context overflow.',
          ),
          value: _autoCompressHistory,
          onChanged: (val) {
            if (mounted) setState(() => _autoCompressHistory = val);
          },
        ),
```

#### 3.2.5 Enable MCP Server SwitchListTile (lines 739–749)
**Before:**
```dart
        SwitchListTile(
          title: const Text('Enable MCP Server'),
          subtitle: const Text(
            'Connect to external MCP tool servers for additional capabilities.',
          ),
          value: _mcpEnabled,
          onChanged: (val) {
            if (mounted) setState(() => _mcpEnabled = val);
            widget.aiService.mcpEnabled = val;
          },
        ),
```
**After:**
```dart
        SwitchListTile(
          title: const Text('Enable MCP Server'),
          subtitle: const Text(
            'Connect to external MCP tool servers for additional capabilities.',
          ),
          value: _mcpEnabled,
          onChanged: (val) {
            if (mounted) setState(() => _mcpEnabled = val);
          },
        ),
```

#### 3.2.6 MCP Server URL TextField (lines 752–763)
**Before:**
```dart
          TextField(
            controller: _mcpUrlController,
            decoration: const InputDecoration(
              labelText: 'MCP Server URL',
              hintText: 'http://10.0.2.2:3000',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              widget.aiService.mcpUrl = val;
            },
          ),
```
**After:**
```dart
          TextField(
            controller: _mcpUrlController,
            decoration: const InputDecoration(
              labelText: 'MCP Server URL',
              hintText: 'http://10.0.2.2:3000',
              border: OutlineInputBorder(),
            ),
          ),
```
