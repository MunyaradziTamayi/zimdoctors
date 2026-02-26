import 'package:pesepay/pesepay.dart';

class PaymentService {
  // These should be configured in a secure way, but for now we use placeholders
  static const String integrationKey = "612cfd0e-1757-48bb-8209-cb1a3141e280";
  static const String encryptionKey = "6fa767d43ea54ea2a76c3322c0c795ff";
  static const String resultUrl = "https://zimdoctors.com/result";
  static const String returnUrl = "https://zimdoctors.com/return";

  final Pesepay pesepay = Pesepay(
    integrationKey: integrationKey,
    encryptionKey: encryptionKey,
    resultUrl: resultUrl,
    returnUrl: returnUrl,
  );


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
    try {
    
      final seamlessTransaction = pesepay.createSeamlessTransaction(
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        amount: amount,
        currencyCode: currencyCode,
        transactionDescription: transactionDescription,
        transactionReference: transactionReference,
        paymentMethodCode: paymentMethodCode,
      );

   
      final response = await pesepay.initiateSeamlessTransaction(
        seamlessTransaction,
      );

      return response;
    } on PesepayException catch (e) {
      
      throw Exception('Payment failed: ${e.message}');
    } catch (e) {
     
      throw Exception('Payment error: $e');
    }
  }

 
  Future<TransactionResponse> initiateWebPayment({
    required double amount,
    required String currencyCode,
    required String transactionDescription,
    required String transactionReference,
  }) async {
    try {
      
      final transaction = pesepay.createTransaction(
        amount: amount,
        currencyCode: currencyCode,
        transactionDescription: transactionDescription,
        transactionReference: transactionReference,
      );

      
      final response = await pesepay.initiateWebTransaction(transaction);

      return response;
    } on PesepayException catch (e) {
      throw Exception('Payment failed: ${e.message}');
    } catch (e) {
      throw Exception('Payment error: $e');
    }
  }


  Future<TransactionResponse> checkTransactionStatus(String pollUrl) async {
    try {
      return await pesepay.checkTransactionStatus(pollUrl);
    } on PesepayException catch (e) {
      throw Exception('Status check failed: ${e.message}');
    } catch (e) {
      throw Exception('Status check error: $e');
    }
  }

 
  Stream<TransactionResponse> streamTransactionStatus(
    String pollUrl, {
    int intervalSeconds = 5,
  }) {
    return pesepay.streamTransactionResponse(
      pollUrl,
      streamInterval: intervalSeconds,
    );
  }

  Future<List<PaymentMethod>> getPaymentMethods(String currencyCode) async {
    try {

      final currencies = await Pesepay.getActiveCurrencies();
      final currency = currencies.firstWhere((c) => c.code == currencyCode);
      return await Pesepay.getPaymentMethodsByCurrency(currency);
    } catch (e) {
      throw Exception('Failed to get payment methods: $e');
    }
  }

 
  Future<List<Currency>> getActiveCurrencies() async {
    try {
      return await Pesepay.getActiveCurrencies();
    } catch (e) {
      throw Exception('Failed to get currencies: $e');
    }
  }
}
