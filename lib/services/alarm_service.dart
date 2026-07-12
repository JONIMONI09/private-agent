import 'package:android_intent_plus/android_intent.dart';

class AlarmFailedException implements Exception {
  final String message;
  AlarmFailedException(this.message);
  @override
  String toString() => 'AlarmFailedException: $message';
}

class TimerFailedException implements Exception {
  final String message;
  TimerFailedException(this.message);
  @override
  String toString() => 'TimerFailedException: $message';
}

class AlarmService {
  /// Set an alarm using Android's built-in alarm intent
  Future<String> setAlarm({
    required int hour,
    required int minute,
    String? label,
  }) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          if (label != null) 'android.intent.extra.alarm.MESSAGE': label,
          'android.intent.extra.alarm.SKIP_UI': true,
        },
      );
      await intent.launch();
      final timeStr =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      return 'Alarm set for $timeStr${label != null ? ' ($label)' : ''}';
    } catch (e) {
      throw AlarmFailedException('Error setting alarm: $e');
    }
  }

  /// Set a timer using Android's built-in timer intent
  Future<String> setTimer({
    required int seconds,
    String? label,
  }) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_TIMER',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.LENGTH': seconds,
          if (label != null) 'android.intent.extra.alarm.MESSAGE': label,
          'android.intent.extra.alarm.SKIP_UI': true,
        },
      );
      await intent.launch();
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return 'Timer set for ${minutes}m ${secs}s${label != null ? ' ($label)' : ''}';
    } catch (e) {
      throw TimerFailedException('Error setting timer: $e');
    }
  }
}
