import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class AppBlockedException implements Exception {
  final String message;
  AppBlockedException(this.message);
  @override
  String toString() => 'AppBlockedException: $message';
}

class AppNotFoundException implements Exception {
  final String message;
  AppNotFoundException(this.message);
  @override
  String toString() => 'AppNotFoundException: $message';
}

class AppLaunchException implements Exception {
  final String message;
  AppLaunchException(this.message);
  @override
  String toString() => 'AppLaunchException: $message';
}

class UrlOpenException implements Exception {
  final String message;
  UrlOpenException(this.message);
  @override
  String toString() => 'UrlOpenException: $message';
}

class AppLauncherService {
  List<AppInfo>? _cachedApps;

  /// Retrieve the list of blocked app package names from SharedPreferences
  Future<List<String>> getBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('blocked_apps_packages') ?? [];
  }

  /// Save the list of blocked app package names to SharedPreferences
  Future<void> saveBlockedApps(List<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_apps_packages', packages);
  }

  /// Get all installed apps (cached)
  Future<List<AppInfo>> getInstalledApps({bool includeBlocked = false}) async {
    try {
      _cachedApps ??= await InstalledApps.getInstalledApps();
    } catch (e) {
      developer.log('Error fetching installed apps: $e', name: 'AppLauncherService', error: e);
      _cachedApps = null;
      rethrow;
    }

    if (includeBlocked) {
      return _cachedApps!;
    } else {
      final blocked = await getBlockedApps();
      return _cachedApps!.where((app) => !blocked.contains(app.packageName)).toList();
    }
  }

  /// Clear app cache
  void clearCache() {
    _cachedApps = null;
  }

  /// Find apps matching a query
  Future<List<AppInfo>> searchApps(String query) async {
    final apps = await getInstalledApps(includeBlocked: false);
    final lowerQuery = query.toLowerCase();
    return apps.where((app) {
      return app.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Open an app by name (fuzzy match)
  Future<String> openApp(String appName) async {
    final allApps = await getInstalledApps(includeBlocked: true);
    final lowerName = appName.toLowerCase();
    
    final matches = allApps.where((app) {
      return app.name.toLowerCase().contains(lowerName);
    }).toList();

    if (matches.isEmpty) {
      developer.log('App not found: $appName', name: 'AppLauncherService');
      throw AppNotFoundException('Could not find app "$appName". Try being more specific.');
    }

    // Try exact match first
    AppInfo? target;
    for (final app in matches) {
      if (app.name.toLowerCase() == lowerName) {
        target = app;
        break;
      }
    }
    target ??= matches.first;

    // Check blocked status
    final blocked = await getBlockedApps();
    if (blocked.contains(target.packageName)) {
      developer.log('Access Denied: The app "${target.name}" is blocked.', name: 'AppLauncherService');
      throw AppBlockedException('The app "${target.name}" is blocked by security permissions.');
    }

    try {
      await InstalledApps.startApp(target.packageName);
      return 'Opened ${target.name}';
    } catch (e) {
      developer.log('Error opening ${target.name}: $e', error: e, name: 'AppLauncherService');
      throw AppLaunchException('Error opening ${target.name}: $e');
    }
  }

  /// Open a URL
  Future<String> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        throw UrlOpenException('Only http and https URLs are allowed for security reasons.');
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return 'Opened $url';
      }
      throw UrlOpenException('Cannot open $url');
    } catch (e) {
      if (e is UrlOpenException) rethrow;
      developer.log('Error opening URL: $e', error: e, name: 'AppLauncherService');
      throw UrlOpenException('Error opening URL: $e');
    }
  }
}
