import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:castnow_app/main.dart'; // Ensure this matches pubspec.yaml name

class MockClient extends Mock implements http.Client {
  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    return super.noSuchMethod(
      Invocation.method(#post, [url], {#headers: headers, #body: body, #encoding: encoding}),
      returnValue: Future.value(http.Response('', 200)),
      returnValueForMissingStub: Future.value(http.Response('', 200)),
    ) as Future<http.Response>;
  }
}

void main() {
  group('GumroadService License Verification', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('returns true when license is valid and success', () async {
      final responseBody = json.encode({
        'success': true,
        'purchase': {
          'refunded': false,
          'chargebacked': false,
        }
      });

      when(mockClient.post(
        Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await GumroadService.verifyLicense('valid_key', client: mockClient);

      expect(result, isTrue);
    });

    test('returns false when success is false', () async {
      final responseBody = json.encode({
        'success': false,
        'message': 'Invalid key'
      });

      when(mockClient.post(
        Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await GumroadService.verifyLicense('invalid_key', client: mockClient);

      expect(result, isFalse);
    });

    test('returns false when purchase is refunded', () async {
      final responseBody = json.encode({
        'success': true,
        'purchase': {
          'refunded': true,
          'chargebacked': false,
        }
      });

      when(mockClient.post(
        Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await GumroadService.verifyLicense('refunded_key', client: mockClient);

      expect(result, isFalse);
    });

    test('returns false on non-200 status code', () async {
      when(mockClient.post(
        Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Error', 404));

      final result = await GumroadService.verifyLicense('any_key', client: mockClient);

      expect(result, isFalse);
    });
  });
}
