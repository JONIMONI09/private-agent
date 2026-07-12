import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_action.dart';
import 'logger_service.dart';

class AiService {
  static const String _defaultBaseUrl = 'https://api.deepseek.com';
  static const String _defaultModel = 'deepseek-chat';

  String? _apiKey;
  String _baseUrl = _defaultBaseUrl;
  String _model = _defaultModel;
  int _maxSteps = 15;
  bool _disableMaxSteps = false;
  bool _yoloMode = false;
  final List<Map<String, String>> _conversationHistory = [];

  String _toolCallingFormat = 'JSON';
  int _extremeThinkingDepth = 0;
  bool _autoCompressHistory = true;
  bool _mcpEnabled = false;
  String _mcpUrl = 'http://10.0.2.2:3000';
  String _telegramWhitelist = '';
  
  http.Client httpClient = http.Client();
  List<Map<String, dynamic>> _mcpTools = [];

  String getAvailableToolsString() {
    return '''
- open_app: {"app_name": "..."}
- make_call: {"contact_name": "..."} OR {"phone_number": "..."}
- send_sms: {"contact_name": "...", "message": "..."}
- search_contact: {"query": "..."}
- set_alarm: {"hour": 7, "minute": 30, "label": "..."}
- set_volume: {"level": 50}
- set_brightness: {"level": 50}
- read_screen: {}
- press_back: {}
- execute_task: {"goal": "..."}
${_mcpTools.isNotEmpty ? _mcpTools.map((t) => "- mcp_tool: ${t['name']}").join('\n') : ''}
    ''';
  }

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
1. ALWAYS provide <thought>...</thought> first, even for normal conversation.
2. XML action must be outside the thought block.
3. No markdown code fences.
4. For normal conversation, reply with plain text naturally AFTER the thought block.
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
1. ALWAYS provide <thought>...</thought> first, even for normal conversation.
2. The JSON action must be outside the thought block.
3. NEVER wrap JSON in ```json ... ``` code fences.
4. For normal conversation, reply with plain text naturally AFTER the thought block.
''';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key');
    _baseUrl = prefs.getString('api_base_url') ?? _defaultBaseUrl;
    _model = prefs.getString('api_model') ?? _defaultModel;
    _maxSteps = prefs.getInt('api_max_steps') ?? 15;
    _disableMaxSteps = prefs.getBool('api_disable_max_steps') ?? false;
    _yoloMode = prefs.getBool('api_yolo_mode') ?? false;
    _toolCallingFormat = prefs.getString('api_tool_calling_format') ?? 'JSON';
    _extremeThinkingDepth = prefs.getInt('api_thinking_depth') ?? 0;
    _autoCompressHistory = prefs.getBool('api_auto_compress_history') ?? true;
    _mcpEnabled = prefs.getBool('api_mcp_enabled') ?? false;
    _mcpUrl = prefs.getString('api_mcp_url') ?? 'http://10.0.2.2:3000';
    _telegramWhitelist = prefs.getString('telegram_chat_id_whitelist') ?? '';
    
    if (_mcpEnabled) {
      await _fetchMcpTools();
    }
  }

  Future<void> _fetchMcpTools() async {
    try {
      final url = _mcpUrl.endsWith('/') ? '${_mcpUrl}tools' : '$_mcpUrl/tools';
      final response = await httpClient.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('tools')) {
          _mcpTools = List<Map<String, dynamic>>.from(data['tools']);
        } else if (data is List) {
          _mcpTools = List<Map<String, dynamic>>.from(data);
        }
        Log.i('Loaded ${_mcpTools.length} MCP tools');
      }
    } catch (e) {
      Log.e('Failed to fetch MCP tools: $e');
    }
  }

  Future<void> saveSettings({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clean up the API key in case the user pasted "Bearer sk-..."
    String cleanApiKey = apiKey.trim();
    if (cleanApiKey.toLowerCase().startsWith('bearer ')) {
      cleanApiKey = cleanApiKey.substring(7).trim();
    }
    
    _apiKey = cleanApiKey;
    await prefs.setString('api_key', cleanApiKey);

    if (baseUrl != null && baseUrl.isNotEmpty) {
      _baseUrl = baseUrl;
      await prefs.setString('api_base_url', baseUrl);
    }
    if (model != null && model.isNotEmpty) {
      _model = model;
      await prefs.setString('api_model', model);
    }
  }

  Future<void> saveMaxSteps(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    _maxSteps = steps;
    await prefs.setInt('api_max_steps', steps);
  }

  Future<void> saveDisableMaxSteps(bool disable) async {
    final prefs = await SharedPreferences.getInstance();
    _disableMaxSteps = disable;
    await prefs.setBool('api_disable_max_steps', disable);
  }

  Future<void> saveYoloMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _yoloMode = value;
    await prefs.setBool('api_yolo_mode', value);
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  String get baseUrl => _baseUrl;
  String get model => _model;
  String get apiKey => _apiKey ?? '';
  int get maxSteps => _disableMaxSteps ? 999 : _maxSteps;
  int get rawMaxSteps => _maxSteps; // For the slider UI
  bool get disableMaxSteps => _disableMaxSteps;
  bool get yoloMode => _yoloMode;

  String get toolCallingFormat => _toolCallingFormat;
  set toolCallingFormat(String value) {
    _toolCallingFormat = value;
    _saveStringSetting('api_tool_calling_format', value);
  }

  int get extremeThinkingDepth => _extremeThinkingDepth;
  set extremeThinkingDepth(int value) {
    _extremeThinkingDepth = value;
    _saveIntSetting('api_thinking_depth', value);
  }

  bool get autoCompressHistory => _autoCompressHistory;
  set autoCompressHistory(bool value) {
    _autoCompressHistory = value;
    _saveBoolSetting('api_auto_compress_history', value);
  }

  bool get mcpEnabled => _mcpEnabled;
  set mcpEnabled(bool value) {
    _mcpEnabled = value;
    if (!value) {
      _mcpTools.clear();
    } else {
      _fetchMcpTools(); // Load them immediately when enabled
    }
    _saveBoolSetting('api_mcp_enabled', value);
  }

  String get mcpUrl => _mcpUrl;
  set mcpUrl(String value) {
    _mcpUrl = value;
    _saveStringSetting('api_mcp_url', value);
  }

  String get telegramWhitelist => _telegramWhitelist;
  set telegramWhitelist(String value) {
    _telegramWhitelist = value;
    _saveStringSetting('telegram_chat_id_whitelist', value);
  }

  void _saveStringSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  void _saveIntSetting(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  void _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  String getSystemPrompt() => _getSystemPrompt();
  List<Map<String, String>> get conversationHistory => _conversationHistory;

  /// Estimate the total token count of the current conversation history.
  /// Uses a rough heuristic of ~4 characters per token.
  int get estimatedTokenCount {
    int totalChars = _getSystemPrompt().length;
    for (final msg in _conversationHistory) {
      totalChars += (msg['content'] ?? '').length;
    }
    return (totalChars / 4).ceil();
  }

  /// Maximum token threshold before auto-compression triggers.
  static const int _autoCompressThreshold = 6000;

  /// Compress the conversation history by asking the LLM to summarize it.
  /// Replaces the full history with a single summary message to reduce tokens.
  Future<bool> compressHistory() async {
    if (_conversationHistory.length < 4) return false;

    try {
      // Build a summarization prompt from the current history
      final historyText = _conversationHistory
          .map((m) => '${m['role']}: ${m['content']}')
          .join('\n');

      final summaryPrompt =
          'Summarize the following conversation in 2-3 concise sentences, '
          'preserving key facts, user preferences, and any ongoing tasks:\n\n'
          '$historyText';

      final messages = [
        {'role': 'system', 'content': 'You are a helpful summarizer. Respond with ONLY the summary, no extra text.'},
        {'role': 'user', 'content': summaryPrompt},
      ];

      String requestUrl = _baseUrl;
      if (!requestUrl.endsWith('/chat/completions')) {
        if (requestUrl.endsWith('/')) {
          requestUrl = '${requestUrl}chat/completions';
        } else {
          requestUrl = '$requestUrl/chat/completions';
        }
      }

      final bodyPayload = jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.3,
        'max_tokens': 512,
      });
      Log.i('HTTP POST [compressHistory]: $requestUrl');
      Log.d('Payload: $bodyPayload');
      final response = await httpClient.post(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: bodyPayload,
      ).timeout(const Duration(seconds: 180), onTimeout: () {
        throw Exception('API request timed out after 180 seconds.');
      });
      Log.i('HTTP Response [compressHistory]: ${response.statusCode}');
      Log.d('Body: ${response.body}');

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return false;
      final summary = choices[0]['message']['content'] as String;

      // Replace the entire history with the compressed summary
      _conversationHistory.clear();
      _conversationHistory.add({
        'role': 'system',
        'content': '[Compressed Context] $summary',
      });

      Log.i('History compressed. New token estimate: $estimatedTokenCount');
      return true;
    } catch (e) {
      Log.e('Failed to compress history: $e', e);
      return false;
    }
  }

  /// Send a stateless message to the AI without polluting the conversation history.
  /// Used by background processes like TaskExecutor.
  Future<String> sendStatelessMessage(String systemPrompt, String userMessage) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API Key is not configured. Please go to Settings.');
    }

    try {
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userMessage},
      ];

      double temperature = 0.3; // Lower temperature for stateless execution tasks
      String requestUrl = _baseUrl;
      if (!requestUrl.endsWith('/chat/completions')) {
        if (requestUrl.endsWith('/')) {
          requestUrl = '${requestUrl}chat/completions';
        } else {
          requestUrl = '$requestUrl/chat/completions';
        }
      }

      final bodyPayload = jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': 1024,
      });
      Log.i('HTTP POST [sendStatelessMessage]: $requestUrl');
      Log.d('Payload: $bodyPayload');
      final response = await httpClient.post(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://github.com/orailnoor/private-agent',
          'X-Title': 'PrivateAgent',
        },
        body: bodyPayload,
      ).timeout(const Duration(seconds: 180), onTimeout: () {
        throw Exception('API request timed out after 180 seconds.');
      });
      Log.i('HTTP Response [sendStatelessMessage]: ${response.statusCode}');
      Log.d('Body: ${response.body}');

      if (response.statusCode != 200) {
        String errorMessage = response.body;
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['error']?['message'] ?? response.body;
        } catch (_) {}
        throw Exception('API error (${response.statusCode}): $errorMessage');
      }

      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('API returned invalid JSON format: missing choices array.');
      }
      return choices[0]['message']['content'] as String;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  /// Send a message to the AI and get a response.
  Future<String> sendMessage(String message) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API Key is not configured. Please go to Settings.');
    }

    // Auto-compress if enabled and token count exceeds threshold
    if (_autoCompressHistory && estimatedTokenCount > _autoCompressThreshold) {
      Log.w('Token count ($estimatedTokenCount) exceeds threshold ($_autoCompressThreshold). Auto-compressing...');
      await compressHistory();
    }

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
      final List<Map<String, String>> messages = [];
      String finalSystemPrompt = systemPrompt;
      int historyStartIdx = 0;

      // Extract the history summary if it sits at index 0 and merge to comply with single system message rule
      if (_conversationHistory.isNotEmpty && _conversationHistory[0]['role'] == 'system') {
        finalSystemPrompt = '$systemPrompt\n\n### CONVERSATION SUMMARY SO FAR\n${_conversationHistory[0]['content']}';
        historyStartIdx = 1;
      }

      messages.add({'role': 'system', 'content': finalSystemPrompt});
      for (int i = historyStartIdx; i < _conversationHistory.length; i++) {
        messages.add(_conversationHistory[i]);
      }

      // Integrate Extreme Thinking Depth
      double temperature = 0.7;
      if (_extremeThinkingDepth > 0) {
        // Lower temperature for higher depth to reduce hallucinations
        temperature = (0.7 - (_extremeThinkingDepth * 0.1)).clamp(0.1, 0.7);
        
        // Add a "Think harder" directive to the last message if depth is high
        if (_extremeThinkingDepth >= 3) {
          final lastMsg = messages.last;
          if (lastMsg['role'] == 'user') {
            lastMsg['content'] = '${lastMsg['content']}\n\n(Think very carefully about this step-by-step before responding)';
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

      final bodyPayload = jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': 1024,
        if (_extremeThinkingDepth > 0) 'top_p': (1.0 - (_extremeThinkingDepth * 0.05)).clamp(0.8, 1.0),
      });
      Log.i('HTTP POST [sendMessage]: $requestUrl');
      Log.d('Payload: $bodyPayload');
      final response = await httpClient.post(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://github.com/orailnoor/private-agent',
          'X-Title': 'PrivateAgent',
        },
        body: bodyPayload,
      ).timeout(const Duration(seconds: 180), onTimeout: () {
        throw Exception('API request timed out after 180 seconds.');
      });
      Log.i('HTTP Response [sendMessage]: ${response.statusCode}');
      Log.d('Body: ${response.body}');

      if (response.statusCode != 200) {
        String errorMessage = response.body;
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['error']?['message'] ?? response.body;
        } catch (_) {}
        throw Exception('API error (${response.statusCode}): $errorMessage');
      }

      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('API returned invalid JSON format: missing choices array.');
      }
      final assistantMessage = choices[0]['message']['content'] as String;

      _conversationHistory.add({
        'role': 'assistant',
        'content': assistantMessage,
      });

      return assistantMessage;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  /// Parse the AI response to check if it's an action or plain text.
  /// Throws FormatException if it looks like an action attempt but formatting is invalid.
  AgentAction? parseAction(String response) {
    String remainingText = response.trim();
    
    // Extract thought block if present
    String thoughtProcess = '';
    final thoughtMatch = RegExp(r'<thought>([\s\S]*?)</thought>').firstMatch(remainingText);
    if (thoughtMatch != null) {
      thoughtProcess = thoughtMatch.group(1)!.trim();
      Log.d('AI Thought: $thoughtProcess');
      // Strip the thought block from the remaining text
      remainingText = remainingText.replaceFirst(thoughtMatch.group(0)!, '').trim();
    }

    // Check if it's an action attempt
    bool isActionAttempt = false;
    if (_toolCallingFormat == 'XML' && remainingText.contains('<action')) {
      isActionAttempt = true;
    } else if (_toolCallingFormat == 'JSON' && (remainingText.contains('"action"') || remainingText.contains("'action'"))) {
      isActionAttempt = true;
    }

    if (thoughtMatch == null && isActionAttempt) {
      throw const FormatException('Missing <thought> block. You MUST output your reasoning in a <thought>...</thought> block BEFORE calling a tool.');
    }

    if (!isActionAttempt) return null; // Normal conversation

    try {
      if (_toolCallingFormat == 'XML') {
        final nameMatch = RegExp(r'''name\s*=\s*(["'])(.*?)\1''').firstMatch(remainingText);
        if (nameMatch == null) throw const FormatException('Missing action name in XML. Expected <action name="...">');
        
        final actionName = nameMatch.group(2)!;
        final responseMatch = RegExp(r'<response>([\s\S]*?)</response>').firstMatch(remainingText);
        final actionResponse = responseMatch?.group(1) ?? '';
        
        final params = <String, dynamic>{};
        final paramsMatch = RegExp(r'<params>([\s\S]*?)</params>').firstMatch(remainingText);
        if (paramsMatch != null) {
          final paramsContent = paramsMatch.group(1)!;
          final paramEntries = RegExp(r'<([a-zA-Z_][a-zA-Z0-9_\-]*)(?:\s[^>]*)?>([\s\S]*?)</\1>').allMatches(paramsContent);
          for (final m in paramEntries) {
            params[m.group(1)!] = m.group(2);
          }
        }
        
        return AgentAction(
          action: actionName,
          params: params,
          response: actionResponse,
        );
      }
      
      int startIdx = remainingText.indexOf('{');
      int endIdx = remainingText.lastIndexOf('}');
      if (startIdx == -1 || endIdx == -1 || startIdx > endIdx) {
        throw const FormatException('No JSON object found.');
      }
      
      final jsonStr = remainingText.substring(startIdx, endIdx + 1);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (!json.containsKey('action')) throw const FormatException('Missing "action" key in JSON.');
      return AgentAction.fromJson(json);
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Invalid format syntax: $e');
    }
  }

  /// Fetches available models from the provider's /models endpoint
  Future<List<String>> fetchAvailableModels(String baseUrl, String apiKey) async {
    try {
      String cleanBaseUrl = baseUrl;
      // Many providers host it at /models, but some require the base URL without /chat/completions logic
      if (cleanBaseUrl.endsWith('/chat/completions')) {
        cleanBaseUrl = cleanBaseUrl.replaceAll('/chat/completions', '');
      }

      final response = await http.get(
        Uri.parse('$cleanBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final modelsList = data['data'] as List;
          return modelsList.map((m) => m['id'].toString()).toList();
        } else if (data is List) {
          return data.map((m) => m['id'].toString()).toList();
        }
      }
      return [];
    } catch (e) {
      Log.e('Error fetching models: $e', e);
      return [];
    }
  }
}
