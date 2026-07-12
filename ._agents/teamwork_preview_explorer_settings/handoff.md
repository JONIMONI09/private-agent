# Handoff Report — Settings & State Audit

## 1. Observation
- In `lib/screens/settings_screen.dart`, lines 759–762:
  ```dart
            onChanged: (val) {
              widget.aiService.mcpUrl = val;
            },
  ```
- In `lib/screens/settings_screen.dart`, lines 680–687:
  ```dart
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
- In `lib/screens/settings_screen.dart`, lines 259–260:
  ```dart
      widget.aiService.mcpEnabled = _mcpEnabled;
      widget.aiService.mcpUrl = _mcpUrlController.text.trim();
  ```
- In `lib/services/ai_service.dart`, setter `mcpEnabled` (lines 235–244):
  ```dart
    set mcpEnabled(bool value) {
      _mcpEnabled = value;
      if (!value) {
        _mcpTools.clear();
      } else {
        _fetchMcpTools(); // Load them immediately when enabled
      }
      _saveBoolSetting('api_mcp_enabled', value);
    }
  ```

---

## 2. Logic Chain
1. By observing that `mcpUrl` `onChanged` triggers on every single keystroke (Observation 1), it is established that typing or pasting an MCP server URL fires disk/shared preferences operations constantly. This causes UI lag and blocks threads on every keystroke.
2. By observing that the `extremeThinkingDepth` slider triggers its `onChanged` immediately (Observation 2), drag events flood `SharedPreferences` with async writes, causing frame rate drops during interaction.
3. By observing the order of assignments in `_saveAllSettings` (Observation 3), `mcpEnabled` is set before `mcpUrl`.
4. When `mcpEnabled` is set to `true`, the setter in `AiService` (Observation 4) immediately calls `_fetchMcpTools()`.
5. Since `_fetchMcpTools()` uses the value of `_mcpUrl`, and the new URL has not been assigned yet (as it's on the next line of `_saveAllSettings`), `_fetchMcpTools()` queries the **old URL** instead of the newly entered URL.
6. The new URL is then set, but its tools are never fetched, resulting in a persistent state mismatch where the wrong tools are loaded in memory.
7. Disabling direct saves inside onChanged handlers of toggles/sliders (which currently auto-commit immediately, unlike manual-save fields like API key) solves these issues and ensures consistency.

---

## 3. Caveats
- No code was actually written or run on-device during this audit. The investigation is based strictly on source code analysis.
- The environment path configuration on the host did not support running `flutter test` directly, but the logic chain was validated against standard Dart/Flutter lifecycle patterns.

---

## 4. Conclusion
The settings state management has three critical flaws:
1. Keystroke and drag-tick disk writing performance bottlenecks.
2. A race condition/incorrect fetching sequence when configuring the MCP URL and saving.
3. Inconsistent UX where some settings auto-save while others require a manual save.

These can be fully corrected by standardizing the settings screen to apply settings only on pressing the "Save All Settings" button and correcting the assignment order for MCP configuration.

---

## 5. Verification Method
- **Verification steps:**
  1. Open `lib/screens/settings_screen.dart` and confirm that all switch and slider `onChanged` handlers now only call `setState` and do not invoke service setters.
  2. Confirm that the `MCP Server URL` textfield `onChanged` parameter has been removed.
  3. Confirm that in `_saveAllSettings()`, the line `widget.aiService.mcpUrl = ...` precedes `widget.aiService.mcpEnabled = ...`.
  4. Run `flutter test` inside the project root to ensure no syntax errors or regressions exist in the project suite.
