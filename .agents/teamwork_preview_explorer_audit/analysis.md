# PrivateAgent Audit: System Prompts and Core Logic Analysis

## Executive Summary
This report presents a comprehensive audit of the system prompts, core parsing logic, and error handling in the PrivateAgent Android project. The audit reveals several structural prompt conflicts, critical parsing vulnerabilities (such as regex failures on JSON/XML structures), and direct violations of the project's error handling convention ("Handle errors with Exceptions, not by returning descriptive error strings").

---

## 1. System Prompts Audit

### 1.1 Token-Efficiency and Redundancy
* **Redundant Headers & Instructions**: Prompts in both `ai_service.dart` and `task_executor.dart` repeat lists of rules and instructions that could be consolidated. For example, `ai_service.dart` includes several lines of constraints in multiple places.
* **Prompt Overlap**: Both services define their own versions of tool descriptions and formats. `AiService` provides a format schema, and `TaskExecutor` provides a slightly different one, leading to split context logic.

### 1.2 Prompt Formatting Mismatches and Contradictions
* **JSON Prompt Contradiction**: In `ai_service.dart` (lines 100-108), the prompt states:
  > "...you MUST respond with ONLY a JSON object (no markdown formatting, no code fences, no trailing text) in this EXACT format..."
  
  Immediately followed by:
  ```xml
  <thought>
  [Phase 1: Analyze user intent]
  ...
  [Phase 2: Evaluate tools]
  ...
  </thought>
  {"action": "action_name", "params": {"key": "value"}, "response": "Optional message to user"}
  ```
  And Rule 2 states: "ALWAYS provide the `<thought>` block first."
  This is a logical contradiction: the model is instructed to output *only* a JSON object, but is simultaneously forced to prepend an XML-style `<thought>...</thought>` block. This causes prompt-compliance stress and makes parsing highly fragile.
* **Schema Inconsistencies between `AiService` and `TaskExecutor`**:
  * In `AiService` (XML format), the action response element is defined as:
    ```xml
    <action name="action_name">
      <params><key>value</key></params>
      <response>What you say to the user</response>
    </action>
    ```
  * In `TaskExecutor` (XML format), the structure is defined as:
    ```xml
    <action name="action_name">
      <params><key>value</key></params>
      <reasoning>why you chose this action</reasoning>
      <is_complete>false</is_complete>
    </action>
    ```
  The fields `<response>` vs `<reasoning>`/`<is_complete>` are inconsistent, causing potential confusion if a model transitions between normal conversation mode and task execution.

---

## 2. Core Logic and Parsing Vulnerabilities

Both `AiService` and `TaskExecutor` parse LLM outputs using regular expressions instead of formal parsers. This leads to critical edge cases where parsing will fail.

### 2.1 JSON Greedy Matching Bug (Crash Vulnerability)
In both `ai_service.dart` (line 571) and `task_executor.dart` (line 199), the JSON content is extracted using:
```dart
final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
```
Because the thought block (`<thought>...</thought>`) precedes the JSON block, if the LLM includes curly braces `{}` inside its thought block to explain or reason about a JSON action, the regex matches greedily:
* Start of match: The first `{` found inside `<thought>`
* End of match: The last `}` found at the end of the JSON action.

**Resulting Crash**: The extracted string will contain the thought text, closing `</thought>` tags, and the JSON. Passing this string to `jsonDecode` will throw a `FormatException` and abort execution.

**Example LLM Output that fails**:
```
<thought>
I will call the tool with {"app_name": "WhatsApp"}.
</thought>
{
  "action": "open_app",
  "params": {"app_name": "WhatsApp"}
}
```

### 2.2 XML Parsing Edge Cases
1. **Rigid Attribute Matcher**:
   In both files, the action name is parsed via:
   ```dart
   final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(jsonStr);
   ```
   If the LLM uses single quotes (`name='click_text'`) or includes whitespace around the equals sign (`name = "click_text"`), the regex fails, and a `FormatException` is thrown.
