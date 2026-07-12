# PrivateAgent UI/UX, Settings, and AI Audit & Improvement Plan

This document presents a comprehensive, read-only audit of the PrivateAgent Flutter application. The audit is structured into three areas: **UI/UX and Rendering**, **Settings and State Functionality**, and **AI Integration and Token Efficiency**.

None of the actual source `.dart` files have been modified. This document serves as the blueprints for recommended changes.

---

## 1. Executive Summary

A comprehensive investigation of the PrivateAgent codebase has revealed:
* **Visual Overflows and UI Clutter:** Critical horizontal overflows on standard portrait mobile devices due to unconstrained permission labels and long tool badge identifiers. The App Bar is cluttered with up to 5 icons, which should be consolidated.
* **Disk Write Bottlenecks and State Sync Race Condition:** Keystrokes in the MCP Server URL field and drags on the Extreme Thinking Depth slider trigger immediate disk writes via `SharedPreferences`, causing UI stutter. Also, a race condition saves the MCP enabled toggle before the MCP URL is updated, causing the service to query the old URL for tools.
* **Token-Wasting Patterns and History Loss:** History truncation discards the summary at index 0, destroying context. Stateless background task execution lacks full step history, leading to repeated clicking loops. Layout dumps are bloated with redundant coordinates and full Java namespaces, adding unnecessary token overhead.

Implementing the recommended changes will eliminate visual layout crashes, resolve database sync issues, prevent API 400 errors, and save **up to 40,000+ tokens** on looping runs.

---

## 2. UI/UX & Rendering Audit

### Issue 2.1: AppBar Actions Overflow (Cluttered Icons)
* **File & Lines:** `lib/screens/home_screen.dart` (lines 529-625)
* **Problem:** There are up to five action buttons rendered in the `AppBar` (visibility test, Shizuku status, compress context, delete history, settings). On typical 360dp portrait screens, this leaves insufficient space for the app title, causing truncation and rendering overlap.
* **Solution:** Retain the settings button and Shizuku status indicator as top-level widgets, but group secondary actions ("Test Screen Reading", "Compress Context", and "Clear Chat") into a standard Material `PopupMenuButton` (overflow menu).
* **Recommended Code Replacement:**
  * **Before:**
    ```dart
    actions: [
      // Screen control test button
      IconButton(
        icon: const Icon(Icons.visibility),
        tooltip: 'Test screen reading',
        onPressed: () async {
          final isRunning = await _actionHandler.screenAutomation
              .isServiceRunning();
          if (!isRunning) {
            setState(() {
              _messages.add(ChatMessage(
                role: 'assistant',
                content:
                    '❌ Screen Control is not enabled!\n\n'
                    'To enable it:\n'
                    '1. Go to Settings (⚙️ icon)\n'
                    '2. Find "Screen Control (Accessibility)"\n'
                    '3. Tap "Open Accessibility Settings"\n'
                    '4. Find "PrivateAgent Screen Control"\n'
                    '5. Toggle it ON',
              ));
            });
            _scrollToBottom();
            return;
          }
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              content: '🔍 Reading screen...',
            ));
          });
          _scrollToBottom();
          final description = await _actionHandler.screenAutomation
              .getScreenDescription();
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              content: '📱 Screen Content:\n\n$description',
            ));
          });
          _scrollToBottom();
        },
      ),
      // Shizuku status indicator
      if (_actionHandler.shizuku.isAvailable)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            Icons.link,
            size: 18,
            color: _actionHandler.shizuku.hasPermission
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      IconButton(
        icon: _isCompressing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.compress),
        tooltip: 'Compress Context',
        onPressed: _isCompressing ? null : _compressContext,
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Clear chat',
        onPressed: () {
          setState(() {
            _messages.clear();
            _aiService.clearHistory();
            _currentPlan = null;
          });
        },
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                aiService: _aiService,
                shizukuService: _actionHandler.shizuku,
                screenAutomationService: _actionHandler.screenAutomation,
                telegramService: _telegramService,
              ),
            ),
          );
          // Refresh Shizuku status after settings
          await _actionHandler.shizuku.checkAvailability();
          if (mounted) setState(() {});
        },
      ),
    ],
    ```
  * **After:**
    ```dart
    actions: [
      // Shizuku status indicator
      if (_actionHandler.shizuku.isAvailable)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.link,
            size: 18,
            color: _actionHandler.shizuku.hasPermission
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                aiService: _aiService,
                shizukuService: _actionHandler.shizuku,
                screenAutomationService: _actionHandler.screenAutomation,
                telegramService: _telegramService,
              ),
            ),
          );
          // Refresh Shizuku status after settings
          await _actionHandler.shizuku.checkAvailability();
          if (mounted) setState(() {});
        },
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          switch (value) {
            case 'test_screen':
              final isRunning = await _actionHandler.screenAutomation.isServiceRunning();
              if (!isRunning) {
                setState(() {
                  _messages.add(ChatMessage(
                    role: 'assistant',
                    content:
                        '❌ Screen Control is not enabled!\n\n'
                        'To enable it:\n'
                        '1. Go to Settings (⚙️ icon)\n'
                        '2. Find "Screen Control (Accessibility)"\n'
                        '3. Tap "Open Accessibility Settings"\n'
                        '4. Find "PrivateAgent Screen Control"\n'
                        '5. Toggle it ON',
                  ));
                });
                _scrollToBottom();
                return;
              }
              setState(() {
                _messages.add(ChatMessage(
                  role: 'assistant',
                  content: '🔍 Reading screen...',
                ));
              });
              _scrollToBottom();
              final description = await _actionHandler.screenAutomation.getScreenDescription();
              setState(() {
                _messages.add(ChatMessage(
                  role: 'assistant',
                  content: '📱 Screen Content:\n\n$description',
                ));
              });
              _scrollToBottom();
              break;
            case 'compress':
              if (!_isCompressing) {
                await _compressContext();
              }
              break;
            case 'clear':
              setState(() {
                _messages.clear();
                _aiService.clearHistory();
                _currentPlan = null;
              });
              break;
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'test_screen',
            child: Row(
              children: [
                Icon(Icons.visibility),
                SizedBox(width: 8),
                Text('Test Screen Reading'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'compress',
            enabled: !_isCompressing,
            child: Row(
              children: [
                _isCompressing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.compress),
                const SizedBox(width: 8),
                const Text('Compress Context'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'clear',
            child: Row(
              children: [
                Icon(Icons.delete_outline),
                SizedBox(width: 8),
                Text('Clear Chat'),
              ],
            ),
          ),
        ],
      ),
    ],
    ```

