# PrivateAgent - Learning Log

## Token Usage & Subagents
- **Do NOT spawn multiple subagents unnecessarily.** The user has tight quota limits on their API key. Subagents consume a massive amount of context tokens and easily trigger `429 RESOURCE_EXHAUSTED` errors.
- Prefer making edits manually and directly instead of delegating to subagents unless absolutely necessary for parallel isolation.

## UI / UX Findings
- Be careful with the `~` character in UI elements near numbers (e.g. `~512`), as users may misread it as a minus sign (`-512`). Use `ca. 512` or `approx. 512` instead.

## AI Formatting & Auto-Retries
- The `AiService.parseAction` strictly enforces a `<thought>` block. If missing, or if the JSON/XML is malformed, it throws a `FormatException`.
- `home_screen.dart` catches this and triggers an automatic retry prompt (up to 2 times), accompanied by an animated shake on a red Error Bubble in the UI. This reduces token waste by self-correcting instead of spawning new subagents to debug formatting.

## Testing & Mocking
- **HTTP Mocking:** Do NOT try to assign to `http.postHandler` directly on the `package:http/http.dart` library (it does not exist). Instead, always declare an `http.Client httpClient = http.Client();` inside your services (`AiService`, `TelegramService`) and use dependency injection or override the `httpClient` field with a `MockClient` from `package:http/testing.dart` during tests.

## Stateless Execution & Hallucinations
- **TaskExecutor:** Background AI execution loops must NEVER use the conversational `sendMessage()` method, as dumping raw UI accessibility trees directly into the main chat history causes context pollution and severe token inflation.
- Always use `sendStatelessMessage()` for background tasks.
- **Format Consistency:** Always ensure static system prompts within background logic respect the user's `toolCallingFormat` (JSON vs XML) instead of forcing a hardcoded format, as contradicting prompts will immediately cause the AI to hallucinate.

## Plan UI / Layout (2026-07-12)
- **NEVER use `Flexible` + `shrinkWrap: true` inside a Column with `Expanded` siblings.** The `Flexible` child will get zero height. Use `Expanded` with explicit `flex` values to divide space.
- **Separate state booleans for separate concerns.** Don't reuse `_isLoading` for plan execution, generation, AND normal chat loading. Use `_isPlanExecuting`, `_isPlanThinking`, etc.
- **Never hide action buttons completely during execution.** Show them as disabled with visual feedback (spinner, "Running..." label) so the user knows the system is working.
- When PlanView needs to coexist with a Messages ListView, use `Expanded(flex: 1)` for messages and `Expanded(flex: 2)` for the plan to ensure the plan gets 2/3 of screen height.

## Device UI & Screen Automation (2026-07-12)
- **FrameTracker IME Timeouts:** When automating Android screen actions (`click_text`, `type_text` on EditTexts), the system keyboard (IME) will pop up. If actions are performed too fast, the OS will struggle to animate the keyboard (`IME_INSETS_HIDE_ANIMATION`), leading to severe FrameTracker lag and NullPointerExceptions in system UI. Always add small artificial delays (e.g. `Future.delayed`) after actions that trigger the keyboard to let the UI settle before the next screenshot is taken.

## Dart Best Practices (2026-07-12)
- **Constants:** Always prefer const over inal for static configurations or string literals (e.g. const systemPrompt = '...';). This keeps the lutter analyze pipeline completely clean of prefer_const_declarations warnings.
