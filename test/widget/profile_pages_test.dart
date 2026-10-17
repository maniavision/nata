import 'package:carrywise_app/screens/identity_status_screen.dart';
import 'package:carrywise_app/screens/identity_verification_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:carrywise_app/screens/sealed_box_policy_screen.dart';
import 'package:carrywise_app/screens/wallet_history_screen.dart';
import 'package:carrywise_app/services/emergency_contact_service.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The pages Profile opens: identity status, wallet history, the sealed box
/// policy and the emergency contact.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Map<String, dynamic> profile(String status, {double? rating}) => {
    'id': 'me',
    'first_name': 'Fortune',
    'last_name': 'Niama',
    'verification_status': status,
    'created_at': '2025-03-01T10:00:00+00:00',
    'avg_rating': rating,
  };

  group('Profile', () {
    Future<FakeEmergencyContactService> pumpProfile(
      WidgetTester tester, {
      String status = 'verified',
      double? rating,
      EmergencyContact? contact,
      FakeTravelerService? travelers,
    }) async {
      tallScreen(tester);
      final emergency = FakeEmergencyContactService()..existing = contact;
      await tester.pumpWidget(
        appWrapper(
          ProfileScreen(
            authService: FakeAuthService()
              ..profile = profile(status, rating: rating),
            emergencyService: emergency,
            travelerService: travelers ?? FakeTravelerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return emergency;
    }

    testWidgets('shows the real rating and review count', (tester) async {
      await pumpProfile(
        tester,
        rating: 4.75,
        travelers: FakeTravelerService()..reviewTotal = 12,
      );

      expect(find.text('4.8 '), findsOneWidget);
      expect(find.text('(12)'), findsOneWidget);
      expect(find.text('5.0 '), findsNothing);
    });

    testWidgets('no rating yet says so', (tester) async {
      await pumpProfile(tester);

      expect(find.text('No reviews yet'), findsOneWidget);
    });

    testWidgets('no settings gear that does nothing', (tester) async {
      await pumpProfile(tester);

      expect(find.byIcon(Icons.settings_rounded), findsNothing);
    });

    for (final (status, title) in [
      ('verified', 'Your identity is verified'),
      ('pending', "We're checking your ID"),
    ]) {
      testWidgets('$status: Identity Verification shows the status', (
        tester,
      ) async {
        await pumpProfile(tester, status: status);

        await tester.tap(find.text('Identity Verification'));
        await tester.pumpAndSettle();

        expect(find.byType(IdentityStatusScreen), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.byType(IdentityVerificationScreen), findsNothing);
      });
    }

    testWidgets('unverified: Identity Verification starts the ID upload', (
      tester,
    ) async {
      await pumpProfile(tester, status: 'unverified');

      await tester.tap(find.text('Identity Verification'));
      await tester.pumpAndSettle();

      expect(find.byType(IdentityVerificationScreen), findsOneWidget);
    });

    testWidgets('View History opens the wallet history', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.byKey(const ValueKey('wallet-view-history')));
      await tester.pumpAndSettle();

      expect(find.byType(WalletHistoryScreen), findsOneWidget);
    });

    testWidgets('Sealed Box Policy opens the policy', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('Sealed Box Policy'));
      await tester.pumpAndSettle();

      expect(find.byType(SealedBoxPolicyScreen), findsOneWidget);
      expect(find.text('Why items travel sealed'), findsOneWidget);
    });

    testWidgets('emergency contact: add one from Profile', (tester) async {
      final service = await pumpProfile(tester);
      expect(find.text('Add someone we can reach'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-emergency-contact')));
      await tester.pumpAndSettle();
      expect(find.byType(EmergencyContactScreen), findsOneWidget);
      expect(find.text('Save contact'), findsOneWidget);
      expect(find.text('Step 2 of 2'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('contact-name')),
        'Ama Mensah',
      );
      await tester.enterText(
        find.byKey(const ValueKey('contact-phone')),
        '7700 900123',
      );
      await tester.tap(find.byKey(const ValueKey('contact-rel-relative')));
      await tester.tap(find.byKey(const ValueKey('contact-finish')));
      await tester.pumpAndSettle();

      expect(service.saved.single.fullName, 'Ama Mensah');
      expect(service.saved.single.relationship, EmergencyRelationship.relative);
      expect(find.byType(EmergencyContactScreen), findsNothing);
      expect(find.text('Emergency contact saved.'), findsOneWidget);
      expect(find.text('Ama Mensah'), findsOneWidget);
    });

    testWidgets('emergency contact: the saved one is filled in', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        contact: const EmergencyContact(
          fullName: 'Kofi Boateng',
          phone: '+447700900123',
          relationship: EmergencyRelationship.colleague,
        ),
      );
      expect(find.text('Kofi Boateng'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-emergency-contact')));
      await tester.pumpAndSettle();

      final name = tester.widget<TextField>(
        find.byKey(const ValueKey('contact-name')),
      );
      expect(name.controller!.text, 'Kofi Boateng');
    });
  });

  group('Identity status', () {
    Future<void> pumpStatus(WidgetTester tester, {required bool verified}) {
      tallScreen(tester);
      return tester.pumpWidget(
        appWrapper(
          IdentityStatusScreen(
            verified: verified,
            loadVerification: () async => {
              'status': verified ? 'verified' : 'pending',
              'id_document_type': 'national_id',
              'updated_at': '2025-03-10T09:00:00Z',
              'verified_at': verified ? '2025-03-12T09:00:00Z' : null,
            },
          ),
        ),
      );
    }

    testWidgets('verified: the document, face match and date', (tester) async {
      await pumpStatus(tester, verified: true);
      await tester.pumpAndSettle();

      expect(find.text('Your identity is verified'), findsOneWidget);
      expect(find.text('National ID'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('12 Mar 2025'), findsOneWidget);
      expect(find.textContaining('Tier'), findsNothing);
    });

    testWidgets('under review: received and in review', (tester) async {
      await pumpStatus(tester, verified: false);
      await tester.pumpAndSettle();

      expect(find.text("We're checking your ID"), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('In review'), findsOneWidget);
      expect(find.text('10 Mar 2025'), findsOneWidget);
    });
  });

  group('Wallet history', () {
    WalletEntry entry(
      WalletEntryKind kind,
      WalletEntryStatus status,
      DateTime date, {
      String item = 'iPad Mini',
      double amount = 45,
    }) => WalletEntry(
      kind: kind,
      id: '$kind$date',
      amount: amount,
      currency: 'USD',
      status: status,
      date: date,
      item: item,
      fromCity: 'Lagos',
      toCity: 'London',
      otherName: 'Amara',
    );

    Future<FakePaymentService> pumpHistory(
      WidgetTester tester,
      List<WalletEntry> history, {
      bool fail = false,
    }) async {
      tallScreen(tester);
      final service = FakePaymentService()
        ..history = history
        ..failHistory = fail;
      await tester.pumpWidget(
        appWrapper(
          WalletHistoryScreen(
            available: r'$320.00',
            inEscrow: r'$150.00',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return service;
    }

    final june = DateTime(2025, 6, 24);
    final may = DateTime(2025, 5, 30);

    testWidgets('payouts and payments, grouped by month', (tester) async {
      await pumpHistory(tester, [
        entry(WalletEntryKind.payout, WalletEntryStatus.paid, june),
        entry(
          WalletEntryKind.payment,
          WalletEntryStatus.inEscrow,
          may,
          item: 'Shoes',
          amount: 50,
        ),
      ]);

      expect(find.text(r'$320.00'), findsOneWidget);
      expect(find.text('June 2025'), findsOneWidget);
      expect(find.text('May 2025'), findsOneWidget);
      expect(find.text('Payout · iPad Mini'), findsOneWidget);
      expect(find.text(r'+$45'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Payment · Shoes'), findsOneWidget);
      expect(find.text(r'−$50'), findsOneWidget);
      expect(find.text('In escrow'), findsWidgets);
      expect(find.textContaining('Delivery request to Amara'), findsOneWidget);
    });

    testWidgets('the filters', (tester) async {
      await pumpHistory(tester, [
        entry(WalletEntryKind.payout, WalletEntryStatus.paid, june),
        entry(
          WalletEntryKind.payment,
          WalletEntryStatus.released,
          may,
          item: 'Shoes',
        ),
      ]);

      await tester.tap(find.byKey(const ValueKey('wallet-filter-payments')));
      await tester.pump();
      expect(find.text('Payout · iPad Mini'), findsNothing);
      expect(find.text('Payment · Shoes'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('wallet-filter-payouts')));
      await tester.pump();
      expect(find.text('Payout · iPad Mini'), findsOneWidget);
      expect(find.text('Payment · Shoes'), findsNothing);
    });

    testWidgets('empty', (tester) async {
      await pumpHistory(tester, []);

      expect(
        find.byKey(const ValueKey('wallet-history-empty')),
        findsOneWidget,
      );
    });

    testWidgets('an error, then retry', (tester) async {
      final service = await pumpHistory(tester, [], fail: true);
      expect(find.text("Couldn't load your history."), findsOneWidget);

      service
        ..failHistory = false
        ..history = [
          entry(WalletEntryKind.payout, WalletEntryStatus.sending, june),
        ];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Sending'), findsOneWidget);
    });
  });
}
