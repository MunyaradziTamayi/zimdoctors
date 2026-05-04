import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:pesepay/pesepay.dart'; // Keep for model types if still used by UI
import 'package:zimdoctors/services/backend_config.dart';

class PaymentService {
  PaymentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Uri _baseUri = BackendConfig.diseaseApiBaseUri();

  String _firstNonEmptyString(Iterable<Object?> candidates, {String fallback = ''}) {
    for (final c in candidates) {
      if (c == null) continue;
      final s = c.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  String _normalizeZimMsisdn(String input) {
    final trimmed = input.trim();
    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');

    var noPlus = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;

    // Common user input mistake: including the trunk "0" after the country code,
    // e.g. "+2630771234567" or "263 0 77 123 4567". Normalize to "263771234567".
    if (noPlus.startsWith('2630') && noPlus.length >= 13) {
      noPlus = '263${noPlus.substring(4)}';
    }

    if (noPlus.startsWith('0') && noPlus.length >= 10) {
      return '263${noPlus.substring(1)}';
    }
    return noPlus;
  }

  bool _isValidUuid(String input) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    ).hasMatch(input.trim());
  }

  String _uuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

    // Per RFC 4122: set version to 4 and variant to 10xx.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(hex).toList(growable: false);

    return '${b.sublist(0, 4).join()}-${b.sublist(4, 6).join()}-${b.sublist(6, 8).join()}-${b.sublist(8, 10).join()}-${b.sublist(10, 16).join()}';
  }

  Uri _endpointUri(String endpointPath) {
    final basePath = _baseUri.path;
    final normalizedBasePath = (basePath.endsWith('/') && basePath.length > 1)
        ? basePath.substring(0, basePath.length - 1)
        : (basePath == '/' ? '' : basePath);
    final path = '$normalizedBasePath/$endpointPath';
    return _baseUri.replace(path: path);
  }

  Future<TransactionResponse> initiateMobileMoneyPayment({
    required double amount,
    required String currencyCode,
    required String transactionDescription,
    required String transactionReference,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String paymentMethodCode,
  }) async {
    String endpoint;
    Map<String, dynamic> body;

    // Route to correct backend service based on method code
    if (paymentMethodCode == 'PZW201') {
      // EcoCash (direct) via backend `/payments/ecocash/direct`
      endpoint = 'payments/ecocash/direct';
      final sourceReference = _isValidUuid(transactionReference)
          ? transactionReference.trim()
          : _uuidV4();
      body = {
        'customerMsisdn': _normalizeZimMsisdn(customerPhone),
        'amount': amount,
        'reason': transactionDescription,
        'currency': currencyCode,
        'sourceReference': sourceReference,
      };
    } else if (paymentMethodCode == 'PZW202') {
      // OneMoney via Paynow
      endpoint = 'payments/paynow/initiate-mobile';
      body = {
        'amount': amount,
        'phone': customerPhone,
        'email': customerEmail,
        'method': 'onemoney',
      };
    } else if (paymentMethodCode.startsWith('PESE')) {
      // Assuming a prefix for Pesepay
      endpoint = 'payments/pesepay/initiate';
      body = {
        'amount': amount,
        'currency_code': currencyCode,
        'customer_email': customerEmail,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'transaction_description': transactionDescription,
        'return_url': 'https://zimdoctors.com/return',
        'result_url': 'https://zimdoctors.com/result',
      };
    } else {
      // Default to Pesepay for other codes
      endpoint = 'payments/pesepay/initiate';
      body = {
        'amount': amount,
        'currency_code': currencyCode,
        'customer_email': customerEmail,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'transaction_description': transactionDescription,
        'return_url': 'https://zimdoctors.com/return',
        'result_url': 'https://zimdoctors.com/result',
      };
    }

    try {
      final response = await _client.post(
        _endpointUri(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final Map<String, dynamic> data =
            (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};

        if (endpoint == 'payments/ecocash/direct') {
          final sourceReference = (body['sourceReference'] ?? '').toString();
          if (data['success'] == false) {
            final message = (data['message'] ?? '').toString();
            // EcoCash sandbox sometimes returns an empty body even though the
            // USSD prompt may still be triggered. In that case, treat the
            // request as initiated and use our UUID as the reference.
            if (message.toLowerCase().contains('empty response from ecocash')) {
              return TransactionResponse(
                referenceNumber: sourceReference,
                pollUrl: '',
                redirectUrl: '',
              );
            }
            throw Exception(message.isEmpty ? 'Direct EcoCash failed' : message);
          }

          final referenceNumber = _firstNonEmptyString(
            [
              data['reference'],
              data['sourceReference'],
              data['paymentId'],
              data['transaction_reference'],
              sourceReference,
            ],
          );

          return TransactionResponse(
            referenceNumber: referenceNumber,
            pollUrl: _firstNonEmptyString([data['poll_url'], data['pollUrl']]),
            redirectUrl:
                _firstNonEmptyString([data['redirect_url'], data['redirectUrl']]),
          );
        }

        if (data['success'] == true) {
          return TransactionResponse(
            referenceNumber:
                _firstNonEmptyString([data['transaction_reference'], data['poll_url']]),
            pollUrl: _firstNonEmptyString([data['poll_url']]),
            redirectUrl: _firstNonEmptyString([data['redirect_url']]),
          );
        }

        throw Exception(data['message'] ?? 'Payment initiation failed');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Payment error at $endpoint: $e');
    }
  }

  Future<TransactionResponse> initiateDirectEcocash({
    required double amount,
    required String phone,
    required String reason,
    String currency = 'USD',
    String? sourceReference,
  }) async {
    try {
      final effectiveSourceReference =
          (sourceReference != null && _isValidUuid(sourceReference))
              ? sourceReference.trim()
              : _uuidV4();
      final response = await _client.post(
        _endpointUri('payments/ecocash/direct'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customerMsisdn': _normalizeZimMsisdn(phone),
          'amount': amount,
          'reason': reason,
          'currency': currency,
          'sourceReference': effectiveSourceReference,
        }),
      );

      final dynamic decoded = jsonDecode(response.body);
      final Map<String, dynamic> data =
          (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};

      if (response.statusCode == 200) {
        if (data['success'] == false) {
          final message = (data['message'] ?? '').toString();
          if (message.toLowerCase().contains('empty response from ecocash')) {
            return TransactionResponse(
              referenceNumber: effectiveSourceReference,
              pollUrl: '',
              redirectUrl: '',
            );
          }
          throw Exception(message.isEmpty ? 'Direct EcoCash failed' : message);
        }

        final referenceNumber = _firstNonEmptyString(
          [
            data['reference'],
            data['sourceReference'],
            data['paymentId'],
            effectiveSourceReference,
          ],
        );

        return TransactionResponse(
          referenceNumber: referenceNumber,
          pollUrl: _firstNonEmptyString([data['poll_url'], data['pollUrl']]),
          redirectUrl:
              _firstNonEmptyString([data['redirect_url'], data['redirectUrl']]),
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Direct EcoCash error: $e');
    }
  }

  Future<TransactionResponse> checkTransactionStatus(
    String pollUrl, {
    String provider = 'pesepay',
  }) async {
    try {
      final encodedUrl = Uri.encodeComponent(pollUrl);
      final endpoint = 'payments/$provider/status/$encodedUrl';

      final response = await _client.get(_endpointUri(endpoint));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TransactionResponse(
          referenceNumber: data['reference'] ?? '',
          pollUrl: pollUrl,
        );
      } else {
        throw Exception('Status check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Status check error: $e');
    }
  }

  Future<List<PaymentMethod>> getPaymentMethods(String currencyCode) async {
    // For now keep this simplified or fetch from a dedicated metadata endpoint if you add one
    return [
      PaymentMethod(
        code: 'PESE_DEFAULT',
        name: 'Pesepay',
        active: true,
        currencies: [],
        description: 'Pay with Pesepay (Visa/Mastercard/EcoCash)',
        id: 1,
        maximumAmount: 100000.0,
        minimumAmount: 1.0,
        processingPaymentMessage: 'Processing Pesepay...',
        redirectRequired: true,
      ),
      PaymentMethod(
        code: 'PZW201',
        name: 'Ecocash (Direct)',
        active: true,
        currencies: [],
        description: 'Ecocash via direct EcoCash endpoint',
        id: 201,
        maximumAmount: 100000.0,
        minimumAmount: 1.0,
        processingPaymentMessage: 'Processing Ecocash...',
        redirectRequired: false,
      ),
    ];
  }

  Future<List<Currency>> getActiveCurrencies() async {
    return [
      Currency(
        code: 'USD',
        name: 'US Dollar',
        active: true,
        defaultCurrency: true,
        description: 'US Dollar',
        rateToDefault: 1.0,
      ),
    ];
  }

  // Process payment for booking
  Future<bool> processPayment({
    required double amount,
    required String currency,
    required String bookingId,
  }) async {
    // This would integrate with actual payment processing
    // For now, return success
    return true;
  }
}
