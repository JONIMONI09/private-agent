# Handoff Report: PrivateAgent Prompt & Core Logic Audit

## 1. Observation

### 1.1 System Prompt Contradiction and Schema Inconsistencies
* **Observation 1.1.1 (JSON Prompt Contradiction)**:
  In `lib/services/ai_service.dart` (lines 100-108):
  ```dart
  CRITICAL INSTRUCTION: When you need to interact with the device, you MUST respond with ONLY a JSON object (no markdown formatting, no code fences, no trailing text) in this EXACT format:
  
  <thought>
  [Phase 1: Analyze user intent]
  ...
  [Phase 2: Evaluate tools]
  ...
  </thought>
  {"action": "action_name", "params": {"key": "value"}, "response": "Optional message to user"}
  ```
  And rule 2 (line 130) states:
  ```dart
  2. ALWAYS provide the <thought> block first.
  ```
* **Observation 1.1.2 (XML/JSON Schema Split)**:
  In `lib/services/ai_service.dart` (lines 63-68):
  ```xml
  <action name="action_name">
    <params>
      <key>value</key>
    </params>
    <response>What you say to the user</response>
  </action>
  ```
  But in `lib/services/task_executor.dart` (lines 46-52):
  ```xml
  <action name="action_name">
    <params>
      <key>value</key>
    </params>
    <reasoning>why you chose this action</reasoning>
    <is_complete>false</is_complete>
  </action>
  ```

### 1.2 Parsing Vulnerabilities
* **Observation 1.2.1 (Greedy JSON Extraction)**:
  In `lib/services/ai_service.dart` (line 571) and `lib/services/task_executor.dart` (line 199):
  ```dart
  final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
  ```
* **Observation 1.2.2 (Rigid XML Attribute Matching)**:
  In `lib/services/ai_service.dart` (line 547) and `lib/services/task_executor.dart` (line 173):
  ```dart
  final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(jsonStr);
  ```
* **Observation 1.2.3 (Fragile Parameter Key-Value Matching)**:
  In `lib/services/ai_service.dart` (line 558) and `lib/services/task_executor.dart` (line 184):
  ```dart
  final paramEntries = RegExp(r'<([^>]+)>([^<]*)</\1>').allMatches(paramsContent);
  ```

### 1.3 Error Handling Violations (Descriptive String Returns)
* **Observation 1.3.1 (App Launcher)**:
  In `lib/services/app_launcher_service.dart` (lines 95-98):
  ```dart
    } catch (e) {
      developer.log('Error opening ${target.name}: $e', error: e, name: 'AppLauncherService');
      return 'Error opening ${target.name}: $e';
    }
  ```
* **Observation 1.3.2 (Communication Service)**:
  In `lib/services/communication_service.dart` (lines 14-16):
  ```dart
      if (number == null) {
        return 'Could not find contact "$contactName". Try searching contacts first.';
      }
  ```
  And lines 29-32:
  ```dart
      return 'Cannot make calls on this device.';
    } catch (e) {
      return 'Error making call: $e';
    }
  ```
* **Observation 1.3.3 (Task Executor Accessibility Error)**:
  In `lib/services/task_executor.dart` (lines 97-100):
  ```dart
    final isRunning = await _screenService.isServiceRunning();
    if (!isRunning) {
      return 'Accessibility service is not enabled. Go to Settings → Accessibility → PrivateAgent Screen Control and enable it.';
    }
  ```

---

## 2. Logic Chain

1. **Prompt Contradictions (from Obs 1.1.1)**: Instructing a model to return "ONLY a JSON object" while requiring a prepended XML `<thought>` tag creates logical dissonance for instruction-following models, increasing formatting error rates.
2. **Schema Inconsistencies (from Obs 1.1.2)**: Having different XML/JSON shapes between `AiService` and `TaskExecutor` (e.g. `<response>` vs `<reasoning>`) increases model completion confusion and parsing bugs.
3. **JSON Regex Crash (from Obs 1.2.1)**: Because the thought block is not stripped *before* the JSON regex search, and because `*` is greedy, any occurrence of `{` and `}` inside the thought block will cause the regex to match from the thought block's `{` to the end of the JSON block, generating a string containing non-JSON text that throws a `FormatException` in `jsonDecode`.
4. **XML Regex Failures (from Obs 1.2.2 & 1.2.3)**: 
   - A rigid `name="..."` match fails if models output single quotes or space around `=`.
   - The param parser `[^<]*` prevents characters like `<` or `>` from being in parameter values, meaning messages containing HTML/XML entities, inequalities, or inner brackets fail to parse.
   - Tag names containing spaces or helper attributes fail backreferences (`\1`), dropping the parameter completely.
5. **Coding Convention Violations (from Obs 1.3.1, 1.3.2, 1.3.3)**: The project rule strictly states: *"Handle errors with Exceptions, not by returning descriptive error strings."* Returning error messages as successful function outputs violates this rule, makes error debugging harder, and results in downstream components (like `ActionHandler`) wrapping failures in `success: true` status results.

