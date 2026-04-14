
import 'package:pesepay/pesepay.dart';

void main() {
  // Testing TransactionResponse
  var tr = TransactionResponse(
    pollUrl: 'test',
    referenceNumber: 'test',
    redirectUrl: 'test',
    // message: 'test', // I suspect this might be missing or named differently
  );
  
  // Testing PaymentMethod
  var pm = PaymentMethod(
    code: 'test',
    name: 'test',
    redirectRequired: true,
    active: true,
    currencies: [],
    description: 'test',
    id: 1, // Changed to int
    maximumAmount: 100.0,
    minimumAmount: 1.0,
    processingPaymentMessage: 'test',
  );
  
  // Testing Currency
  var cur = Currency(
    code: 'test',
    name: 'test',
    active: true,
    defaultCurrency: false,
    description: 'test',
    rateToDefault: 1.0,
  );

  print(tr.referenceNumber);
  print(tr.redirectUrl);
  print(tr.pollUrl);
}
