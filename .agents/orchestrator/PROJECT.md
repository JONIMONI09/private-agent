# Project: PrivateAgent Audit & Optimization
# Scope: Audit and optimize system prompts, core logic, and verify implementation

## Architecture
- **Frontend:** Flutter (Dart) utilizing Material 3.
- **Native Layer:** Kotlin (Android Accessibility Service, namespace `com.orailnoor.privateagent`).
- **AI Service:** OpenAI-compatible Chat Completion API (`deepseek-chat`, base URL config).
- **Core Automation:** Screen reading & multi-step execution.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Research & Audit Planning | Audit existing system prompts, parsing, and execution logic. Create detailed plans. | none | DONE |
| 2 | Prompt & Logic Optimization | Optimize prompt token-efficiency, fix JSON/XML mismatches, and improve error handling. | M1 | DONE |
| 3 | Verification & Reporting | Run tests, verify codebase health, and compile final audit report. | M2 | DONE |

## Interface Contracts
### AI Prompts and Formats
- Both XML and JSON formatting must be clean, robust, and correctly parsed.
- Core logic in `ai_service.dart` and `task_executor.dart` must handle malformed LLM outputs and network timeouts gracefully.