---

## 3. Caveats

* Only local Dart code files and tests inside the repository were audited.
* The behavior of external MCP tools was not tested directly, though the code handling MCP calls was audited.
* It is assumed that the `xml` parsing package is not currently imported in the project; therefore, regex-based solutions or introducing a standard parser like `package:xml` is recommended.

---

## 4. Conclusion

The PrivateAgent project contains critical parsing flaws that can cause runtime application crashes or failures when LLMs write details in their thought blocks or use natural symbols in parameters. Furthermore, the error handling framework is inconsistent with the project's coding conventions, relying heavily on swallowed exceptions and returned error strings. 

### Recommendations and Recommended Optimizations

#### Recommendation 1: Fix Prompt Contradictions
Refactor the system prompts to clearly distinguish boundaries. E.g. for JSON format:
> "Output your reasoning inside `<thought>...</thought>` tags. After closing the thought block, output your next action as a raw JSON object matching the schema below. Do not wrap the JSON in markdown code blocks."

#### Recommendation 2: Robust Regex JSON/XML Parsing (Code Example)
Modify `parseAction` in `ai_service.dart` and the parsing logic in `task_executor.dart` to first strip out the `<thought>` block, then parse.
```dart
AgentAction? parseAction(String response) {
  String textToParse = response.trim();
  String thoughtProcess = '';
  
  // Extract and strip thought block first
  final thoughtMatch = RegExp(r'<thought>([\s\S]*?)</thought>').firstMatch(textToParse);
  if (thoughtMatch != null) {
    thoughtProcess = thoughtMatch.group(1)!.trim();
    textToParse = textToParse.replaceFirst(thoughtMatch.group(0)!, '').trim();
    developer.log('AI Thought: $thoughtProcess', name: 'AiService');
  } else {
    // If it looks like an action attempt but lacks thought block, throw
    if (textToParse.contains('<action') || textToParse.contains('"action"')) {
      throw const FormatException('Missing <thought> block.');
    }
  }

  // Parse remaining clean action block
  if (_toolCallingFormat == 'XML') {
    // Match name flexibly with single/double quotes and optional spaces
    final nameMatch = RegExp(r'name\s*=\s*["\']([^"\']+)["\']').firstMatch(textToParse);
    if (nameMatch == null) return null;
    
    final actionName = nameMatch.group(1)!;
    final responseMatch = RegExp(r'<response>([\s\S]*?)</response>').firstMatch(textToParse);
    final actionResponse = responseMatch?.group(1) ?? '';
    
    final params = <String, dynamic>{};
    final paramsMatch = RegExp(r'<params>([\s\S]*?)</params>').firstMatch(textToParse);
    if (paramsMatch != null) {
      final paramsContent = paramsMatch.group(1)!;
      // Allow any content inside the param tag using [\s\S]*?
      final paramEntries = RegExp(r'<([^>\s]+)(?:\s+[^>]*)?>([\s\S]*?)</\1>').allMatches(paramsContent);
      for (final m in paramEntries) {
        params[m.group(1)!] = m.group(2);
      }
    }
    return AgentAction(action: actionName, params: params, response: actionResponse);
  } else {
    // JSON matching on remaining clean text
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(textToParse);
    if (jsonMatch == null) return null;
    
    final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    return AgentAction.fromJson(json);
  }
}
```

#### Recommendation 3: Standardize Error Handling with Exceptions (Code Example)
Refactor service methods to throw typed exceptions.
1. Define custom exceptions:
```dart
class AccessibilityServiceException implements Exception {
  final String message;
  AccessibilityServiceException(this.message);
  @override
  String toString() => 'AccessibilityServiceException: $message';
}

class ContactNotFoundException implements Exception {
  final String message;
  ContactNotFoundException(this.message);
  @override
  String toString() => 'ContactNotFoundException: $message';
}
```
2. Throw exceptions in services:
```dart
// In lib/services/communication_service.dart
if (number == null) {
  throw ContactNotFoundException('Could not find contact "$contactName".');
}
```
3. Catch and translate in `ActionHandler.execute`:
```dart
try {
  // Execute action ...
} on ContactNotFoundException catch (e) {
  return AgentActionResult(actionType: action.action, success: false, details: e.message);
} on AccessibilityServiceException catch (e) {
  return AgentActionResult(actionType: action.action, success: false, details: e.message);
} catch (e) {
  return AgentActionResult(actionType: action.action, success: false, details: 'Unexpected error: $e');
}
```

---

## 5. Verification Method

### 5.1 Verification Commands
To verify the existing test suite passes:
```powershell
flutter test test/ai_service_test.dart
flutter test test/security_test.dart
```

### 5.2 Verification Files to Inspect
* Inspect `test/ai_service_test.dart` and `test/security_test.dart` to check current parser coverage.

### 5.3 Invalidation Conditions
If a standard XML/JSON schema parser package is introduced (e.g. `xml` or `json_serializable`), the custom regex-based parser checks mentioned above are invalidated.
