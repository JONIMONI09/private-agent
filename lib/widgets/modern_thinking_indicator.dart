import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class ModernAuroraThinkingIndicator extends StatefulWidget {
  const ModernAuroraThinkingIndicator({super.key});

  @override
  State<ModernAuroraThinkingIndicator> createState() => _ModernAuroraThinkingIndicatorState();
}

class _ModernAuroraThinkingIndicatorState extends State<ModernAuroraThinkingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  final List<String> _phases = [
    'Analyzing user intent...',
    'Evaluating available tools...',
    'Synthesizing execution plan...',
    'Resolving dependencies...',
    'Finalizing agent workflow...'
  ];
  int _currentPhaseIndex = 0;
  late Stream<int> _phaseStream;
  late final StreamSubscription<int> _phaseSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _phaseStream = Stream.periodic(const Duration(milliseconds: 2500), (count) => count);
    _phaseSubscription = _phaseStream.listen((count) {
      if (mounted) {
        setState(() {
          _currentPhaseIndex = (count + 1) % _phases.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _phaseSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            children: [
              // Aurora Orb
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow rotating
                    Transform.rotate(
                      angle: _controller.value * 2 * math.pi,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.0),
                              colorScheme.primary.withValues(alpha: 0.6),
                              colorScheme.secondary.withValues(alpha: 0.6),
                              colorScheme.primary.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.4, 0.8, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Inner core to create the ring effect
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Inner pulsing dot
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.4 + 0.6 * math.sin(_controller.value * 2 * math.pi)),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Shimmering Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [
                            colorScheme.onSurface,
                            colorScheme.primary,
                            colorScheme.onSurface,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                          transform: GradientRotation(_controller.value * 2 * math.pi),
                        ).createShader(bounds);
                      },
                      child: Text(
                        _phases[_currentPhaseIndex],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: colorScheme.surface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Multi-step agent logic active',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