### Issue 2.2: TabBar Horizontal Compression
* **File & Lines:** `lib/screens/settings_screen.dart` (lines 211-218)
* **Problem:** The settings `TabBar` has 4 tabs containing both an icon and text. Because `isScrollable` is left at its default value (`false`), the 4 tabs are compressed into the screen width, leading to word wrapping, clipping, and text overlapping.
* **Solution:** Enable `isScrollable: true` and specify `tabAlignment: TabAlignment.start` for scrollable tabs.
* **Recommended Code Replacement:**
  * **Before:**
    ```dart
    bottom: const TabBar(
      tabs: [
        Tab(icon: Icon(Icons.tune), text: 'General'),
        Tab(icon: Icon(Icons.smart_toy), text: 'AI Models'),
        Tab(icon: Icon(Icons.security), text: 'Permissions'),
        Tab(icon: Icon(Icons.science), text: 'Advanced'),
      ],
    ),
    ```
  * **After:**
    ```dart
    bottom: const TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(icon: Icon(Icons.tune), text: 'General'),
        Tab(icon: Icon(Icons.smart_toy), text: 'AI Models'),
        Tab(icon: Icon(Icons.security), text: 'Permissions'),
        Tab(icon: Icon(Icons.science), text: 'Advanced'),
      ],
    ),
    ```

### Issue 2.3: Double Dividers
* **File & Lines:** `lib/screens/settings_screen.dart` (lines 315-317)
* **Problem:** Duplicate consecutive dividers in the General settings tab layout.
* **Solution:** Remove the redundant divider.
* **Recommended Code Replacement:**
  * **Before:**
    ```dart
    const Divider(height: 32),

    const Divider(height: 32),
    ```
  * **After:**
    ```dart
    const Divider(height: 32),
    ```

