import 'package:url_launcher/url_launcher.dart';
import 'contacts_service.dart';


class CallFailedException implements Exception {
  final String message;
  CallFailedException(this.message);
  @override
  String toString() => 'CallFailedException: $message';
}

class SmsFailedException implements Exception {
  final String message;
  SmsFailedException(this.message);
  @override
  String toString() => 'SmsFailedException: $message';
}

class EmailFailedException implements Exception {
  final String message;
  EmailFailedException(this.message);
  @override
  String toString() => 'EmailFailedException: $message';
}

class CommunicationService {
  final ContactsService _contactsService = ContactsService();

  /// Make a phone call. Can accept a name or number.
  Future<String> makeCall({String? contactName, String? phoneNumber}) async {
    String? number = phoneNumber;

    // If contact name given, look up the number
    if (contactName != null && number == null) {
      number = await _contactsService.getPhoneNumber(contactName);
      if (number == null) {
        throw ContactNotFoundException('Could not find contact "$contactName". Try searching contacts first.');
      }
    }

    if (number == null || number.isEmpty) {
      throw CallFailedException('No phone number provided.');
    }

    try {
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return 'Calling $number${contactName != null ? ' ($contactName)' : ''}...';
      }
      throw CallFailedException('Cannot make calls on this device.');
    } catch (e) {
      if (e is CallFailedException || e is ContactNotFoundException) rethrow;
      throw CallFailedException('Error making call: $e');
    }
  }

  /// Send an SMS. Can accept a name or number.
  Future<String> sendSms({
    String? contactName,
    String? phoneNumber,
    required String message,
  }) async {
    String? number = phoneNumber;

    if (contactName != null && number == null) {
      number = await _contactsService.getPhoneNumber(contactName);
      if (number == null) {
        throw ContactNotFoundException('Could not find contact "$contactName".');
      }
    }

    if (number == null || number.isEmpty) {
      throw SmsFailedException('No phone number provided.');
    }

    try {
      final uri = Uri(
        scheme: 'sms',
        path: number,
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return 'Opening SMS to $number${contactName != null ? ' ($contactName)' : ''} with message: "$message"';
      }
      throw SmsFailedException('Cannot send SMS on this device.');
    } catch (e) {
      if (e is SmsFailedException || e is ContactNotFoundException) rethrow;
      throw SmsFailedException('Error sending SMS: $e');
    }
  }

  /// Send an email
  Future<String> sendEmail({
    required String to,
    String? subject,
    String? body,
  }) async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: to,
        queryParameters: {
          if (subject != null) 'subject': subject,
          if (body != null) 'body': body,
        },
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return 'Opening email to $to';
      }
      throw EmailFailedException('Cannot send email on this device.');
    } catch (e) {
      if (e is EmailFailedException) rethrow;
      throw EmailFailedException('Error sending email: $e');
    }
  }
}
