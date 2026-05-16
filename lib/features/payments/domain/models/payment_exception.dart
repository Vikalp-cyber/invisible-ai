/// Payment flow failures (create-link, browser checkout, subscription polling).
class PaymentException implements Exception {
  PaymentException(this.message, {this.code, this.httpStatus});

  final String message;
  final String? code;
  final int? httpStatus;

  @override
  String toString() => message;
}

class PaymentCancelledException extends PaymentException {
  PaymentCancelledException([super.message = 'Payment was cancelled.'])
      : super(code: 'cancelled');
}

class PaymentTimeoutException extends PaymentException {
  PaymentTimeoutException([
    super.message =
        'Payment was not confirmed in time. If you paid, wait a moment and tap Retry.',
  ]) : super(code: 'timeout');
}

class PaymentCheckoutUnavailableException extends PaymentException {
  PaymentCheckoutUnavailableException([
    super.message = 'Could not open the payment page in your browser.',
  ]) : super(code: 'checkout_unavailable');
}

/// HTTP 409 — user already has an active premium subscription.
class PremiumAlreadyActiveException extends PaymentException {
  PremiumAlreadyActiveException([
    super.message = 'You already have Flowdesk Premium.',
  ]) : super(code: 'PREMIUM_ALREADY_ACTIVE', httpStatus: 409);
}