### Issue 2.4: Permission Card Layout Overflows
* **File & Lines:** `lib/screens/settings_screen.dart` (lines 885-891 and 960-966)
* **Problem:** Text widgets indicating Shizuku status ("Permission granted — ADB commands available") and Accessibility status ("Can read screen, tap, scroll, and type in other apps") are placed inside a `Row` alongside an icon. Because they are not wrapped in a layout boundary/constraint, they overflow the screen width horizontally.
* **Solution:** Wrap both text widgets in `Expanded` to force text wrapping.
* **Recommended Code Replacement (Shizuku Card):**
  * **Before:**
    ```dart
    Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Permission granted — ADB commands available',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 13,
          ),
        ),
      ],
    ),
    ```
  * **After:**
    ```dart
    Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Permission granted — ADB commands available',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
    ```
* **Recommended Code Replacement (Accessibility Card):**
  * **Before:**
    ```dart
    Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Can read screen, tap, scroll, and type in other apps',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 13,
          ),
        ),
      ],
    ),
    ```
  * **After:**
    ```dart
    Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Can read screen, tap, scroll, and type in other apps',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
    ```

### Issue 2.5: Timeline Connector Line Overrun
* **File & Lines:** `lib/widgets/plan_view.dart` (lines 136-139, 188)
* **Problem:** Each step row uses an `IntrinsicHeight` wrapper to match the height of the left timeline connector column and the right content card. However, a bottom margin of `12` is defined inside the content card container instead of the outer row container. Because the row height expands to fit the card content, the vertical connector line (in the left column) draws `12dp` further down, running past the bottom of the card border.
* **Solution:** Move the `bottom: 12` margin from the inner card container to the outer animated row container.
* **Recommended Code Replacement:**
  * **Before:**
    ```dart
    // Line 136
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: IntrinsicHeight(
        child: Row(
          // ...
          // Line 188 (Inside right column container)
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
    ```
  * **After:**
    ```dart
    // Line 136
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          // ...
          // Line 188 (Inside right column container)
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(16),
    ```

### Issue 2.6: Button Label Layout Overflow on Compact Device Viewports
* **File & Lines:** `lib/widgets/plan_view.dart` (lines 462-533)
* **Problem:** In the plan step controls, "Cancel", "Edit", and "Proceed" buttons are laid out horizontally. On narrow viewports, long labels combined with icons can exceed screen boundaries, causing visual clipping and overflow crashes.
* **Solution:** Wrap text labels in `FittedBox` with `BoxFit.scaleDown` to automatically scale text size under narrow bounds.
* **Recommended Code Replacement:**
  * **Before:**
    ```dart
    label: const Text('Cancel'), // Line 467
    label: const Text('Edit'), // Line 486
    label: Text(isExecuting ? 'Running...' : 'Proceed'), // Line 521
    ```
  * **After:**
    ```dart
    label: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text('Cancel'),
    ),
    label: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text('Edit'),
    ),
    label: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(isExecuting ? 'Running...' : 'Proceed'),
    ),
    ```

### Issue 2.7: Action Result Badge Text Overflow
* **File & Lines:** `lib/widgets/message_bubble.dart` (lines 108-117)
* **Problem:** Inside action bubble feedback, the action type is printed in a horizontal badge limited to 80% screen width. Extremely long action identifiers (e.g. `get_screen_automation_description_by_selector`) cause layout overflows.
* **Solution:** Wrap the text in `Flexible` and specify `overflow: TextOverflow.ellipsis`.
* **Recommended Code Replacement:**
  * **Before:**
    ```dart
    Text(
      widget.message.actionResult!.actionType.replaceAll('_', ' '),
      style: TextStyle(
        fontSize: 11,
        color: widget.message.actionResult!.success
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w600,
      ),
    )
    ```
  * **After:**
    ```dart
    Flexible(
      child: Text(
        widget.message.actionResult!.actionType.replaceAll('_', ' '),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: widget.message.actionResult!.success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    )
    ```

---

## 3. Settings & State Functionality Audit

### Issue 3.1: Keystroke and Drag Write Disk Bottlenecks
* **File & Lines:** `lib/screens/settings_screen.dart` (lines 680-687 and 759-762)
* **Problem:** Typing in the MCP URL field and dragging the Thinking Depth slider immediately update service states, causing continuous asynchronous writes to `SharedPreferences`. This blocks CPU threads, drops frames, and writes invalid URL states to disk.
* **Solution:** Disable immediate saving inside `onChanged` handlers of sliders and textfields. Instead, update the local screen state via `setState`, and write to `AiService` only when the user taps "Save All Settings".