2. **Inner Bracket Failure for Parameters**:
   In both files, parameters are parsed with:
   ```dart
   final paramEntries = RegExp(r'<([^>]+)>([^<]*)</\1>').allMatches(paramsContent);
   ```
   * The group `([^<]*)` explicitly forbids `<` characters. If a parameter (such as `message` in `send_sms` or `query` in `search_contact`) contains a `<` character (e.g. `<message>I like <cats></message>`), the parser fails to capture the parameter.
   * If a parameter uses XML attributes (e.g., `<text type="string">Hello</text>`), group 1 is `text type="string"`, but the closing tag is `</text>`. The regex backreference `\1` expects `</text type="string">`, causing the match to fail.

---

## 3. Error Handling Audit

The project guidelines state: **"Handle errors with Exceptions, not by returning descriptive error strings."**
The current implementation frequently violates this rule by catching exceptions internally and returning descriptive strings, which are then treated as successful results by callers.

### 3.1 Violations in Services
* **`AppLauncherService`** (`lib/services/app_launcher_service.dart`):
  * Lines 92-98:
    ```dart
    try {
      await InstalledApps.startApp(target.packageName);
      return 'Opened ${target.name}';
    } catch (e) {
      developer.log('Error opening ${target.name}: $e', error: e, name: 'AppLauncherService');
      return 'Error opening ${target.name}: $e'; // Violation
    }
    ```
  * Lines 102-114 (`openUrl`):
    ```dart
    try {
      ...
    } catch (e) {
      return 'Error opening URL: $e'; // Violation
    }
    ```
* **`CommunicationService`** (`lib/services/communication_service.dart`):
  * All methods (`makeCall`, `sendSms`, `sendEmail`) return hardcoded descriptive error strings instead of throwing exceptions. E.g.:
    * `return 'Could not find contact "$contactName". Try searching contacts first.';`
    * `return 'No phone number provided.';`
    * `return 'Cannot make calls on this device.';`
    * `return 'Error making call: $e';`
* **`AlarmService`** (`lib/services/alarm_service.dart`):
  * `setAlarm` and `setTimer` return strings like `'Error setting alarm: $e'` on catch, swallowing the exception.
* **`TaskExecutor`** (`lib/services/task_executor.dart`):
  * Lines 97-100:
    ```dart
    final isRunning = await _screenService.isServiceRunning();
    if (!isRunning) {
      return 'Accessibility service is not enabled. Go to Settings → ...'; // Violation
    }
    ```
    This should throw an `AccessibilityServiceException`.

### 3.2 Swallowing Exceptions in `ActionHandler`
In `ActionHandler.execute` (`lib/services/action_handler.dart`), errors caught during execution (e.g. from HTTP timeouts or network failures in MCP tool execution) are swallowed and returned as successful actions:
```dart
        case 'mcp_tool_call':
          ...
          try {
            ...
            if (response.statusCode == 200) {
              result = ...
            } else {
              result = 'MCP Error (${response.statusCode}): ${response.body}'; // Swallowed as success: true
            }
          } catch (e) {
            result = 'Failed to execute MCP tool: $e'; // Swallowed as success: true
          }
```
This causes the calling task runner to believe the step succeeded, when it actually failed.

---

## 4. Test Files Audit

### 4.1 `test/ai_service_test.dart`
* **Coverage**: Basic happy path tests for XML and JSON formats, verifying that actions are extracted and that missing `<thought>` blocks trigger format exceptions.
* **Missing Test Cases**:
  * No test cases for curly braces inside thought blocks.
  * No test cases for spaces or single quotes in XML attributes.
  * No test cases for parameter values containing `<` or `>`.
  * No test cases for nested XML structures or empty parameter lists.

### 4.2 `test/security_test.dart`
* Covers blocklists, app blocking, YOLO mode, and Telegram Whitelist verification.
* Verifies `TaskExecutor` throws `AppBlockedException` when a blocked app is running.
* **Missing Test Cases**: Does not verify parsing robustness, nor does it test behaviors when dependent services return error strings rather than throwing exceptions.
