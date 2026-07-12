import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../services/app_launcher_service.dart';

/// Screen for managing which installed apps the agent is allowed to interact
/// with. Apps can be individually toggled or bulk-blocked / bulk-allowed.
class AppPermissionsScreen extends StatefulWidget {
  final AppLauncherService appLauncher;

  const AppPermissionsScreen({
    super.key,
    required this.appLauncher,
  });

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen> {
  List<AppInfo> _allApps = [];
  List<String> _blockedPackages = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final apps =
          await widget.appLauncher.getInstalledApps(includeBlocked: true);
      final blocked = await widget.appLauncher.getBlockedApps();

      // Sort alphabetically by app name.
      apps.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _allApps = apps;
        _blockedPackages = List<String>.from(blocked);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load apps: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  List<AppInfo> get _filteredApps {
    if (_searchQuery.isEmpty) return _allApps;
    final query = _searchQuery.toLowerCase();
    return _allApps
        .where((app) => app.name.toLowerCase().contains(query))
        .toList();
  }

  int get _blockedCount => _blockedPackages.length;

  // ---------------------------------------------------------------------------
  // Toggle helpers
  // ---------------------------------------------------------------------------

  Future<void> _toggleApp(String packageName, bool isAllowed) async {
    if (!mounted) return;
    setState(() {
      if (isAllowed) {
        _blockedPackages.remove(packageName);
      } else {
        if (!_blockedPackages.contains(packageName)) {
          _blockedPackages.add(packageName);
        }
      }
    });
    await widget.appLauncher.saveBlockedApps(_blockedPackages);
  }

  Future<void> _blockAll() async {
    if (!mounted) return;
    setState(() {
      _blockedPackages =
          _allApps.map((app) => app.packageName).toList();
    });
    await widget.appLauncher.saveBlockedApps(_blockedPackages);
    _showSnackBar('All apps blocked');
  }

  Future<void> _allowAll() async {
    if (!mounted) return;
    setState(() {
      _blockedPackages = [];
    });
    await widget.appLauncher.saveBlockedApps(_blockedPackages);
    _showSnackBar('All apps allowed');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App Permissions'),
            Text(
              '$_blockedCount app${_blockedCount == 1 ? '' : 's'} blocked',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
            onSelected: (value) {
              switch (value) {
                case 'block_all':
                  _blockAll();
                  break;
                case 'allow_all':
                  _allowAll();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'block_all',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: colorScheme.error),
                    const SizedBox(width: 12),
                    const Text('Block All'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'allow_all',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 20, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    const Text('Allow All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            )
          : Column(
              children: [
                _buildSearchBar(colorScheme),
                Expanded(child: _buildAppList(colorScheme)),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: (value) {
          if (!mounted) return;
          setState(() => _searchQuery = value);
        },
        decoration: InputDecoration(
          hintText: 'Search apps…',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    if (!mounted) return;
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: colorScheme.outlineVariant, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
        style: TextStyle(color: colorScheme.onSurface),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // App list
  // ---------------------------------------------------------------------------

  Widget _buildAppList(ColorScheme colorScheme) {
    final apps = _filteredApps;

    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No apps found',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isBlocked = _blockedPackages.contains(app.packageName);
        final isAllowed = !isBlocked;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 3),
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isBlocked
                  ? colorScheme.error.withValues(alpha: 0.15)
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: _buildAppIcon(app, colorScheme),
            title: Text(
              app.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isBlocked
                    ? colorScheme.onSurface.withValues(alpha: 0.5)
                    : colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              app.packageName,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Switch.adaptive(
              value: isAllowed,
              onChanged: (value) => _toggleApp(app.packageName, value),
              activeThumbColor: colorScheme.primary,
              inactiveThumbColor: colorScheme.outline,
              inactiveTrackColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // App icon
  // ---------------------------------------------------------------------------

  Widget _buildAppIcon(AppInfo app, ColorScheme colorScheme) {
    final Uint8List? iconBytes = app.icon;

    if (iconBytes != null && iconBytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          iconBytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _defaultAppIcon(colorScheme),
        ),
      );
    }

    return _defaultAppIcon(colorScheme);
  }

  Widget _defaultAppIcon(ColorScheme colorScheme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.android,
        size: 24,
        color: colorScheme.primary,
      ),
    );
  }
}
