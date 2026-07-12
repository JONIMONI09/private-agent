# Project Plan: PrivateAgent Audit & Optimization

## Mission
Audit, optimize, and verify system prompts and core logic (e.g. in `lib/services/ai_service.dart`, `lib/services/task_executor.dart`) within the PrivateAgent Android project. Ensure token efficiency, robust XML/JSON parsing, clean error handling, and test compliance.

---

## Milestones

### Milestone 1: Exploration & System Design (Audit Phase)
- **Objective:** Spawn a read-only Explorer (`teamwork_preview_explorer`) to analyze:
  - System prompts in `lib/services/ai_service.dart` and `lib/services/task_executor.dart`.
  - Core execution flow, XML/JSON parsing edge cases, and token-efficiency issues.
  - Error handling (handling with Exceptions vs descriptive strings).
- **Subagent constraint:** Instruct explorer that it is FORBIDDEN to spawn further subagents.
- **Verification:** An audit analysis file summarizing found issues and optimization strategies.

### Milestone 2: Optimization (Implementation Phase)
- **Objective:** Spawn a Worker (`teamwork_preview_worker`) to:
  - Streamline and optimize system prompts for token efficiency and clarity.
  - Fix any prompt format (JSON vs XML) mismatches.
  - Robustify XML/JSON parsing of AI responses in `AiService` and `TaskExecutor`.
  - Improve error handling to follow the rule "Handle errors with Exceptions, not by returning descriptive error strings" where appropriate.
  - Ensure all existing and new unit tests compile and pass.
- **Subagent constraint:** Instruct worker that it is FORBIDDEN to spawn further subagents.
- **Verification:** `flutter analyze` runs cleanly and all tests pass.

### Milestone 3: Review and Final Reporting
- **Objective:** Spawn a Reviewer (`teamwork_preview_reviewer`) to:
  - Review the optimized code for correctness, security, and prompt engineering best practices.
  - Verify that the changes address the issues listed in Milestone 1 without breaking any existing features.
  - Run all tests to verify correctness.
- **Subagent constraint:** Instruct reviewer that it is FORBIDDEN to spawn further subagents.
- **Verification:** Reviewer's handoff report confirming clean builds and passing tests.
- **Final Output:** Generate `audit_report.md` at project root documenting checked files, optimized items, and any theoretical logic flaws found.
- **Completion Signal:** Report completion to the Sentinel.

---

## Detailed Execution Strategy
- For each step, we spawn the respective subagent, monitor via progress files, and verify results.
- We will explicitly check that no subagent spawns further subagents.
- All code/documentation is written in English. Communication with Sentinel is in German.
