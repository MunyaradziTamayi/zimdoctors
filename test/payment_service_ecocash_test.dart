import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zimdoctors/services/payment_service.dart';

class _CapturingClient extends http.BaseClient {
  _CapturingClient(this._handler);

  final Future<http.Response> Function(http.Request request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final r = request as http.Request;
    final resp = await _handler(r);
    return http.StreamedResponse(
      Stream.value(resp.bodyBytes),
      resp.statusCode,
      headers: resp.headers,
      reasonPhrase: resp.reasonPhrase,
      request: request,
    );
  }
}

void main() {
  final uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  test('EcoCash initiation sends UUID sourceReference and normalized msisdn', () async {
    late Map<String, dynamic> body;
    late Uri url;

    final client = _CapturingClient((request) async {
      url = request.url;
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'success': true, 'reference': 'backend-ref'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = PaymentService(client: client);
    final resp = await service.initiateMobileMoneyPayment(
      amount: 25,
      currencyCode: 'USD',
      transactionDescription: 'Consultation',
      transactionReference: 'TXN_123', // invalid UUID; must be replaced
      customerName: 'Pat',
      customerEmail: 'pat@example.com',
      customerPhone: '+263 78 064 9692',
      paymentMethodCode: 'PZW201',
    );

    expect(url.path, endsWith('/payments/ecocash/direct'));
    expect(body['customerMsisdn'], '263780649692');
    expect(body['reason'], 'Consultation');
    expect(body['currency'], 'USD');
    expect(body['sourceReference'], isA<String>());
    expect(uuidRegex.hasMatch(body['sourceReference'] as String), isTrue);

    // We still accept whatever the backend returns as referenceNumber (if present).
    expect(resp.referenceNumber, isNotEmpty);
  });

  test('EcoCash msisdn normalization removes trunk 0 after 263', () async {
    late Map<String, dynamic> body;

    final client = _CapturingClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'success': true, 'reference': 'backend-ref'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = PaymentService(client: client);
    await service.initiateMobileMoneyPayment(
      amount: 25,
      currencyCode: 'USD',
      transactionDescription: 'Consultation',
      transactionReference: 'TXN_123',
      customerName: 'Pat',
      customerEmail: 'pat@example.com',
      customerPhone: '+2630771234567',
      paymentMethodCode: 'PZW201',
    );

    expect(body['customerMsisdn'], '263771234567');
  });

  test('EcoCash empty-response error is treated as initiated (success)', () async {
    late Map<String, dynamic> body;

    final client = _CapturingClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'success': false,
          'message':
              'Empty response from EcoCash Sandbox. Check if your API key is active.',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = PaymentService(client: client);
    final resp = await service.initiateMobileMoneyPayment(
      amount: 25,
      currencyCode: 'USD',
      transactionDescription: 'Consultation',
      transactionReference: 'TXN_123', // invalid UUID; will be replaced
      customerName: 'Pat',
      customerEmail: 'pat@example.com',
      customerPhone: '0771234567',
      paymentMethodCode: 'PZW201',
    );

    final src = (body['sourceReference'] ?? '').toString();
    expect(uuidRegex.hasMatch(src), isTrue);
    expect(resp.referenceNumber, src);
  });
}
