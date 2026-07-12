# AI Integration & Token Efficiency Audit Report

This report presents the findings of the AI Integration, Token Efficiency, and Tool Calling Robustness audit for the PrivateAgent project. 

---

## 1. File and Line Index of AI Payload & History Management

The core logic handling token budgets, message history compression, and XML/JSON tool calling resides in the following files and lines:

1. **`lib/services/ai_service.dart`**
   - **Lines 45-124**: System prompt generation for XML and JSON calling formats (`_getSystemPrompt()`).
   - **Lines 280-288**: Token budget heuristic calculations (`estimatedTokenCount`).
   - **Lines 290-291**: Hardcoded compression trigger threshold (`_autoCompressThreshold = 6000`).
   - **Lines 295-362**: History compression implementation through LLM summarization (`compressHistory()`).
   - **Lines 433-439**: Auto-compression check during standard messages execution.
   - **Lines 441-450**: Message trimming logic maintaining a sliding window of the last 20 messages.
   - **Lines 453-457**: API request payload compilation.
   - **Lines 534-601**: Response action parsing and `<thought>` tag extraction (`parseAction()`).

2. **`lib/services/task_executor.dart`**
   - **Lines 46-97**: Task-specific system prompt definition (`_getTaskSystemPrompt()`).
   - **Lines 126-143**: User prompt composition and previous action logging in the task execution loop.
   - **Lines 149-150**: Stateless execution call to the AI model (`sendStatelessMessage()`).
   - **Lines 159-220**: XML/JSON tool call extraction and parsing of reasoning, completed status, and parameter maps.

3. **`lib/services/screen_automation_service.dart`** (Related payload provider)
   - **Lines 47-99**: Screen accessibility layout representation sent to the AI (`getScreenDescription()`).

---

## 2. Logic Gaps, Inefficiencies, and Token-Wasting Patterns

### Gap A: History Truncation Erases the Compressed Summary
* **Location**: `ai_service.dart` (Lines 448-450)
* **Description**: When the length of the `_conversationHistory` exceeds 20, the service truncates older messages using `_conversationHistory.removeRange(0, length - 20)`. Because the history summary from `compressHistory()` is stored at index 0, it is deleted as soon as the rolling window rolls forward.
* **Token/Robustness Impact**: High. Discarding the summary makes history compression completely useless after a few additional turns, forcing the AI to lose all memories of user preferences or past instructions.

### Gap B: API Protocol Violation via Multiple System Messages
* **Location**: `ai_service.dart` (Lines 453-457)
* **Description**: The compression routine appends the summary as `{'role': 'system', 'content': '[Compressed Context] ...'}`. When compiled, the final payload contains multiple consecutive `system` role messages.
* **Token/Robustness Impact**: High. Many LLM endpoints (e.g. Claude, Gemini, or strict API gateways) do not allow multiple `system` messages or system turns after user/assistant messages, resulting in HTTP 400 bad requests.

### Gap C: Stateless Task Execution Lacks Past Timeline Context
* **Location**: `task_executor.dart` (Lines 126-143)
* **Description**: To prevent polluting the user's primary chat view, the background `TaskExecutor` uses `sendStatelessMessage()`. However, it only passes the immediate last step's outcome (`results.last`). The LLM has zero knowledge of steps 1 to N-2.
* **Token/Robustness Impact**: Critical. Without sequence history, the model cannot detect stuck states and frequently loops (e.g. clicking the same non-functional element repeatedly), wasting thousands of context tokens in futile retries.

### Gap D: Task Prompt Format Mismatch (JSON Examples in XML System Prompt)
* **Location**: `task_executor.dart` (Lines 46-97)
* **Description**: If the calling format is XML, the system prompt specifies the XML formatting layout, but the "Available actions" list still displays JSON representations (e.g., `- click_text: {"text": "exact text to click"}`).
* **Token/Robustness Impact**: High. This mix of formats confuses the model, causing it to emit invalid mixed payloads (e.g. JSON strings nested in XML parameters), triggering parsing crashes and model retry overhead.

