import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ai_service.dart';
import '../services/shizuku_service.dart';
import '../services/screen_automation_service.dart';
import '../services/telegram_service.dart';
import '../services/app_launcher_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_permissions_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AiService aiService;
  final ShizukuService shizukuService;
  final ScreenAutomationService screenAutomationService;
  final TelegramService telegramService;

  const SettingsScreen({
    super.key,
    required this.aiService,
    required this.shizukuService,
    required this.screenAutomationService,
    required this.telegramService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  // Existing controllers & state
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;
  late TextEditingController _telegramTokenController;
  bool _obscureKey = true;
  bool _telegramEnabled = false;
  double _maxSteps = 15;
  bool _disableMaxSteps = false;

  // New state variables
  bool _yoloMode = false;
  String _toolCallingFormat = 'JSON';
  int _extremeThinkingDepth = 0;
  bool _autoCompressHistory = true;
  bool _mcpEnabled = false;
  late TextEditingController _mcpUrlController;
  late TextEditingController _telegramWhitelistController;

  final Map<String, PermissionStatus> _permissions = {};
  Future<bool>? _accessibilityServiceFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiKeyController = TextEditingController(text: widget.aiService.apiKey);
    _baseUrlController = TextEditingController(text: widget.aiService.baseUrl);
    _modelController = TextEditingController(text: widget.aiService.model);
    _telegramTokenController = TextEditingController(
      text: widget.telegramService.botToken,
    );
    _telegramEnabled = widget.telegramService.isEnabled;
    _maxSteps = widget.aiService.rawMaxSteps.toDouble();
    _disableMaxSteps = widget.aiService.disableMaxSteps;

    // Initialize new state
    _yoloMode = widget.aiService.yoloMode;
    _toolCallingFormat = widget.aiService.toolCallingFormat;
    _extremeThinkingDepth = widget.aiService.extremeThinkingDepth;
    _autoCompressHistory = widget.aiService.autoCompressHistory;
    _mcpEnabled = widget.aiService.mcpEnabled;
    _mcpUrlController = TextEditingController(text: widget.aiService.mcpUrl);
    _telegramWhitelistController = TextEditingController(
      text: widget.aiService.telegramWhitelist,
    );

    _accessibilityServiceFuture = widget.screenAutomationService.isServiceRunning();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _telegramTokenController.dispose();
    _mcpUrlController.dispose();
    _telegramWhitelistController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the UI when coming back from Android Settings
      _accessibilityServiceFuture = widget.screenAutomationService.isServiceRunning();
      if (mounted) setState(() {});
    }
  }

  Future<void> _checkPermissions() async {
    final perms = {
      'Microphone': Permission.microphone,
      'Contacts': Permission.contacts,
      'Phone': Permission.phone,
      'SMS': Permission.sms,
      'Notifications': Permission.notification,
    };

    for (final entry in perms.entries) {
      _permissions[entry.key] = await entry.value.status;
    }
    if (mounted) setState(() {});
  }

  Future<void> _requestPermission(String name, Permission permission) async {
    final status = await permission.request();
    if (mounted) setState(() => _permissions[name] = status);
  }

  // _saveApiSettings removed in favor of _saveAllSettings

  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Base URL and API Key first.'),
        ),
      );
      return;
    }

    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return const Center(child: CircularProgressIndicator());
      },
    );

    final models = await widget.aiService.fetchAvailableModels(baseUrl, apiKey);

    // Hide loading
    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.pop(dialogContext!);
    } else if (mounted) {
      Navigator.pop(context);
    }

    if (models.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No models found or error fetching models.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select a Model'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: models.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(models[index]),
                  onTap: () {
                    setState(() {
                      _modelController.text = models[index];
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.tune), text: 'General'),
              Tab(icon: Icon(Icons.smart_toy), text: 'AI Models'),
              Tab(icon: Icon(Icons.security), text: 'Permissions'),
              Tab(icon: Icon(Icons.science), text: 'Advanced'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGeneralTab(),
            _buildAiModelsTab(),
            _buildPermissionsTab(),
            _buildAdvancedTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveAllSettings,
          icon: const Icon(Icons.save),
          label: const Text('Save All Settings'),
        ),
      ),
    );
  }

  Future<void> _saveAllSettings() async {
    // API & General
    await widget.aiService.saveSettings(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );

    // Telegram
    await widget.telegramService.saveSettings(
      botToken: _telegramTokenController.text.trim(),
      isEnabled: _telegramEnabled,
    );

    // Advanced & Limits
    await widget.aiService.saveMaxSteps(_maxSteps.toInt());
    await widget.aiService.saveDisableMaxSteps(_disableMaxSteps);
    await widget.aiService.saveYoloMode(_yoloMode);
    widget.aiService.telegramWhitelist = _telegramWhitelistController.text.trim();
    widget.aiService.toolCallingFormat = _toolCallingFormat;
    widget.aiService.extremeThinkingDepth = _extremeThinkingDepth;
    widget.aiService.autoCompressHistory = _autoCompressHistory;
    widget.aiService.mcpUrl = _mcpUrlController.text.trim();
    widget.aiService.mcpEnabled = _mcpEnabled;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All Settings Saved!')),
      );
    }
  }

  // ─── Tab 1: General ────────────────────────────────────────────────────

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [


        // Telegram section
        Text(
          'Telegram Remote Access (Optional)',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telegramTokenController,
          decoration: const InputDecoration(
            labelText: 'Telegram Bot Token',
            hintText: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          title: const Text('Enable Telegram Bot'),
          subtitle: const Text('Allows remote control via Telegram chat'),
          value: _telegramEnabled,
          onChanged: (val) {
            if (mounted) setState(() => _telegramEnabled = val);
          },
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telegramWhitelistController,
          decoration: const InputDecoration(
            labelText: 'Telegram Chat ID Whitelist',
            hintText: '123456789, 987654321',
            border: OutlineInputBorder(),
            helperText:
                'Comma-separated chat IDs allowed to control the bot. Leave empty to allow all (insecure).',
            helperMaxLines: 3,
          ),
        ),
        const Divider(height: 32),

        // About section
        Text(
          'About',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Project Repository'),
          subtitle: const Text('View the official source code on GitHub'),
          onTap: () {
            launchUrl(
              Uri.parse('https://github.com/orailnoor/private-agent'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Orailnoor on YouTube'),
          subtitle: const Text('Subscribe for project updates and tutorials'),
          onTap: () {
            launchUrl(
              Uri.parse('https://www.youtube.com/orailnoor'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Tab 2: AI Models ──────────────────────────────────────────────────

  Widget _buildAiModelsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'AI Configuration',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('YOLO Mode (Autonomous)'),
          subtitle: const Text(
            'When enabled, the agent executes all actions without asking for confirmation.',
          ),
          value: _yoloMode,
          onChanged: (val) {
            if (mounted) {
              setState(() => _yoloMode = val);
            }
          },
        ),
        const Divider(height: 32),

        // API Key
        TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: 'sk-...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                if (mounted) setState(() => _obscureKey = !_obscureKey);
              },
            ),
          ),
          obscureText: _obscureKey,
        ),
        const SizedBox(height: 12),

        // Base URL
        TextField(
          controller: _baseUrlController,
          decoration: const InputDecoration(
            labelText: 'API Base URL',
            hintText: 'https://api.deepseek.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('DeepSeek', style: TextStyle(fontSize: 12)),
              onPressed: () =>
                  _baseUrlController.text = 'https://api.deepseek.com',
            ),
            ActionChip(
              label: const Text('OpenRouter', style: TextStyle(fontSize: 12)),
              onPressed: () =>
                  _baseUrlController.text = 'https://openrouter.ai/api/v1',
            ),
            ActionChip(
              label: const Text('Groq', style: TextStyle(fontSize: 12)),
              onPressed: () =>
                  _baseUrlController.text = 'https://api.groq.com/openai/v1',
            ),
            ActionChip(
              label: const Text('Local', style: TextStyle(fontSize: 12)),
              onPressed: () =>
                  _baseUrlController.text = 'http://10.0.2.2:1234/v1',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Model + Fetch
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'deepseek-chat',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _fetchModels,
              icon: const Icon(Icons.cloud_download),
              label: const Text('Fetch'),
            ),
          ],
        ),
        const Divider(height: 32),

        // Max Steps
        SwitchListTile(
          title: const Text('Disable Maximum Steps'),
          subtitle: Text(
            '⚠️ Warning: Can cause infinite loops.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          value: _disableMaxSteps,
          onChanged: (bool value) {
            if (mounted) setState(() => _disableMaxSteps = value);
          },
        ),
        if (!_disableMaxSteps) ...[
          Text(
            'Maximum Steps Per Task: ${_maxSteps.toInt()}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Slider(
            value: _maxSteps,
            min: 5,
            max: 50,
            divisions: 45,
            label: _maxSteps.toInt().toString(),
            onChanged: (value) {
              if (mounted) setState(() => _maxSteps = value);
            },
          ),
        ],
        const SizedBox(height: 12),

        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Tab 3: Permissions ────────────────────────────────────────────────

  Widget _buildPermissionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // System Permissions
        Text(
          'System Permissions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._buildPermissionTiles(),

        const Divider(height: 32),

        // Accessibility
        Text(
          'Screen Control (Accessibility)',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildAccessibilityCard(),

        const Divider(height: 32),

        // Shizuku
        Text(
          'Shizuku (Optional)',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Shizuku allows extra features like toggling WiFi, force-stopping apps, and running ADB commands without root.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _buildShizukuCard(),

        const Divider(height: 32),

        // App Permissions
        Text(
          'App Permissions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.apps),
          title: const Text('Manage App Permissions'),
          subtitle: const Text(
            'Control which apps the agent can interact with',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppPermissionsScreen(
                  appLauncher: AppLauncherService(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Tab 4: Advanced ───────────────────────────────────────────────────

  Widget _buildAdvancedTab() {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tool Calling Format
        Text(
          'Tool Calling Format',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'JSON',
              label: Text('JSON'),
              icon: Icon(Icons.code),
            ),
            ButtonSegment(
              value: 'XML',
              label: Text('XML'),
              icon: Icon(Icons.data_object),
            ),
          ],
          selected: {_toolCallingFormat},
          onSelectionChanged: (val) {
            if (mounted) {
              setState(() => _toolCallingFormat = val.first);
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Use XML for local models to reduce hallucination in tool-calling responses.',
          style: theme.textTheme.bodySmall,
        ),
        const Divider(height: 32),

        // Extreme Thinking Mode
        Text(
          'Extreme Thinking Mode',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withAlpha(38),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warning: Only change this if you know what you are doing. '
                        'Higher values increase response quality but significantly '
                        'increase token usage and latency.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thinking Depth: $_extremeThinkingDepth',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Slider(
                      value: _extremeThinkingDepth.toDouble(),
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: _extremeThinkingDepth.toString(),
                      onChanged: (val) {
                        if (mounted) {
                          setState(
                            () => _extremeThinkingDepth = val.toInt(),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 32),

        // History Management
        Text(
          'History Management',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Auto-Compress History'),
          subtitle: const Text(
            'Automatically compress chat history when token limits are reached '
            'to prevent context overflow.',
          ),
          value: _autoCompressHistory,
          onChanged: (val) {
            if (mounted) setState(() => _autoCompressHistory = val);
          },
        ),
        const Divider(height: 32),

        // MCP Connector
        Text(
          'MCP Connector',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(
            'BETA',
            style: TextStyle(
              color: theme.colorScheme.onTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: theme.colorScheme.tertiary,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Enable MCP Server'),
          subtitle: const Text(
            'Connect to external MCP tool servers for additional capabilities.',
          ),
          value: _mcpEnabled,
          onChanged: (val) {
            if (mounted) setState(() => _mcpEnabled = val);
          },
        ),
        if (_mcpEnabled) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _mcpUrlController,
            decoration: const InputDecoration(
              labelText: 'MCP Server URL',
              hintText: 'http://10.0.2.2:3000',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Shared Helpers ────────────────────────────────────────────────────

  List<Widget> _buildPermissionTiles() {
    final permissionMap = {
      'Microphone': Permission.microphone,
      'Contacts': Permission.contacts,
      'Phone': Permission.phone,
      'SMS': Permission.sms,
      'Notifications': Permission.notification,
    };

    final icons = {
      'Microphone': Icons.mic,
      'Contacts': Icons.contacts,
      'Phone': Icons.phone,
      'SMS': Icons.sms,
      'Notifications': Icons.notifications,
    };

    return permissionMap.entries.map((entry) {
      final status = _permissions[entry.key];
      final isGranted = status?.isGranted ?? false;

      return ListTile(
        leading: Icon(icons[entry.key]),
        title: Text(entry.key),
        trailing: isGranted
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : TextButton(
                onPressed: () => _requestPermission(entry.key, entry.value),
                child: const Text('Grant'),
              ),
        subtitle: Text(
          isGranted
              ? 'Granted'
              : (status?.isDenied ?? true
                  ? 'Not granted'
                  : 'Denied permanently'),
          style: TextStyle(
            color: isGranted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            fontSize: 12,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildShizukuCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.shizukuService.isAvailable
                      ? Icons.link
                      : Icons.link_off,
                  color: widget.shizukuService.isAvailable
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.shizukuService.isAvailable
                      ? 'Shizuku is running'
                      : 'Shizuku not detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: widget.shizukuService.isAvailable
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!widget.shizukuService.isAvailable) ...[
              const Text(
                '1. Install Shizuku from Play Store\n'
                '2. Open Shizuku and start it via Wireless Debugging\n'
                '3. Come back here and tap "Check Again"',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await widget.shizukuService.checkAvailability();
                  if (mounted) setState(() {});
                },
                child: const Text('Check Again'),
              ),
            ] else if (!widget.shizukuService.hasPermission) ...[
              OutlinedButton(
                onPressed: () async {
                  await widget.shizukuService.requestPermission();
                  if (mounted) setState(() {});
                },
                child: const Text('Grant Shizuku Permission'),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Permission granted — ADB commands available',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityCard() {
    return FutureBuilder<bool>(
      future: _accessibilityServiceFuture,
      builder: (context, snapshot) {
        final isRunning = snapshot.data ?? false;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isRunning ? Icons.visibility : Icons.visibility_off,
                      color: isRunning
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRunning
                          ? 'Screen Control is active'
                          : 'Screen Control is disabled',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isRunning
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isRunning) ...[
                  const Text(
                    'Tap below to open Accessibility Settings, then find '
                    '"PrivateAgent Screen Control" and enable it.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await widget.screenAutomationService
                          .openAccessibilitySettings();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Open Accessibility Settings'),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Can read screen, tap, scroll, and type in other apps',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