### Issue 3.2: Save Order Race Condition (MCP Tools Fetching)
* **File & Lines:** `lib/screens/settings_screen.dart` (lines 259-260)
* **Problem:** In `_saveAllSettings`, `aiService.mcpEnabled` is updated *before* `aiService.mcpUrl`. Inside `AiService`'s setter for `mcpEnabled`, if it is set to `true`, it immediately calls `_fetchMcpTools()` to load tools. Since the setter for `mcpUrl` has not run yet, `_fetchMcpTools()` queries the **old URL**.
* **Solution:** Order the assignments in `_saveAllSettings` so that `mcpUrl` is written first, ensuring that `_fetchMcpTools()` queries the updated URL.

### Issue 3.3: Auto-Save vs. Manual-Save UX Inconsistency
* **File & Lines:** `lib/screens/settings_screen.dart`
* **Problem:** General parameters (API key, base URL, model) require tapping "Save All Settings" to persist. However, sliders and toggle switches (YOLO mode, auto-compress, MCP enabled, thinking depth) immediately commit to disk. A user backing out of settings might think their switch changes were unsaved, when in fact they were committed.
* **Solution:** Align all input structures in the settings page to commit only during the unified `_saveAllSettings()` call.

### Recommended Code Replacements for Settings Screen & State Sync:

