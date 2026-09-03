import 'dart:async';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/enums/transaction_status.dart';
import 'mock_data.dart';

class MockConversionService {
  Future<ConversionQuote> getQuote({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final rate = MockData.exchangeRate;
    final feeAmount = amount * (rate.fee / 100);
    final netAmount = (amount - feeAmount) / rate.rate;

    return ConversionQuote(
      inputAmount: amount,
      inputCurrency: fromCurrency,
      outputAmount: netAmount,
      outputCurrency: toCurrency,
      rate: rate.rate,
      fee: rate.fee,
      feeAmount: feeAmount,
      expiresAt: rate.expiresAt,
    );
  }

  Future<Transaction> executeConversion(ConversionQuote quote) async {
    await Future.delayed(AppConstants.mockLongDelay);
    return Transaction(
      id: 'cnv_${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.conversion,
      amount: quote.inputAmount,
      currency: quote.inputCurrency,
      status: TransactionStatus.completed,
      date: DateTime.now(),
      reference: 'CNV-${DateTime.now().millisecondsSinceEpoch}',
      fromCurrency: quote.inputCurrency,
      toCurrency: quote.outputCurrency,
      convertedAmount: quote.outputAmount,
      exchangeRate: quote.rate,
      fee: quote.feeAmount,
    );
  }
}
