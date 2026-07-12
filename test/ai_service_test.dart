import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_agent/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AiService format validation tests', () {
    late AiService aiService;

    setUp(() {
      aiService = AiService();
    });

    test('Valid JSON action with thought block parses successfully', () {
      aiService.toolCallingFormat = 'JSON';
      const validResponse = '''
<thought>
I need to send an SMS to Alice.
</thought>
{
  "action": "send_sms",
  "params": {
    "to": "Alice",
    "message": "Hello"
  }
}
''';
      final action = aiService.parseAction(validResponse);
      expect(action, isNotNull);
      expect(action!.action, 'send_sms');
      expect(action.params['to'], 'Alice');
    });

    test('JSON action missing thought block throws FormatException', () {
      aiService.toolCallingFormat = 'JSON';
      const invalidResponse = '''
{
  "action": "send_sms",
  "params": {
    "to": "Alice"
  }
}
''';
      expect(
        () => aiService.parseAction(invalidResponse),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Missing <thought> block'),
        )),
      );
    });

    test('Plain text conversation returns null (not an action)', () {
      aiService.toolCallingFormat = 'JSON';
      const textResponse = 'Hello there, how can I help you today?';
      
      final action = aiService.parseAction(textResponse);
      expect(action, isNull);
    });

    test('Valid XML action with thought block parses successfully', () {
      aiService.toolCallingFormat = 'XML';
      const validXml = '''
<thought>
I am going to use an XML tool format.
</thought>
<action name="execute_task">
  <params>
    <task>Clean up the house</task>
  </params>
  <response>Task started</response>
</action>
''';
      final action = aiService.parseAction(validXml);
      expect(action, isNotNull);
      expect(action!.action, 'execute_task');
      expect(action.params['task'], 'Clean up the house');
      expect(action.response, 'Task started');
    });

    test('XML action missing thought block throws FormatException', () {
      aiService.toolCallingFormat = 'XML';
      const invalidXml = '''
<action name="execute_task">
  <params></params>
</action>
''';
      expect(
        () => aiService.parseAction(invalidXml),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Missing <thought> block'),
        )),
      );
    });

    test('JSON parser parses action when curly braces are in thought block', () {
      aiService.toolCallingFormat = 'JSON';
      const responseWithBracesInThought = '''
<thought>
I need to evaluate this expression: {a: 1, b: 2}.
Then I will call the action.
</thought>
{
  "action": "open_app",
  "params": {
    "app_name": "Settings"
  }
}
''';
      final action = aiService.parseAction(responseWithBracesInThought);
      expect(action, isNotNull);
      expect(action!.action, 'open_app');
      expect(action.params['app_name'], 'Settings');
    });

    test('XML parser parses action name with single quotes and spaces', () {
      aiService.toolCallingFormat = 'XML';
      const xmlResponse = '''
<thought>
Reasoning here...
</thought>
<action name = 'click_element'>
  <params>
    <element_id>btn_submit</element_id>
  </params>
  <response>Clicking button</response>
</action>
''';
      final action = aiService.parseAction(xmlResponse);
      expect(action, isNotNull);
      expect(action!.action, 'click_element');
      expect(action.params['element_id'], 'btn_submit');
      expect(action.response, 'Clicking button');
    });

    test('XML parser parses parameters with < or > in values', () {
      aiService.toolCallingFormat = 'XML';
      const xmlResponse = '''
<thought>
Evaluating values...
</thought>
<action name="execute_task">
  <params>
    <expression>5 < 10 && 3 > 1</expression>
    <html><div>Hello</div></html>
  </params>
</action>
''';
      final action = aiService.parseAction(xmlResponse);
      expect(action, isNotNull);
      expect(action!.action, 'execute_task');
      expect(action.params['expression'], '5 < 10 && 3 > 1');
      expect(action.params['html'], '<div>Hello</div>');
    });

    test('XML parser parses parameters with attributes', () {
      aiService.toolCallingFormat = 'XML';
      const xmlResponse = '''
<thought>
Sending message...
</thought>
<action name="send_sms">
  <params>
    <message type="text" encoding="utf-8">Hello world</message>
    <recipient label="work">123456</recipient>
  </params>
</action>
''';
      final action = aiService.parseAction(xmlResponse);
      expect(action, isNotNull);
      expect(action!.action, 'send_sms');
      expect(action.params['message'], 'Hello world');
      expect(action.params['recipient'], '123456');
    });
  });
}
