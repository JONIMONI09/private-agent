# Original User Request

## Initial Request — 2026-07-04T20:07:13Z

# Teamwork Project Prompt

Refactor and expand a private Flutter/Dart Android AI Agent app to include robust security execution modes, a tabbed settings UI with advanced configurations (local model toggles, thinking depth), an automated token/history compressor, and a modern 2026-standard animated planning UI. All code, skills, and .md files MUST remain strictly in English.

Working directory: d:\private-agent
Integrity mode: demo

## Verification Resources
- Automated: `flutter analyze` for static code analysis.
- Evaluation Agent: A dedicated agent step that reviews code changes against the Acceptance Criteria rubric below.
- Manual: User will perform end-to-end testing on a physical Android device.

## Requirements

### R1. Core Security and App Management
- Implement robust `Approve Mode` (manual confirmation per task) and `YOLO Mode` (autonomous).
- Implement fully functional and secure app permission management (allowing/denying the AI access to specific installed apps).

### R2. Settings Revamp (Tabbed UI)
- Redesign the Settings Screen using a Tab-Category system (e.g., General, UI, AI Models, Advanced).
- In the Advanced tab, include toggles for "Tool Calling Format (JSON/XML)", "Extreme Thinking Mode (depth slider with strict warning)", "Auto-Compress History", and a "MCP Connector (Beta)" UI for third-party tools.

### R3. Token Management and History Compressor
- Add a visible Token Counter at the bottom of the chat and a manual "Compress Context" button.
- Build logic to automatically pause tasks, summarize/shrink chat history safely when limits are reached, and resume execution.

### R4. Plan UI and Task Animations (2026 Standards)
- Revamp the `/plan` command UI to display as a vertical step-system with circular icons that animate downwards with green arrows/checkmarks upon completion.
- Ensure each step has an expandable accordion stream and a specific "Thinking" symbol during brainstorming.

## Acceptance Criteria

### Programmatic & Agent Evaluation (Pre-Release)
- [ ] `flutter analyze` returns zero errors on all modified `.dart` files.
- [ ] Evaluation Agent confirms `Approve Mode` blocks execution until confirmation, while `YOLO Mode` executes continuously.
- [ ] Evaluation Agent confirms the Settings UI is split into the 4 Tabs.
- [ ] Evaluation Agent verifies the `/plan` command renders a Vertical Step UI instead of raw text.

### User Manual Verification (Post-Release)
- [ ] User can successfully compile the app via `flutter build apk` / `flutter run`.
- [ ] Token Counter visibly updates in the Chat UI during conversation.
- [ ] History Compressor successfully reduces context length without crashing the AI session.

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



