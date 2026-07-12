# Plan: PrivateAgent UI/UX, Settings, and AI Audit

## Objectives
Perform a comprehensive, read-only audit of the PrivateAgent Flutter application to identify layout, rendering, state persistence, and token-wasting AI issues. Document recommendations in `ui_improvement_plan.md`.

## Decomposition & Subagents
To perform this audit efficiently under the strict limit of 4 subagents maximum and a flat hierarchy (depth = 1):
1. **Explorer 1: UI/UX & Rendering Auditor**
   - **Scope**: `lib/screens/home_screen.dart`, `lib/screens/settings_screen.dart`, `lib/widgets/plan_view.dart`, and `lib/widgets/message_bubble.dart`.
   - **Focus**: UI layout overflows, rendering errors, theme integration, usability issues, and responsiveness.
2. **Explorer 2: Settings & State Auditor**
   - **Scope**: `lib/screens/settings_screen.dart`, `lib/services/ai_service.dart`, and state storage/persistence.
   - **Focus**: Toggles, sliders, input fields, state binding, error handling on save/load, and any missing configurations or synchronization discrepancies.
3. **Explorer 3: AI Integration & Token Efficiency Auditor**
   - **Scope**: `lib/services/ai_service.dart`, `lib/services/task_executor.dart`, and message models.
   - **Focus**: Token budgeting, history compression/pruning, tool calling structures (XML/JSON), redundant system prompt payload, and efficiency optimizations.

## Execution Timeline
1. **Phase 1: Setup & Initialization** (Done)
   - Initialize workspace, plan, progress, and original request records.
2. **Phase 2: Dispatch Exploration Agents**
   - Spawn Explorer 1, 2, and 3 concurrently.
   - Set safety and liveness timers for monitoring.
3. **Phase 3: Monitor & Gather Handoffs**
   - Read reports and check for completed audits.
   - Handle any stuck/deadlocked agents if necessary.
4. **Phase 4: Synthesis & Reporting**
   - Analyze and reconcile all findings into a unified consensus.
   - Write the comprehensive `d:\private-agent\ui_improvement_plan.md` with exact recommended code changes.
   - Write handoff.md and report to parent in German.
