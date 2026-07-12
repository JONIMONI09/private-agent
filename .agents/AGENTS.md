# PrivateAgent – Project Rules

## Language
- All code comments must be in English.
- Commit messages must be in English.
- Agent communication must be in German (as per default global rules, unless talking about code or artifact generation where the user prefers English).
- All generated documentation, Markdown (.md) files, and skills must be strictly in English.

## Code Quality
- Always read files before editing.
- Never use hardcoded colors – always use Theme/ColorScheme.
- Handle errors with Exceptions, not by returning descriptive error strings.
- Set timeouts on all HTTP requests.
- Use a proper Logger instead of print().
- Verify `mounted` state before calling `setState()`.

## Security
- API keys must NEVER be hardcoded or written to source control.
- Validate user inputs before passing them to native shells.
- Telegram Bot: Always validate the Chat ID against a whitelist.

## Architecture
- Register new services as Singletons via Dependency Injection once DI is introduced.
- MethodChannel Name: `com.privateagent/accessibility`
- Always register new actions in the `availableActions` list in `agent_action.dart`.
- **Background Tasks:** Any internal AI reasoning loop (like `TaskExecutor`) MUST use `AiService.sendStatelessMessage()` rather than `sendMessage()` to avoid polluting the main chat UI with massive screen dumps.
- **Formats:** Ensure all system prompts natively support both strict JSON and XML tool calling, with a mandatory `<thought>` block enforcement in both branches.

## Testing
- Write at least one unit test for every new feature.
- Add regression tests when resolving bugs.

## Workflow
1. Use CodeGraph (`codegraph explore`) to understand codebase symbols.
2. Read the project `SKILL.md` and check `LEARNING.md` before starting tasks.
3. Always document bugs and findings in `LEARNING.md`.
