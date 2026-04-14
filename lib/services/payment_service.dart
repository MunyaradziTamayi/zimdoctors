import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pesepay/pesepay.dart'; // Keep for model types if still used by UI

class PaymentService {
  final String _baseUrl = dotenv.env['DISEASE_API_BASE_URL'] ?? 'http://localhost:8000';

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
    if (paymentMethodCode == 'PZW201' || paymentMethodCode == 'PZW202') { // Paynow / EcoCash via Paynow
       endpoint = '/payments/paynow/initiate-mobile';
       body = {
         'amount': amount,
         'phone': customerPhone,
         'email': customerEmail,
         'method': paymentMethodCode == 'PZW201' ? 'ecocash' : 'onemoney',
       };
    } else if (paymentMethodCode.startsWith('PESE')) { // Assuming a prefix for Pesepay
       endpoint = '/payments/pesepay/initiate';
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
       endpoint = '/payments/pesepay/initiate';
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
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return TransactionResponse(
            referenceNumber: data['transaction_reference'] ?? data['poll_url'] ?? '',
            pollUrl: data['poll_url'] ?? '',
            redirectUrl: data['redirect_url'] ?? '',
          );
        } else {
          throw Exception(data['message'] ?? 'Payment initiation failed');
        }
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
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payments/ecocash-direct/sandbox'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customerMsisdn': phone,
          'amount': amount,
          'reason': reason,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return TransactionResponse(
          referenceNumber: data['reference'] ?? '',
          pollUrl: '', // No poll URL for direct sandbox usually
        );
      } else {
        throw Exception(data['message'] ?? 'Direct EcoCash failed');
      }
    } catch (e) {
      throw Exception('Direct EcoCash error: $e');
    }
  }

  Future<TransactionResponse> checkTransactionStatus(String pollUrl, {String provider = 'pesepay'}) async {
    try {
      final encodedUrl = Uri.encodeComponent(pollUrl);
      final endpoint = '/payments/$provider/status/$encodedUrl';
      
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
      );

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
        name: 'Ecocash (Paynow)',
        active: true,
        currencies: [],
        description: 'Ecocash via Paynow',
        id: 201,
        maximumAmount: 100000.0,
        minimumAmount: 1.0,
        processingPaymentMessage: 'Processing Ecocash...',
        redirectRequired: false,
      ),
    ];
  }

  Future<List<Currency>> getActiveCurrencies() async {
    return [Currency(
      code: 'USD',
      name: 'US Dollar',
      active: true,
      defaultCurrency: true,
      description: 'US Dollar',
      rateToDefault: 1.0,
    )];
  }
}

