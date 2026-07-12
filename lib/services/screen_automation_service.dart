import 'package:flutter/services.dart';

/// Dart bridge to the native AccessibilityService.
/// Provides screen reading, UI element interaction, and gesture control.
class ScreenAutomationService {
  static const _channel = MethodChannel('com.privateagent/accessibility');

  /// Check if the accessibility service is running
  Future<bool> isServiceRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isServiceRunning') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Open Android accessibility settings so user can enable the service
  Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  /// Dump the current screen — returns a list of UI elements
  /// Each element has: text, contentDescription, className, isClickable,
  /// isEditable, isScrollable, bounds, index, depth
  Future<List<Map<String, dynamic>>> dumpScreen() async {
    try {
      final result = await _channel.invokeMethod<List>('dumpScreen');
      if (result == null) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Take a screenshot and return it as a Base64 encoded string.
  /// Note: Requires Android 11 (API 30) or higher.
  Future<String?> takeScreenshot() async {
    try {
      final result = await _channel.invokeMethod<String>('takeScreenshot');
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Get a simplified text description of the current screen for the LLM
  Future<String> getScreenDescription() async {
    final nodes = await dumpScreen();
    if (nodes.isEmpty) {
      return 'Could not read screen. Make sure accessibility service is enabled.';
    }

    final buffer = StringBuffer();
    final pkg = await getCurrentPackage();
    if (pkg != null) {
      buffer.writeln('Current app: $pkg');
    }
    buffer.writeln('Screen elements:');

    for (final node in nodes) {
      final index = node['index'];
      final text = node['text'] ?? '';
      final desc = node['contentDescription'] ?? '';
      var className = node['className'] as String? ?? '';
      final isClickable = node['isClickable'] == true;
      final isEditable = node['isEditable'] == true;
      final isScrollable = node['isScrollable'] == true;

      final displayText = text.isNotEmpty ? text : desc;
      if (displayText.isEmpty && !isClickable && !isEditable && !isScrollable) {
        continue; // Skip empty non-interactive nodes
      }

      // Simplify full Java package names to save characters/tokens
      if (className.contains('.')) {
        className = className.split('.').last;
      }

      final tags = <String>[];
      if (isClickable) tags.add('clickable');
      if (isEditable) tags.add('editable');
      if (isScrollable) tags.add('scrollable');

      final label = displayText.isNotEmpty ? '"$displayText"' : '(no text)';
      final type = className.isNotEmpty ? '[$className]' : '';
      final tagStr = tags.isNotEmpty ? '{${tags.join(", ")}}' : '';
      
      String boundsStr = '';
      if (node['bounds'] is Map) {
        final b = node['bounds'] as Map;
        final left = b['left'] is num ? (b['left'] as num).toDouble() : 0.0;
        final right = b['right'] is num ? (b['right'] as num).toDouble() : 0.0;
        final top = b['top'] is num ? (b['top'] as num).toDouble() : 0.0;
        final bottom = b['bottom'] is num ? (b['bottom'] as num).toDouble() : 0.0;
        final centerX = (left + right) / 2;
        final centerY = (top + bottom) / 2;
        // Output center coordinates only to reduce redundancy and simplify coordinates for AI
        boundsStr = ' center:(${centerX.round()},${centerY.round()})';
      }

      buffer.writeln('  [$index] $type $label $tagStr$boundsStr');
    }

    return buffer.toString();
  }

  /// Click an element by its visible text
  Future<bool> clickByText(String text) async {
    try {
      return await _channel.invokeMethod<bool>('clickByText', {'text': text}) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Click at specific screen coordinates
  Future<bool> clickAt(double x, double y) async {
    try {
      return await _channel
              .invokeMethod<bool>('clickAt', {'x': x, 'y': y}) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Type text into an editable field
  Future<bool> typeText(String text, {String? fieldHint}) async {
    try {
      return await _channel.invokeMethod<bool>(
              'typeText', {'text': text, 'fieldHint': fieldHint}) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Scroll in a direction ("down", "up")
  Future<bool> scroll(String direction, {String? target}) async {
    try {
      return await _channel.invokeMethod<bool>(
              'scroll', {'direction': direction, 'target': target}) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Swipe from one point to another
  Future<bool> swipe(
      double startX, double startY, double endX, double endY) async {
    try {
      return await _channel.invokeMethod<bool>('swipe', {
            'startX': startX,
            'startY': startY,
            'endX': endX,
            'endY': endY,
          }) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Press the back button
  Future<bool> pressBack() async {
    try {
      return await _channel.invokeMethod<bool>('pressBack') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Press the home button
  Future<bool> pressHome() async {
    try {
      return await _channel.invokeMethod<bool>('pressHome') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Open notifications panel
  Future<bool> openNotifications() async {
    try {
      return await _channel.invokeMethod<bool>('openNotifications') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get current foreground app package name
  Future<String?> getCurrentPackage() async {
    try {
      return await _channel.invokeMethod<String>('getCurrentPackage');
    } catch (e) {
      return null;
    }
  }
}
