## 2026-07-05T12:26:31Z
You are a Worker agent.
Your working directory is d:\private-agent\.agents\worker_ai_service\

Task: Optimize system prompts and parsing in `lib/services/ai_service.dart` and add tests in `test/ai_service_test.dart`.

Requirements:
1. System Prompt Optimization in `ai_service.dart`:
   - Resolve the JSON system prompt contradiction: instruct the model to first output reasoning in `<thought>...</thought>` blocks, followed by the raw JSON action object, but clarify that the JSON is outside the thought tags and no markdown code fences (```json) should wrap it.
   - Align XML system prompts to be clear and concise.
   - Optimize prompts for token efficiency.
2. Robust Parsing in `parseAction`:
   - Refactor `parseAction` to first extract and strip the `<thought>...</thought>` block from the LLM output.
   - Extract the remaining text for XML or JSON parsing.
   - Make XML action name parsing flexible: allow single or double quotes, and arbitrary spaces around '=' (e.g. `name = 'click_element'`).
   - Make XML parameter parsing robust: support values that contain '<' or '>' characters (such as math inequalities or HTML blocks). Do not let inner brackets break parsing.
   - Tolerantly match parameter tags with attributes (e.g. `<text hint="app">WhatsApp</text>` should successfully match parameter name 'text' and value 'WhatsApp').
3. Unit Test Expansion in `test/ai_service_test.dart`:
   - Add test cases verifying:
     - JSON parser successfully parses actions when curly braces `{}` are present inside the `<thought>` block.
     - XML parser successfully parses action names with single quotes and spaces (e.g. `<action name = 'click_element'>`).
     - XML parser successfully parses parameters containing `<` or `>` in their values.
     - XML parser successfully parses parameters with attributes (e.g. `<message type="text">Hello</message>`).
4. Run tests and make sure all of them compile and pass. Run `flutter test test/ai_service_test.dart`.

CRITICAL INSTRUCTIONS:
- FLAT HIERARCHY: You are FORBIDDEN from spawning any further subagents. Do not call invoke_subagent.
- MANDATORY INTEGRITY WARNING: DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
- Write your progress in `d:\private-agent\.agents\worker_ai_service\progress.md` and handoff report in `d:\private-agent\.agents\worker_ai_service\handoff.md`.
- Report your results back via message to parent conversation ID: 3889460b-ee6b-42d7-86ff-4e0057bac98a.