### Gap E: Insecure XML Action Matcher and Dangerous `is_complete` Default
* **Location**: `task_executor.dart` (Lines 162-201)
* **Description**:
  1. The regex used to parse XML actions `RegExp('name\\s*=\\s*["\']([^"\']+)["\']')` is unanchored. It matches any text containing `name="..."`, potentially capturing strings inside thoughts or reasoning comments.
  2. Extracted parameter values are never trimmed (`m.group(2)!`), preserving leading/trailing spaces and newlines.
  3. `isComplete` defaults to `true` under XML parsing. If the model omits `<is_complete>` or the regex fails to catch it, the executor assumes completion and halts prematurely.
* **Token/Robustness Impact**: High. Causes execution failures or truncated tasks, requiring users to trigger brand new automation loops.

### Gap F: Hidden Tools in General System Prompt
* **Location**: `ai_service.dart` (Lines 45-124)
* **Description**: `ActionHandler` supports `set_timer`, `send_email`, `open_url`, `read_notifications`, and `run_adb_command`. However, none of these are defined in the general `_getSystemPrompt()`. The AI can never use them in normal chat.

### Gap G: Heavy Screen Dump Layout Payload
* **Location**: `screen_automation_service.dart` (Lines 47-99)
* **Description**: The screen dump includes full Android package prefixes (e.g., `android.widget.TextView`) and outputs both bounds coordinates and center point coordinates.
* **Token/Robustness Impact**: High. A typical screen contains dozens of nodes. Package prefixes and redundant coordinates bloat the screen description by ~500–1000 characters per step, costing thousands of tokens over a multi-step task.

---

## 3. Recommended Code Replacements

### Optimization 1: Unified System Prompt & Rolling History Summary Protection
* **Target File**: `lib/services/ai_service.dart`

To protect the history summary from deletion and resolve the multiple system messages error without breaking tests:
1. Dynamically merge the summary (index 0 system message) into the main `system` prompt in the API request payload.
2. Skip the summary when trimming the history list.
3. Expose missing tools (`set_timer`, `send_email`, `open_url`, `read_notifications`, `run_adb_command`) in `_getSystemPrompt()`.

#### Replacement for `_getSystemPrompt()` in `lib/services/ai_service.dart` (Lines 45-124):
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

#### Replacement for `sendMessage()` inside `lib/services/ai_service.dart` (Lines 441-499):
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

---

### Optimization 2: Dynamic Action Descriptions and Full Action History
* **Target File**: `lib/services/task_executor.dart`

To improve tool calling formatting correctness and provide full execution context:
1. Dynamically render the available actions list inside `_getTaskSystemPrompt()` based on the calling format.
2. Compile and insert a lightweight sequence log of all previous actions into the prompt.
3. Fix XML regex safety, parameter whitespace trimming, and the `isComplete` default logic.

#### Replacement for `_getTaskSystemPrompt()` in `lib/services/task_executor.dart` (Lines 46-97):
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

#### Replacement for prompt building and parsing in `executeTask` in `lib/services/task_executor.dart` (Lines 126-220):
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

---

### Optimization 3: Strip Java Class Prefixes and Redundant Bounds in Screen Dumps
* **Target File**: `lib/services/screen_automation_service.dart`

To save context tokens and simplify coordinates parsing for the model, replace `getScreenDescription()` to strip verbose package structures and output only the center coordinates.

#### Replacement for `getScreenDescription()` in `lib/services/screen_automation_service.dart` (Lines 47-99):
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

## 4. Projected Token and Financial Savings

For a typical automation task executing over **10 steps** with a screen dump density of **40 elements**:

* **Class Name Simplification**: Reduces each node description line by ~18 characters. 
  * 18 chars * 40 nodes = 720 characters saved per screen dump.
  * Over 10 steps, this is **7,200 characters (~1,800 tokens)** saved per task run.
* **Bounds Redundancy Removal**: Eliminates `bounds:[left,top,right,bottom]` (~25 characters per node).
  * 25 chars * 40 nodes = 1,000 characters saved per screen dump.
  * Over 10 steps, this is **10,000 characters (~2,500 tokens)** saved per task run.
* **Loop Prevention**: Keeping history prevents the AI from falling into clicking loops (which consume 100% of the step limit, i.e., 15 steps of full dumps). Reducing loop steps by 5 steps saves **~35,000 tokens** per unsuccessful run.

**Total Token Savings**: ~4,300 tokens per successful run, and up to **40,000+ tokens** saved per failed/looping run.
