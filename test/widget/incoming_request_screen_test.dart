import 'package:carrywise_app/screens/incoming_request_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The traveler's view of one request: review it, then accept or decline.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;
  final now = DateTime(2030, 6, 20, 12);
  bool? popped;

  setUp(() {
    service = FakeRequestService();
    popped = null;
  });

  Future<void> pump(WidgetTester tester, IncomingRequest request) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    service.incoming = [request];
    await tester.pumpWidget(
      appWrapper(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => IncomingRequestScreen(
                      request: request,
                      service: service,
                      now: () => now,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the sender, payout, trip, items and photos', (
    tester,
  ) async {
    await pump(
      tester,
      sampleIncoming(
        items: const [
          RequestItem(
            name: 'Apple Watch Series 9',
            category: RequestCategory.electronics,
            description: 'Sealed box',
          ),
          RequestItem(
            name: 'Scarf',
            category: RequestCategory.apparel,
            description: '',
          ),
        ],
        expiresAt: now.add(const Duration(hours: 23, minutes: 10)),
      ),
    );

    expect(find.text('Request Details'), findsOneWidget);
    expect(find.text('Chioma Eze'), findsOneWidget);
    expect(find.byKey(const ValueKey('sender-verified')), findsOneWidget);
    expect(find.text('Sender · 5 deliveries'), findsOneWidget);
    expect(find.text(r'$32'), findsOneWidget);
    expect(find.text('Lagos → London'), findsOneWidget);
    expect(find.text('Jun 22, 2030'), findsOneWidget);
    expect(find.text('0.45 kg · Shoebox · 15 x 8 x 4 cm'), findsOneWidget);
    expect(find.text('Apple Watch Series 9'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);
    expect(find.text('Sealed box'), findsOneWidget);
    expect(find.text('Scarf'), findsOneWidget);
    expect(find.byKey(const ValueKey('incoming-photo-0')), findsOneWidget);
    expect(find.text('Answer within 23h 10m'), findsOneWidget);
  });

  testWidgets('the recipient stays hidden until accepted', (tester) async {
    await pump(tester, sampleIncoming());

    expect(find.byKey(const ValueKey('recipient-hidden')), findsOneWidget);
    expect(find.text('David Adeleke'), findsNothing);
  });

  testWidgets('once accepted: the recipient, no answer buttons', (
    tester,
  ) async {
    await pump(tester, sampleIncoming(status: 'paid'));

    expect(find.text('David Adeleke'), findsOneWidget);
    expect(find.text('+447700900456'), findsOneWidget);
    expect(find.byKey(const ValueKey('incoming-accept')), findsNothing);
    expect(find.byKey(const ValueKey('incoming-decline')), findsNothing);
  });

  testWidgets('Accept answers it and goes back with a change', (tester) async {
    await pump(tester, sampleIncoming());

    await tester.tap(find.byKey(const ValueKey('incoming-accept')));
    await tester.pumpAndSettle();

    expect(service.accepted, ['in-1']);
    expect(popped, isTrue);
  });

  testWidgets('Decline asks, then answers it', (tester) async {
    await pump(tester, sampleIncoming());

    await tester.tap(find.byKey(const ValueKey('incoming-decline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-confirm')));
    await tester.pumpAndSettle();

    expect(service.declined.single, (id: 'in-1', reason: null));
    expect(popped, isTrue);
  });

  testWidgets('a refused accept stays on the screen and says why', (
    tester,
  ) async {
    service.failAnswer = const RequestException(RequestFailure.rateUnavailable);
    await pump(tester, sampleIncoming());

    await tester.tap(find.byKey(const ValueKey('incoming-accept')));
    await tester.pumpAndSettle();

    expect(find.byType(IncomingRequestScreen), findsOneWidget);
    expect(
      find.textContaining("exchange rate isn't available"),
      findsOneWidget,
    );
  });

  testWidgets('is translated', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        IncomingRequestScreen(
          request: sampleIncoming(),
          service: service,
          now: () => now,
        ),
        locale: const Locale('es'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalles de la solicitud'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });
}