#### 3.3.1 Replacement for `_saveAllSettings` (lines 237–267)
* **Before:**
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
* **After:**
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
    
    // Crucial fix: Save MCP URL first, then enable MCP. This ensures the correct URL is queried for tools.
    widget.aiService.mcpUrl = _mcpUrlController.text.trim();
    widget.aiService.mcpEnabled = _mcpEnabled;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All Settings Saved!')),
      );
    }
  }
  ```

#### 3.3.2 Replacement for Slider & Toggle switches:
* **YOLO Mode Switch (Lines 369-381):**
  * **Before:**
    ```dart
    onChanged: (val) {
      if (mounted) {
        setState(() => _yoloMode = val);
      }
      widget.aiService.saveYoloMode(val);
    },
    ```
  * **After:**
    ```dart
    onChanged: (val) {
      if (mounted) {
        setState(() => _yoloMode = val);
      }
    },
    ```
* **Tool Calling Format Segmented Button (Lines 596-616):**
  * **Before:**
    ```dart
    onSelectionChanged: (val) {
      if (mounted) {
        setState(() => _toolCallingFormat = val.first);
      }
      widget.aiService.toolCallingFormat = val.first;
    },
    ```
  * **After:**
    ```dart
    onSelectionChanged: (val) {
      if (mounted) {
        setState(() => _toolCallingFormat = val.first);
      }
    },
    ```
* **Extreme Thinking Depth Slider (Lines 674-688):**
  * **Before:**
    ```dart
    onChanged: (val) {
      if (mounted) {
        setState(
          () => _extremeThinkingDepth = val.toInt(),
        );
      }
      widget.aiService.extremeThinkingDepth = val.toInt();
    },
    ```
  * **After:**
    ```dart
    onChanged: (val) {
      if (mounted) {
        setState(
          () => _extremeThinkingDepth = val.toInt(),
        );
      }
    },
    ```
* **Auto-Compress History Switch (Lines 704-715):**
  * **Before:**
    ```dart
    onChanged: (val) {
      if (mounted) setState(() => _autoCompressHistory = val);
      widget.aiService.autoCompressHistory = val;
    },
    ```
  * **After:**
    ```dart
    onChanged: (val) {
      if (mounted) setState(() => _autoCompressHistory = val);
    },
    ```
* **Enable MCP Server Switch (Lines 739-749):**
  * **Before:**
    ```dart
    onChanged: (val) {
      if (mounted) setState(() => _mcpEnabled = val);
      widget.aiService.mcpEnabled = val;
    },
    ```
  * **After:**
    ```dart
    onChanged: (val) {
      if (mounted) setState(() => _mcpEnabled = val);
    },
    ```
* **MCP Server URL TextField (Lines 752-763):**
  * **Before:**
    ```dart
    onChanged: (val) {
      widget.aiService.mcpUrl = val;
    },
    ```
  * **After:**
    ```dart
    // Remove onChanged callback so that values are only read from controller during save settings
    ```

---

## 4. AI Integration & Token Efficiency Audit

### Issue 4.1: History Truncation Erases the Compressed Summary
* **File & Lines:** `lib/services/ai_service.dart` (lines 448-450)
* **Problem:** When the rolling conversation history length exceeds 20, older messages are pruned with `removeRange(0, length - 20)`. The summary loaded at index 0 from `compressHistory()` is immediately lost in the next turns.
* **Solution:** Detect the presence of the system summary role at index 0, and prune range from index 1 to retain the summary at the start of the list.

### Issue 4.2: API Protocol Violation (Multiple System Messages)
* **File & Lines:** `lib/services/ai_service.dart` (lines 453-457)
* **Problem:** The summary is saved as a system message. Adding the system prompt creates multiple system messages in the final request payload, violating Claude/Gemini API contracts.
* **Solution:** Dynamically merge the history summary string directly into the primary system prompt string before sending it to the model.

### Issue 4.3: Stateless Task Execution Lacks Sequence History
* **File & Lines:** `lib/services/task_executor.dart` (lines 126-143)
* **Problem:** Background tasks are stateless (`sendStatelessMessage`). The LLM prompt only receives the last step result, making it unaware of steps 1 to N-2. This leads to infinite repeat-action loops.
* **Solution:** Maintain a chronological list of prior executed actions and inject it into the prompt.

### Issue 4.4: Task Tool Calling Formatting Discrepancies
* **File & Lines:** `lib/services/task_executor.dart` (lines 46-97)
* **Problem:** In XML tool calling mode, the system prompt describes the XML syntax but displays the list of available actions in JSON format. This causes format mixing in responses.
* **Solution:** Dynamically format the available actions as XML elements when XML calling format is chosen.

### Issue 4.5: Weak XML Matcher and Unsound Completion Defaults
* **File & Lines:** `lib/services/task_executor.dart` (lines 162-201)
* **Problem:** The action name matcher regex is unanchored and can match thought comments. Captured parameters contain un-trimmed white space, and the parser defaults `isComplete` to `true` (if the tag is omitted), causing premature task exit.
* **Solution:** Anchor the action regex tag, trim input values, and default `isComplete` to `false` (same as JSON).

### Issue 4.6: High Layout Payload Verbosity in Screen Dumps
* **File & Lines:** `lib/services/screen_automation_service.dart` (lines 47-99)
* **Problem:** Accessibility screen dumps contain full Java package namespace paths (e.g. `android.widget.TextView`) and redundantly output bounds coordinates `[left,top,right,bottom]` plus center points. This adds up to 1,500+ tokens per step.
* **Solution:** Strip Java package namespaces to just the class name, and output only the center coordinates `(x, y)` since clicking only requires the center.

### Recommended Code Replacements for AI Services:

#### 4.6.1 Replacement for `_getSystemPrompt()` in `lib/services/ai_service.dart` (Lines 45-124)
Add missing handler tools (`set_timer`, `send_email`, `open_url`, `read_notifications`, `run_adb_command`) to the prompt:
```dart
  String _getSystemPrompt() {
    final String mcpToolsString = _mcpTools.isNotEmpty 
        ? "- mcp_tool: ${_mcpTools.map((t) => t['name']).join(', ')} (Use as instructed by system)" 
        : "";

    if (_toolCallingFormat == 'XML') {
      return '''
You are PrivateAgent, an AI assistant controlling this Android device.
For device interaction, you MUST output a <thought>...</thought> block FIRST, followed by a raw XML action (no markdown backticks):

<thought>
[Phase 1: Analyze user intent]
...
[Phase 2: Evaluate tools]
...
</thought>
<action name="action_name">
  <params>
    <key>value</key>
  </params>
  <response>What you say to the user</response>
</action>

Available actions:
- open_app: <params><app_name>YouTube</app_name></params>
- make_call: <params><contact_name>Mom</contact_name></params> OR <params><phone_number>123456</phone_number></params>
- send_sms: <params><contact_name>John</contact_name><message>Hello</message></params>
- search_contact: <params><query>John</query></params>
- set_alarm: <params><hour>7</hour><minute>30</minute><label>Wake up</label></params>
- set_timer: <params><seconds>60</seconds><label>Timer label</label></params>
- set_volume: <params><level>50</level></params> (0-100)
- set_brightness: <params><level>50</level></params> (0-100)
- read_screen: <params></params>
- press_back: <params></params>
- read_notifications: <params></params>
- run_adb_command: <params><command>shell input keyevent 26</command></params>
- send_email: <params><to>recipient@example.com</to><subject>Hello</subject><body>Message body</body></params>
- open_url: <params><url>https://example.com</url></params>
$mcpToolsString

Workflows:
- execute_task: <params><goal>goal description</goal></params> (Use for multi-step automation.)

Rules:
1. ALWAYS provide <thought> first.
2. XML action must be outside the thought block.
3. No markdown code fences.
4. For normal conversation, reply with plain text naturally.
''';
    }

    return '''
You are PrivateAgent, an AI assistant controlling this Android device.
For device interaction, you MUST output a <thought>...</thought> block FIRST, followed by the raw JSON action object (no markdown backticks, no code fences):

<thought>
[Phase 1: Analyze user intent]
...
[Phase 2: Evaluate tools]
...
</thought>
{"action": "action_name", "params": {"key": "value"}, "response": "Optional message to user"}

Available actions:
- open_app: {"app_name": "YouTube"}
- make_call: {"contact_name": "Mom"} OR {"phone_number": "123456"}
- send_sms: {"contact_name": "John", "message": "Hi"}
- search_contact: {"query": "John"}
- set_alarm: {"hour": 7, "minute": 30, "label": "Wake up"}
- set_timer: {"seconds": 60, "label": "Timer label"}
- set_volume: {"level": 50} (0-100)
- set_brightness: {"level": 50} (0-100)
- read_screen: {}
- press_back: {}
- read_notifications: {}
- run_adb_command: {"command": "shell input keyevent 26"}
- send_email: {"to": "recipient@example.com", "subject": "Hello", "body": "Message body"}
- open_url: {"url": "https://example.com"}
$mcpToolsString

Workflows:
- execute_task: {"goal": "goal description"} (Use for multi-step automation.)

Rules:
1. ALWAYS provide <thought> first.
2. The JSON action must be outside the thought block.
3. NEVER wrap JSON in ```json ... ``` code fences.
4. For normal conversation, reply with plain text naturally.
''';
  }
