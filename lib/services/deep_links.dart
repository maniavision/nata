import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_ext.dart';
import '../screens/recipient_chat_screen.dart';
import '../widgets/nata_toast.dart';
import 'auth_gate.dart';
import 'request_service.dart';

/// Links into the app (universal links on iOS, app links on Android) from
/// nata-app-a03de.web.app. A recipient's link (/r/<token>) opens their chat
/// with the traveler in the app when they're signed in; they take the link,
/// and the chat then lives in their Messages (20240186). Otherwise the page
/// opens inside the app.
class DeepLinks {
  DeepLinks._();
  static final DeepLinks instance = DeepLinks._();

  static const host = 'nata-app-a03de.web.app';

  GlobalKey<NavigatorState>? _navigator;
  StreamSubscription<Uri>? _links;

  /// Replaced in tests.
  RequestService Function() requests = RequestService.new;

  Future<void> start(GlobalKey<NavigatorState> navigator) async {
    _navigator = navigator;
    try {
      final links = AppLinks();
      _links = links.uriLinkStream.listen(open);
    } catch (e) {
      debugPrint('[DeepLinks] unavailable: $e');
    }
  }

  /// The recipient token in [uri], if it is a recipient link.
  static String? recipientToken(Uri uri) {
    if (uri.host != host || uri.pathSegments.length < 2) return null;
    if (uri.pathSegments.first != 'r') return null;
    final token = uri.pathSegments[1].trim();
    return token.isEmpty ? null : token;
  }

  Future<void> open(Uri uri) async {
    final token = recipientToken(uri);
    if (token == null) return;
    // Let the first screen settle on a cold start.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final navigator = _navigator?.currentState;
    final context = _navigator?.currentContext;
    if (navigator == null || context == null) return;
    if (!AuthGate.isSignedIn()) {
      await _openPage(uri);
      return;
    }
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final requestId = await requests().claimRecipientLink(token);
      await navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              RecipientChatScreen(requestId: requestId, asRecipient: true),
        ),
      );
    } on RecipientLinkException catch (e) {
      switch (e.problem) {
        case RecipientLinkProblem.notRecipient:
          messenger?.showSnackBar(nataToast(l.linkForRecipient));
        case RecipientLinkProblem.taken:
          // Someone else's: the page still works.
          await _openPage(uri);
        case RecipientLinkProblem.invalid:
          messenger?.showSnackBar(
            nataToast(l.linkNoLongerWorks, tone: ToastTone.error),
          );
      }
    } catch (e) {
      debugPrint('[DeepLinks] recipient link: $e');
      await _openPage(uri);
    }
  }

  /// The web page, inside the app (an in-app browser doesn't send the link
  /// back to the app).
  Future<void> _openPage(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      debugPrint('[DeepLinks] page: $e');
    }
  }

  Future<void> dispose() async => _links?.cancel();
}
