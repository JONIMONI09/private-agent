import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/agent_action.dart';
import '../models/chat_message.dart';
import '../models/plan_step.dart';
import '../services/ai_service.dart';
import '../services/action_handler.dart';
import '../services/voice_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/plan_view.dart';
import '../widgets/modern_thinking_indicator.dart';
import '../services/telegram_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiService _aiService = AiService();
  final ActionHandler _actionHandler = ActionHandler();
  final VoiceService _voiceService = VoiceService();
  late final TelegramService _telegramService;

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _isCompressing = false;
  List<PlanStep>? _currentPlan;
  bool _isPlanThinking = false;
  bool _isPlanExecuting = false;
  bool _showCommandSuggestions = false;

  @override
  void initState() {
    super.initState();
    _telegramService = TelegramService(_actionHandler, _aiService);
    _initServices();
  }

  Future<void> _initServices() async {
    await _aiService.init();
    await _voiceService.init();
    await _telegramService.init();

    // Check Shizuku availability
    await _actionHandler.shizuku.checkAvailability();

    // Check accessibility service
    final accessibilityEnabled =
        await _actionHandler.screenAutomation.isServiceRunning();

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content:
              'Hi! I\'m PrivateAgent. I can help you control your phone.\n\n'
              '${accessibilityEnabled ? '✅ Screen Control is ACTIVE — I can read and control other apps!' : '⚠️ Screen Control is OFF — Go to Settings to enable it for multi-step tasks.'}\n\n'
              'Try saying:\n'
              '• "Open YouTube"\n'
              '• "Call Mom"\n'
              '• "Set volume to 50%"\n'
              '• "What\'s on my screen?"\n\n'
              'Type or tap the mic to get started!',
        ));
      });
    }
  }

  Future<bool> _showActionApprovalDialog(Map<String, dynamic> actionData) async {
    final actionName = actionData['action'] as String? ?? 'Unknown';
    final params = actionData['params'] as Map<String, dynamic>? ?? {};
    final reasoning = actionData['reasoning'] as String? ?? '';

    if (!mounted) return false;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            'Confirm Action',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Action:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                Text(actionName),
                const SizedBox(height: 8),
                if (reasoning.isNotEmpty) ...[
                  Text(
                    'Reasoning:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  Text(reasoning),
                  const SizedBox(height: 8),
                ],
                if (params.isNotEmpty) ...[
                  Text(
                    'Parameters:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  ...params.entries.map((e) => Text('• ${e.key}: ${e.value}')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
    return approved ?? false;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Intercept /plan command (only if not already executing a plan)
    if (text.trim().toLowerCase().startsWith('/plan')) {
      final goal = text.trim().substring(5).trim();
      if (goal.isEmpty) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Usage: /plan <goal>\n\nExample: /plan Open YouTube and search for Flutter tutorials',
          ));
        });
        _textController.clear();
        _scrollToBottom();
        return;
      }
      _textController.clear();
      await _generatePlan(goal);
      return;
    }

    final userMessage = ChatMessage(role: 'user', content: text.trim());
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _showCommandSuggestions = false;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      String currentPrompt = text.trim();
      int retries = 0;
      bool success = false;

      while (!success && retries < 3) {
        // Get AI response
        final response = await _aiService.sendMessage(currentPrompt);

        try {
          // Check if it's an action (throws FormatException if malformed)
          final action = _aiService.parseAction(response);
          success = true; // Parsing succeeded

          if (action != null) {
            // Execute the action (pass aiService for multi-step tasks)
            final result = await _actionHandler.execute(
              action,
              aiService: _aiService,
              onProgress: (msg) {
                if (mounted) {
                  setState(() {
                    _messages.add(ChatMessage(role: 'assistant', content: '⏳ $msg'));
                  });
                  _scrollToBottom();
                }
              },
              onConfirmAction: _showActionApprovalDialog,
            );

            if (mounted) {
              setState(() {
                _messages.add(ChatMessage(
                  role: 'assistant',
                  content: action.response.isNotEmpty
                      ? action.response
                      : result.details ?? 'Done.',
                  actionResult: result,
                ));
              });
            }

            // Speak the response
            _voiceService.speak(action.response.isNotEmpty
                ? action.response
                : result.details ?? 'Done.');
          } else {
            // Plain text response
            if (mounted) {
              setState(() {
                _messages.add(ChatMessage(role: 'assistant', content: response));
              });
            }
            _voiceService.speak(response);
          }
        } on FormatException catch (e) {
          retries++;
          // Add error bubble to UI
          if (mounted) {
            setState(() {
              _messages.add(ChatMessage(
                role: 'system',
                content: 'Parsing Error: ${e.message}\nAuto-retrying ($retries/3)...',
                isError: true,
              ));
            });
          }
          _scrollToBottom();
          
          if (retries >= 3) {
            if (mounted) {
              setState(() {
                _messages.add(ChatMessage(
                  role: 'system',
                  content: 'Failed to correct formatting after multiple attempts. Please try rephrasing your request.',
                  isError: true,
                ));
              });
            }
            break;
          }
          
          // Formulate retry prompt (sent to AI, but not added to UI as user message)
          currentPrompt = 'SYSTEM ERROR: Your previous response format was invalid. Reason: ${e.message}\n\nPlease output the required <thought> block followed by the correct action format.\n\nAvailable Tools:\n${_aiService.getAvailableToolsString()}';
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Error: ${e.toString().replaceFirst('Exception: ', '')}',
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);

    await _voiceService.startListening(
      onResult: (text) {
        _sendMessage(text);
      },
      onDone: () {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _voiceService.dispose();
    _telegramService.dispose();
    super.dispose();
  }

  /// Generate a step-by-step plan for the given goal using the LLM.
  Future<void> _generatePlan(String goal) async {
    setState(() {
      _isLoading = true;
      _isPlanThinking = true;
      _currentPlan = [];
      _messages.add(ChatMessage(
        role: 'user',
        content: '/plan $goal',
      ));
    });
    _scrollToBottom();

    try {
      final planPrompt =
          'I need you to create a step-by-step execution plan for the following goal. '
          'Respond with ONLY a JSON array of objects, each with "title" and "description" fields. '
          'Keep it to 3-7 steps. No markdown, no code fences.\n\n'
          'Goal: $goal\n\n'
          'Example response format:\n'
          '[{"title": "Step 1", "description": "Do something"}, '
          '{"title": "Step 2", "description": "Do something else"}]';

      const systemPrompt = 'You are a precise JSON outputting assistant.';
      final response = await _aiService.sendStatelessMessage(systemPrompt, planPrompt);

      // Parse the plan steps from JSON response
      final List<PlanStep> steps = [];
      try {
        String dataStr = response.trim();
        // Remove markdown code fences if present
        if (dataStr.startsWith('```')) {
          dataStr = dataStr.replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: true), '');
          dataStr = dataStr.replaceAll(RegExp(r'\n?```$', multiLine: true), '');
          dataStr = dataStr.trim();
        }

        // Extract JSON array from response
        final jsonMatch = RegExp(r'\[\s*\{[\s\S]*\}\s*\]').firstMatch(dataStr);
        if (jsonMatch != null) {
          final List<dynamic> parsed =
              List<dynamic>.from(jsonDecode(jsonMatch.group(0)!) as List);
          for (final item in parsed) {
            steps.add(PlanStep(
              title: item['title'] as String? ?? 'Step',
              description: item['description'] as String? ?? '',
            ));
          }
        }
      } catch (e) {
        developer.log('Plan parsing error: $e', name: 'HomeScreen');
      }

      // If no steps were parsed, use the goal as a single step fallback
      if (steps.isEmpty) {
        steps.add(PlanStep(
          title: 'Execute Task',
          description: goal,
        ));
      }

      if (mounted) {
        setState(() {
          _currentPlan = steps;
          _isPlanThinking = false;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlanThinking = false;
          _isLoading = false;
          _currentPlan = null;
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Failed to generate plan: ${e.toString().replaceFirst('Exception: ', '')}',
          ));
        });
        _scrollToBottom();
      }
    }
  }

  /// Execute the currently displayed plan.
  void _executePlan() async {
    if (_currentPlan == null || _currentPlan!.isEmpty) return;

    final plan = _currentPlan!;
    final goal = plan
        .map((s) => '${s.title}: ${s.description}')
        .join('. ');

    setState(() {
      _isLoading = true;
      _isPlanExecuting = true;
    });

    try {
      // Mark the first step as active
      setState(() {
        if (plan.isNotEmpty) {
          plan[0] = plan[0].copyWith(status: PlanStepStatus.active);
        }
      });

      // Directly execute the task via ActionHandler with execute_task action
      final action = AgentAction(
        action: 'execute_task',
        params: {'goal': goal},
        response: 'Executing plan...',
      );

      final result = await _actionHandler.execute(
        action,
        aiService: _aiService,
        onProgress: (msg) {
          if (mounted) {
            setState(() {
              _messages.add(ChatMessage(role: 'assistant', content: '⏳ $msg'));
            });
            _scrollToBottom();
          }
        },
        onStepProgress: (msg, {status, stepIndex}) {
          if (mounted && stepIndex != null && status != null) {
            setState(() {
              if (stepIndex < plan.length) {
                plan[stepIndex] = plan[stepIndex].copyWith(
                  status: status,
                  result: msg,
                );
              } else {
                plan.add(PlanStep(
                  title: 'Action ${stepIndex + 1}',
                  description: 'Automated step',
                  status: status,
                  result: msg,
                ));
              }

              // If goal is reached, mark all remaining pending steps as done
              if (status == PlanStepStatus.done && msg.toLowerCase().contains('goal reached')) {
                for (int i = 0; i < plan.length; i++) {
                  if (plan[i].status != PlanStepStatus.failed) {
                    plan[i] = plan[i].copyWith(status: PlanStepStatus.done);
                  }
                }
              }
            });
            _scrollToBottom();
          }
        },
        onConfirmAction: _showActionApprovalDialog,
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: result.details ?? 'Plan execution completed.',
            actionResult: result,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Error during plan execution: ${e.toString().replaceFirst('Exception: ', '')}',
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlanExecuting = false;
        });
      }
      _scrollToBottom();
    }
  }

  /// Manually compress the conversation history.
  Future<void> _compressContext() async {
    setState(() => _isCompressing = true);

    final success = await _aiService.compressHistory();

    if (mounted) {
      setState(() => _isCompressing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Context compressed. Tokens: ~${_aiService.estimatedTokenCount}'
                : 'Not enough history to compress.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PrivateAgent'),
        actions: [
          // Stop button if executing
          if (_isLoading || _isPlanExecuting)
            IconButton(
              icon: const Icon(Icons.stop_circle),
              color: Theme.of(context).colorScheme.error,
              onPressed: () {
                _actionHandler.cancelCurrentTask();
                setState(() {
                  _isLoading = false;
                  _isPlanExecuting = false;
                  _isPlanThinking = false;
                  _messages.add(ChatMessage(
                    role: 'system',
                    content: 'Execution stopped manually.',
                    isError: true,
                  ));
                });
              },
              tooltip: 'Stop Execution',
            ),
          // Shizuku status indicator
          if (_actionHandler.shizuku.isAvailable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.link,
                size: 18,
                color: _actionHandler.shizuku.hasPermission
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    aiService: _aiService,
                    shizukuService: _actionHandler.shizuku,
                    screenAutomationService: _actionHandler.screenAutomation,
                    telegramService: _telegramService,
                  ),
                ),
              );
              // Refresh Shizuku status after settings
              await _actionHandler.shizuku.checkAvailability();
              if (mounted) setState(() {});
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'test_screen':
                  final isRunning = await _actionHandler.screenAutomation.isServiceRunning();
                  if (!isRunning) {
                    setState(() {
                      _messages.add(ChatMessage(
                        role: 'assistant',
                        content:
                            '❌ Screen Control is not enabled!\n\n'
                            'To enable it:\n'
                            '1. Go to Settings (⚙️ icon)\n'
                            '2. Find "Screen Control (Accessibility)"\n'
                            '3. Tap "Open Accessibility Settings"\n'
                            '4. Find "PrivateAgent Screen Control"\n'
                            '5. Toggle it ON',
                      ));
                    });
                    _scrollToBottom();
                    return;
                  }
                  setState(() {
                    _messages.add(ChatMessage(
                      role: 'assistant',
                      content: '🔍 Reading screen...',
                    ));
                  });
                  _scrollToBottom();
                  final description = await _actionHandler.screenAutomation.getScreenDescription();
                  setState(() {
                    _messages.add(ChatMessage(
                      role: 'assistant',
                      content: '📱 Screen Content:\n\n$description',
                    ));
                  });
                  _scrollToBottom();
                  break;
                case 'compress':
                  if (!_isCompressing) {
                    await _compressContext();
                  }
                  break;
                case 'clear':
                  setState(() {
                    _messages.clear();
                    _aiService.clearHistory();
                    _currentPlan = null;
                  });
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'test_screen',
                child: Row(
                  children: [
                    Icon(Icons.visibility),
                    SizedBox(width: 8),
                    Text('Test Screen Reading'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'compress',
                enabled: !_isCompressing,
                child: Row(
                  children: [
                    _isCompressing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.compress),
                    const SizedBox(width: 8),
                    const Text('Compress Context'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // API key warning
          if (!_aiService.isConfigured)
            MaterialBanner(
              content: const Text(
                'API key not set. Go to Settings to add your DeepSeek API key.',
              ),
              leading: Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          aiService: _aiService,
                          shizukuService: _actionHandler.shizuku,
                          screenAutomationService: _actionHandler.screenAutomation,
                          telegramService: _telegramService,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  child: const Text('SETTINGS'),
                ),
              ],
            ),

          // Messages area
          Expanded(
            flex: (_currentPlan != null && !_isPlanThinking && _currentPlan!.isNotEmpty) ? 1 : 2,
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Start a conversation...',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(message: _messages[index]);
                    },
                  ),
          ),

          // Plan View (if a plan is active and AI is done thinking)
          if (_currentPlan != null && !_isPlanThinking && _currentPlan!.isNotEmpty)
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: PlanView(
                  steps: _currentPlan!,
                  isThinking: _isPlanExecuting,
                  onProceed: _isPlanExecuting ? null : _executePlan,
                  onEdit: _isPlanExecuting ? null : () {
                    setState(() => _currentPlan = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan dismissed. Type a new /plan command.')),
                    );
                  },
                  onCancel: () {
                    setState(() {
                      _currentPlan = null;
                      _isPlanExecuting = false;
                    });
                  },
                ),
              ),
            ),

          // Modern Thinking Animation
          if (_isPlanThinking)
            const ModernAuroraThinkingIndicator(),

          // Loading indicator
          if (_isLoading && !_isPlanThinking)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('Thinking...', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),

          // Token counter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tokens: ca. ${_aiService.estimatedTokenCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  '${_messages.length} messages',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),

          // Command suggestions
          if (_showCommandSuggestions)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                title: const Text('/plan <goal>'),
                subtitle: const Text('Generates a step-by-step execution plan.'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  _textController.text = '/plan ';
                  _textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _textController.text.length),
                  );
                  setState(() => _showCommandSuggestions = false);
                },
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Mic button
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: _isLoading ? null : _toggleVoice,
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Listening...'
                            : 'Type a command...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onChanged: (text) {
                        if (mounted) {
                          setState(() {
                            _showCommandSuggestions = text.startsWith('/') && !text.contains(' ');
                          });
                        }
                      },
                      onSubmitted:
                          _isLoading ? null : (text) => _sendMessage(text),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Send button
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(_textController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
