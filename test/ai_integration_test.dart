import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_agent/services/ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiService Integration Tests', () {
    late AiService aiService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'api_key': 'test_key',
        'api_tool_calling_format': 'JSON',
        'api_thinking_depth': 0,
      });
      aiService = AiService();
      await aiService.init();
    });

    test('Tool calling format affects system prompt', () async {
      // Test JSON (default)
      String prompt = aiService.getSystemPrompt();
      expect(prompt, contains('raw JSON action object'));
      expect(prompt, isNot(contains('<action name=')));

      // Switch to XML
      aiService.toolCallingFormat = 'XML';
      prompt = aiService.getSystemPrompt();
      expect(prompt, contains('raw XML action'));
      expect(prompt, contains('<action name='));
    });

    test('Extreme Thinking Depth affects temperature and top_p', () async {
      // We need to intercept the http call to see the request body
      Map<String, dynamic>? lastRequestBody;
      aiService.httpClient = MockClient((request) async {
        lastRequestBody = jsonDecode(request.body);
        return http.Response(jsonEncode({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': '{"action": "done", "response": "OK"}'}
            }
          ]
        }), 200);
      });

      // Depth 0 (Default)
      await aiService.sendMessage('hello');
      expect(lastRequestBody?['temperature'], closeTo(0.7, 0.01));
      expect(lastRequestBody?['top_p'], isNull);

      // Depth 3
      aiService.extremeThinkingDepth = 3;
      await aiService.sendMessage('hello again');
      // temp = (0.7 - (3 * 0.1)).clamp(0.1, 0.7) = 0.4
      expect(lastRequestBody?['temperature'], closeTo(0.4, 0.01));
      // top_p = (1.0 - (3 * 0.05)).clamp(0.8, 1.0) = 0.85
      expect(lastRequestBody?['top_p'], closeTo(0.85, 0.01));
      // Check for thinking directive in content
      final messages = lastRequestBody?['messages'] as List;
      expect(messages.last['content'], contains('Think very carefully'));

      aiService.httpClient = http.Client();
    });

    test('History compression logic', () async {
      // Mock many messages to exceed threshold
      for (int i = 0; i < 20; i++) {
        aiService.conversationHistory.add({'role': 'user', 'content': 'message $i'});
        aiService.conversationHistory.add({'role': 'assistant', 'content': 'reply $i'});
      }

      aiService.httpClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': 'Summary of the long chat.'}
            }
          ]
        }), 200);
      });

      final result = await aiService.compressHistory();
      expect(result, isTrue);
      
      final history = aiService.conversationHistory;
      expect(history.length, 1);
      expect(history[0]['content'], contains('[Compressed Context]'));
      
      aiService.httpClient = http.Client();
    });

    test('Parsing XML and JSON actions', () {
      // Test JSON
      aiService.toolCallingFormat = 'JSON';
      const jsonResponse = '<thought>reasoning</thought>{"action": "open_app", "params": {"app_name": "Test"}, "response": "Opening"}';
      final actionJson = aiService.parseAction(jsonResponse);
      expect(actionJson?.action, 'open_app');
      expect(actionJson?.params['app_name'], 'Test');

      // Test XML
      aiService.toolCallingFormat = 'XML';
      const xmlResponse = '<thought>reasoning</thought><action name="open_app"><params><app_name>TestXML</app_name></params><response>Opening XML</response></action>';
      final actionXml = aiService.parseAction(xmlResponse);
      expect(actionXml?.action, 'open_app');
      expect(actionXml?.params['app_name'], 'TestXML');
      expect(actionXml?.response, 'Opening XML');
    });
  });
}
