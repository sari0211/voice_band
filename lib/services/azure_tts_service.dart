import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class AzureTtsService {
  final String _subscriptionKey;
  final String _region;

  AzureTtsService({
    String? subscriptionKey,
    String? region,
  })  : _subscriptionKey = subscriptionKey ?? AppConstants.azureSubscriptionKey,
        _region = region ?? AppConstants.azureRegion;

  String get _endpoint =>
      'https://$_region.tts.speech.microsoft.com/cognitiveservices/v1';

  Future<Uint8List> synthesize(String text) async {
    final escapedText = _escapeXml(text);

    final ssml = '''<speak version='1.0' xml:lang='en-US'>
  <voice name='${AppConstants.ttsVoiceName}'>$escapedText</voice>
</speak>''';

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Ocp-Apim-Subscription-Key': _subscriptionKey,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': AppConstants.ttsOutputFormat,
      },
      body: ssml,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'TTS failed (${response.statusCode}): ${response.body}');
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception('TTS returned empty audio');
    }

    return response.bodyBytes;
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
