import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../main.dart';
import 'request_service.dart';

/// How the sender left Stripe's payment sheet.
enum CardSheetResult {
  /// Paid: the payment is confirmed with Stripe next (verify-payment).
  paid,

  /// Closed without paying.
  cancelled,

  /// Stripe couldn't take the payment (the sheet already said why).
  failed,
}

/// Shows Stripe's own payment sheet for [sheet]: card details, and Apple Pay
/// or Google Pay where they're set up, entered in the app and sent straight
/// to Stripe (never to Nata).
Future<CardSheetResult> presentStripeSheet(StripeSheet sheet) async {
  try {
    Stripe.publishableKey = sheet.publishableKey;
    Stripe.merchantIdentifier = sheet.appleMerchantId;
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: sheet.setup ? null : sheet.clientSecret,
        setupIntentClientSecret: sheet.setup ? sheet.clientSecret : null,
        // The member's saved cards, the default first (20240196).
        customerId: sheet.ephemeralKey == null ? null : sheet.customerId,
        customerEphemeralKeySecret: sheet.customerId == null
            ? null
            : sheet.ephemeralKey,
        merchantDisplayName: 'Nata',
        applePay: sheet.appleMerchantId == null
            ? null
            : PaymentSheetApplePay(merchantCountryCode: sheet.merchantCountry),
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: sheet.merchantCountry,
          testEnv: sheet.publishableKey.startsWith('pk_test_'),
        ),
        style: ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: AppColors.accent),
          primaryButton: PaymentSheetPrimaryButtonAppearance(
            colors: PaymentSheetPrimaryButtonTheme(
              light: PaymentSheetPrimaryButtonThemeColors(
                background: AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    return CardSheetResult.paid;
  } on StripeException catch (e) {
    if (e.error.code == FailureCode.Canceled) return CardSheetResult.cancelled;
    debugPrint('[Stripe] ${e.error.code}: ${e.error.message}');
    return CardSheetResult.failed;
  }
}

/// Saves a card in Stripe's sheet ([sheet] in setup mode): true once Stripe
/// saved it, false when closed or refused (the sheet already said why).
Future<bool> presentStripeSetupSheet(StripeSheet sheet) async =>
    await presentStripeSheet(sheet) == CardSheetResult.paid;