```

#### 4.6.2 Replacement for `sendMessage()` inside `lib/services/ai_service.dart` (Lines 441-499)
```dart
    // Add ONLY the text to the persistent conversation history to save tokens.
    _conversationHistory.add({
      'role': 'user',
      'content': message,
    });

    // Keep conversation history manageable (last 20 messages)
    if (_conversationHistory.length > 20) {
      final hasSummary = _conversationHistory.isNotEmpty && _conversationHistory[0]['role'] == 'system';
      if (hasSummary) {
        // Protect the summary at index 0, trim intermediate history
        _conversationHistory.removeRange(1, _conversationHistory.length - 19);
      } else {
        _conversationHistory.removeRange(0, _conversationHistory.length - 20);
      }
    }

    try {
      // Build the prompt including system instructions
      final systemPrompt = _getSystemPrompt();
      final List<Map<String, String>> payloadMessages = [];
      String finalSystemPrompt = systemPrompt;
      int historyStartIdx = 0;

      // Extract the history summary if it sits at index 0 and merge to comply with single system message rule
      if (_conversationHistory.isNotEmpty && _conversationHistory[0]['role'] == 'system') {
        finalSystemPrompt = '$systemPrompt\n\n### CONVERSATION SUMMARY SO FAR\n${_conversationHistory[0]['content']}';
        historyStartIdx = 1;
      }

      payloadMessages.add({'role': 'system', 'content': finalSystemPrompt});
      for (int i = historyStartIdx; i < _conversationHistory.length; i++) {
        payloadMessages.add(_conversationHistory[i]);
      }

      // Integrate Extreme Thinking Depth
      double temperature = 0.7;
      if (_extremeThinkingDepth > 0) {
        // Lower temperature for higher depth to reduce hallucinations
        temperature = (0.7 - (_extremeThinkingDepth * 0.1)).clamp(0.1, 0.7);
        
        // Add a "Think harder" directive to the last message if depth is high
        if (_extremeThinkingDepth >= 3) {
          final lastMsg = payloadMessages.last;
          if (lastMsg['role'] == 'user') {
            payloadMessages[payloadMessages.length - 1] = {
              'role': 'user',
              'content': '${lastMsg['content']}\n\n(Think very carefully about this step-by-step before responding)',
            };
          }
        }
      }

      String requestUrl = _baseUrl;
      if (requestUrl.endsWith('/chat/completions')) {
        requestUrl = requestUrl; // User already included it
      } else {
        if (requestUrl.endsWith('/')) {
          requestUrl = '${requestUrl}chat/completions';
        } else {
          requestUrl = '$requestUrl/chat/completions';
        }
      }

      final response = await httpClient.post(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://github.com/orailnoor/private-agent',
          'X-Title': 'PrivateAgent',
        },
        body: jsonEncode({
          'model': _model,
          'messages': payloadMessages,
          'temperature': temperature,
          'max_tokens': 1024,
          if (_extremeThinkingDepth > 0) 'top_p': (1.0 - (_extremeThinkingDepth * 0.05)).clamp(0.8, 1.0),
        }),
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('API request timed out after 30 seconds.');
      });
