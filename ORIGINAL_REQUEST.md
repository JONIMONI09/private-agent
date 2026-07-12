# Original User Request

## Initial Request — 2026-07-05T12:24:02Z

An automated team will audit, optimize, and verify the system prompts and core logic within the PrivateAgent Android project, utilizing a strict flat hierarchy (subagents cannot spawn subagents) to ensure efficiency and prevent infinite loops.

Working directory: d:\private-agent
Integrity mode: development

## Requirements

### R1. Logic & System Prompt Audit
The team must review all AI system prompts (e.g., in `ai_service.dart`, `task_executor.dart`) and core execution logic. 

### R2. Strict Subagent Policy (No Recursion)
The team must spawn individual worker agents for specific auditing tasks (e.g., one for `ai_service`, one for `task_executor`). Each worker agent MUST be strictly instructed that it is forbidden from spawning any further subagents (depth limit = 1).

### R3. Proactive Research
The team must actively utilize Codegraph and Web Search to understand the codebase and best practices for prompt engineering before making changes.

### R4. Comprehensive Reporting
The team must produce a final report artifact (`audit_report.md`) detailing exactly what was optimized, what was checked, and where potential logic errors might still exist.

## Acceptance Criteria

### Verification
- [ ] The `audit_report.md` artifact is created and clearly lists all files checked.
- [ ] The `audit_report.md` explicitly lists any theoretical logic flaws found during the audit.
- [ ] No subagent was allowed to spawn another subagent during execution.

## Follow-up — 2026-07-12T14:35:42Z

# Teamwork Project Prompt

An automated team will deeply audit the system for bugs, logic errors, and UI issues within the PrivateAgent Android project, utilizing extreme token efficiency. The team must work silently (no unnecessary chatter) and only produce necessary documentation of their findings.

Working directory: `d:\private-agent`
Integrity mode: development

## Requirements

### R1. Deep Bug Hunting
The team must proactively seek out hidden bugs, logic errors, missing security validations, and layout issues across the entire codebase.

### R2. Extreme Token Efficiency & Silence
The agents MUST NOT engage in conversational chatter. All internal thinking must be highly optimized and concise. The team must use the absolute minimum number of tokens necessary to complete the task.

### R3. Strict Subagent Policy
Keep the number of subagents to a bare minimum. Subagents must operate in a flat hierarchy (depth limit = 1) and are strictly forbidden from spawning further subagents to prevent infinite loops and token burning.

### R4. Documentation
The team must document all found bugs and theoretical logic flaws directly into a `bug_documentation.md` file.

## Acceptance Criteria

### Verification
- [ ] A `bug_documentation.md` artifact is created containing all found bugs.
- [ ] The total token usage of the operation is kept exceptionally low due to the strict enforcement of concise outputs and minimal chatter.
- [ ] No subagents spawned additional nested subagents.

## Follow-up — 2026-07-12T14:37:05Z

CRITICAL USER DIRECTIVE UPDATE: The user has explicitly stated: "also er darf mindestens nur insgesasmt 4 Agenten starten , die immer andere sachen prüfen!!!".

You MUST enforce a strict limit of EXACTLY OR MAXIMUM 4 subagents total across your entire audit. Each of these 4 agents must be assigned to check completely different areas (e.g., one for UI, one for Logic, one for Security, one for Performance). DO NOT SPAWN MORE THAN 4 AGENTS.

## Follow-up — 2026-07-12T14:56:59Z

# Teamwork Project Prompt

The goal is to perform a comprehensive audit of the PrivateAgent Flutter app, focusing on UI/UX rendering issues, Settings screen functionality, and AI integration problems, and to produce a detailed improvement plan artifact.

Working directory: d:\private-agent
Integrity mode: demo

## Requirements

### R1. UI/UX and Rendering Audit
- Analyze the Flutter UI files (especially `home_screen.dart`, `settings_screen.dart`, `plan_view.dart`, `message_bubble.dart`).
- Identify layout overflows, rendering errors, inconsistent theming, or poor UX flows.

### R2. Settings Functionality Audit
- Audit the newly refactored tabbed `settings_screen.dart` to ensure all toggles, sliders, and inputs correctly update the `AiService` state and persist.
- Identify any missing states or logical disconnects in the settings UI.

### R3. AI Integration & Token Efficiency
- Review how the AI handles token management, history compression, and XML/JSON tool calling.
- Identify any logic gaps or token-wasting patterns.

### R4. Improvement Plan Artifact
- Output a detailed Markdown artifact (`ui_improvement_plan.md`) documenting all found issues and the exact recommended code changes to fix them.
- Do NOT implement the fixes. Only document them. The primary agent will implement them later.

## Acceptance Criteria

### Automated / Objective Checks
- [ ] A file named `ui_improvement_plan.md` is generated in the workspace.
- [ ] The plan contains at least one section for UI Rendering, one for Settings Functionality, and one for AI Integration.
- [ ] The plan provides specific file paths and code snippets for each proposed fix.
- [ ] No actual `.dart` files are modified by the subagents (read-only audit).



