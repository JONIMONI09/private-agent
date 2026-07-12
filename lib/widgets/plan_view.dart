import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/plan_step.dart';

/// A premium vertical stepper-style widget that displays an AI-generated
/// execution plan with animated step indicators, expandable details,
/// and action buttons.
class PlanView extends StatefulWidget {
  final List<PlanStep> steps;
  final bool isThinking;
  final VoidCallback? onProceed;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const PlanView({
    super.key,
    required this.steps,
    this.isThinking = false,
    this.onProceed,
    this.onEdit,
    this.onCancel,
  });

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> with TickerProviderStateMixin {
  late AnimationController _thinkingPulseController;
  late AnimationController _spinController;
  final Set<int> _expandedSteps = {};

  @override
  void initState() {
    super.initState();

    // Pulsing animation for the "Thinking deeply..." indicator.
    _thinkingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Continuous spin for the active-step icon.
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _thinkingPulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Execution status header
        if (widget.isThinking)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.3),
                  colorScheme.primaryContainer.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Executing plan...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        // Step list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: widget.steps.length,
            itemBuilder: (context, index) {
              return _buildStepItem(context, index, colorScheme);
            },
          ),
        ),

        // Action buttons (shown even during execution, but disabled)
        if (widget.steps.isNotEmpty)
          _buildActionButtons(colorScheme),
      ],
    );
  }

  // Removed legacy thinking indicator methods

  // ---------------------------------------------------------------------------
  // Step item (timeline row)
  // ---------------------------------------------------------------------------

  Widget _buildStepItem(
      BuildContext context, int index, ColorScheme colorScheme) {
    final step = widget.steps[index];
    final isLast = index == widget.steps.length - 1;
    final isExpanded = _expandedSteps.contains(index);
    final hasExpandableContent =
        step.substeps.isNotEmpty || (step.result != null && step.result!.isNotEmpty);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Timeline column (icon + line) ---
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  _buildStepIcon(step.status, colorScheme),
                  if (!isLast)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 2.5,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: step.status == PlanStepStatus.done
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // --- Content column ---
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: step.status == PlanStepStatus.pending ? 0.65 : 1.0,
                child: GestureDetector(
                  onTap: hasExpandableContent
                      ? () {
                          if (!mounted) return;
                          setState(() {
                            if (isExpanded) {
                              _expandedSteps.remove(index);
                            } else {
                              _expandedSteps.add(index);
                            }
                          });
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _cardColor(step.status, colorScheme).withValues(alpha: 0.8),
                          _cardColor(step.status, colorScheme).withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: step.status == PlanStepStatus.active 
                            ? colorScheme.primary.withValues(alpha: 0.6)
                            : _borderColor(step.status, colorScheme).withValues(alpha: 0.3),
                        width: step.status == PlanStepStatus.active ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        if (step.status == PlanStepStatus.active)
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                step.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (hasExpandableContent)
                              AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 250),
                                child: Icon(
                                  Icons.expand_more,
                                  size: 20,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        // Description
                        if (step.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            step.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        // Expandable content
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              SizeTransition(
                            sizeFactor: animation,
                            alignment: Alignment.topCenter,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          ),
                          child: isExpanded
                              ? _buildExpandedContent(step, colorScheme)
                              : const SizedBox.shrink(
                                  key: ValueKey('collapsed')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed unused skeleton step

  // ---------------------------------------------------------------------------
  // Step icon
  // ---------------------------------------------------------------------------

  Widget _buildStepIcon(PlanStepStatus status, ColorScheme colorScheme) {
    const double size = 32;

    switch (status) {
      case PlanStepStatus.pending:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
          ),
          child: Icon(Icons.schedule, size: 16, color: colorScheme.outline),
        );

      case PlanStepStatus.active:
        return AnimatedBuilder(
          animation: _spinController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _spinController.value * 2 * math.pi,
              child: child,
            );
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer,
              border: Border.all(color: colorScheme.primary, width: 2),
            ),
            child: Icon(Icons.sync, size: 16, color: colorScheme.primary),
          ),
        );

      case PlanStepStatus.done:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
          child: Icon(Icons.check, size: 18, color: colorScheme.onPrimary),
        );

      case PlanStepStatus.failed:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.error,
          ),
          child: Icon(Icons.close, size: 18, color: colorScheme.onError),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Expanded content (substeps + result)
  // ---------------------------------------------------------------------------

  Widget _buildExpandedContent(PlanStep step, ColorScheme colorScheme) {
    return Padding(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.substeps.isNotEmpty) ...[
            Text(
              'Substeps',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            ...step.substeps.map(
              (sub) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sub,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (step.result != null && step.result!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Result',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.result!,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action buttons
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons(ColorScheme colorScheme) {
    final isExecuting = widget.isThinking;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Cancel (always available)
          if (widget.onCancel != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Cancel'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (widget.onCancel != null && widget.onEdit != null)
            const SizedBox(width: 10),
          // Edit (disabled during execution)
          if (widget.onEdit != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isExecuting ? null : widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Edit'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isExecuting
                      ? colorScheme.onSurface.withValues(alpha: 0.3)
                      : colorScheme.onSurface,
                  side: BorderSide(
                    color: isExecuting
                        ? colorScheme.outline.withValues(alpha: 0.3)
                        : colorScheme.outline,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (widget.onEdit != null && widget.onProceed != null)
            const SizedBox(width: 10),
          // Proceed (disabled during execution)
          if (widget.onProceed != null || isExecuting)
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: isExecuting ? null : widget.onProceed,
                icon: isExecuting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(isExecuting ? 'Running...' : 'Proceed'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isExecuting
                      ? colorScheme.primary.withValues(alpha: 0.5)
                      : colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Color helpers
  // ---------------------------------------------------------------------------

  Color _cardColor(PlanStepStatus status, ColorScheme cs) {
    switch (status) {
      case PlanStepStatus.active:
        return cs.primaryContainer.withValues(alpha: 0.15);
      case PlanStepStatus.done:
        return cs.primary.withValues(alpha: 0.06);
      case PlanStepStatus.failed:
        return cs.error.withValues(alpha: 0.08);
      case PlanStepStatus.pending:
        return cs.surfaceContainerLow;
    }
  }

  Color _borderColor(PlanStepStatus status, ColorScheme cs) {
    switch (status) {
      case PlanStepStatus.active:
        return cs.primary.withValues(alpha: 0.5);
      case PlanStepStatus.done:
        return cs.primary.withValues(alpha: 0.2);
      case PlanStepStatus.failed:
        return cs.error.withValues(alpha: 0.4);
      case PlanStepStatus.pending:
        return cs.outlineVariant;
    }
  }
}