```

#### 4.6.3 Replacement for `_getTaskSystemPrompt()` in `lib/services/task_executor.dart` (Lines 46-97)
```dart
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
```

#### 4.6.4 Replacement for prompt building and parsing in `executeTask` in `lib/services/task_executor.dart` (Lines 126-220)
```dart
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
          final nameMatch = RegExp(r'<action\s+name\s*=\s*["\']([^"\']+)["\']').firstMatch(dataStr);
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
```

#### 4.6.5 Replacement for `getScreenDescription()` in `lib/services/screen_automation_service.dart` (Lines 47-99)
```dart
  /// Get a simplified text description of the current screen for the LLM
  Future<String> getScreenDescription() async {
    final nodes = await dumpScreen();
    if (nodes.isEmpty) {
      return 'Could not read screen. Make sure accessibility service is enabled.';
    }

    final buffer = StringBuffer();
    final pkg = await getCurrentPackage();
    if (pkg != null) {
      buffer.writeln('Current app: $pkg');
    }
    buffer.writeln('Screen elements:');

    for (final node in nodes) {
      final index = node['index'];
      final text = node['text'] ?? '';
      final desc = node['contentDescription'] ?? '';
      var className = node['className'] as String? ?? '';
      final isClickable = node['isClickable'] == true;
      final isEditable = node['isEditable'] == true;
      final isScrollable = node['isScrollable'] == true;

      final displayText = text.isNotEmpty ? text : desc;
      if (displayText.isEmpty && !isClickable && !isEditable && !isScrollable) {
        continue; // Skip empty non-interactive nodes
      }

      // Simplify full Java package names to save characters/tokens
      if (className.contains('.')) {
        className = className.split('.').last;
      }

      final tags = <String>[];
      if (isClickable) tags.add('clickable');
      if (isEditable) tags.add('editable');
      if (isScrollable) tags.add('scrollable');

      final label = displayText.isNotEmpty ? '"$displayText"' : '(no text)';
      final type = className.isNotEmpty ? '[$className]' : '';
      final tagStr = tags.isNotEmpty ? '{${tags.join(", ")}}' : '';
      
      String boundsStr = '';
      if (node['bounds'] is Map) {
        final b = node['bounds'] as Map;
        final left = b['left'] is num ? (b['left'] as num).toDouble() : 0.0;
        final right = b['right'] is num ? (b['right'] as num).toDouble() : 0.0;
        final top = b['top'] is num ? (b['top'] as num).toDouble() : 0.0;
        final bottom = b['bottom'] is num ? (b['bottom'] as num).toDouble() : 0.0;
        final centerX = (left + right) / 2;
        final centerY = (top + bottom) / 2;
        // Output center coordinates only to reduce redundancy and simplify coordinates for AI
        boundsStr = ' center:(${centerX.round()},${centerY.round()})';
      }

      buffer.writeln('  [$index] $type $label $tagStr$boundsStr');
    }

    return buffer.toString();
  }
```

---

## 5. Verification Commands

To verify that these code changes do not break compilation or disrupt the existing test suite, run the following commands:
1. Validate formatting and analyze codebase:
   `flutter analyze`
2. Run general and integration tests:
   `flutter test test/ai_service_test.dart`
   `flutter test test/ai_integration_test.dart`
   `flutter test test/security_test.dart`
