import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../l10n/l10n_ext.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';

/// 6-digit OTP verification screen.
///
/// [phone]       — E.164 phone number (e.g. "+2348034567890")
/// [isSignUp]    — true = new account (also saves firstName/lastName to profile)
/// [firstName]   — only used when isSignUp = true
/// [lastName]    — only used when isSignUp = true
/// [onSuccess]   — callback after successful verification (navigate to next screen)
class OtpScreen extends StatefulWidget {
  final String phone;
  final bool isSignUp;
  final String firstName;
  final String lastName;
  final VoidCallback onSuccess;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.isSignUp,
    this.firstName = '',
    this.lastName = '',
    required this.onSuccess,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _digitCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focus = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  String? _error;

  // Resend countdown
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _digitCtrl) c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────
  void _startTimer() {
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  // ── OTP helpers ────────────────────────────────────────────────────────────
  String get _otp => _digitCtrl.map((c) => c.text).join();
  bool get _otpComplete => _otp.length == 6;

  void _onDigitChanged(int index, String value) {
    setState(() => _error = null);
    if (value.length == 1 && index < 5) {
      _focus[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focus[index - 1].requestFocus();
    }
    // Auto-submit when last digit filled
    if (index == 5 && value.isNotEmpty) {
      _verify();
    }
  }

  // ── Verify ─────────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (!_otpComplete || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await AuthService().verifyOtp(widget.phone, _otp);

      if (response.session != null) {
        final prefs = PreferencesService();
        if (widget.isSignUp) {
          // Save name + preferences to DB for new users
          if (widget.firstName.isNotEmpty || widget.lastName.isNotEmpty) {
            await AuthService().updateProfile(
              firstName: widget.firstName,
              lastName: widget.lastName,
            );
          }
          // Save language, currency, country to profile
          await prefs.saveToProfile();
        } else {
          // Sign-in: load saved preferences from DB and apply to app
          await prefs.loadFromProfile();
        }
        if (mounted) widget.onSuccess();
      } else {
        setState(() {
          _error = 'Verification failed. Please try again.';
          _loading = false;
        });
        _clearBoxes();
      }
    } on AuthException catch (e) {
      debugPrint('[OtpScreen] AuthException: code=${e.code} msg=${e.message}');
      setState(() {
        _error = _friendlyAuthError(e);
        _loading = false;
      });
      _clearBoxes();
    } catch (e) {
      debugPrint('[OtpScreen] Unknown error: $e');
      setState(() {
        _error = _friendlyError(e.toString());
        _loading = false;
      });
      _clearBoxes();
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await AuthService().sendOtp(widget.phone);
      _clearBoxes();
      _startTimer();
    } on Exception catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearBoxes() {
    for (final c in _digitCtrl) c.clear();
    if (mounted) _focus[0].requestFocus();
  }

  /// Handles Supabase AuthException specifically with known error codes.
  String _friendlyAuthError(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'otp_expired' || msg.contains('expired')) {
      return 'Code expired. Please request a new one.';
    }
    if (code == 'otp_disabled') {
      return 'Phone verification is not enabled. Please contact support.';
    }
    if (code == 'user_not_found' || code == 'invalid_credentials') {
      return 'Incorrect code. Please try again.';
    }
    if (code == 'over_sms_send_rate_limit' || msg.contains('rate limit')) {
      return 'Too many attempts. Please wait before retrying.';
    }
    return _friendlyError(e.message);
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('expired') || lower.contains('token has expired')) {
      return 'Code expired. Please request a new one.';
    }
    if (lower.contains('invalid') || lower.contains('incorrect') ||
        lower.contains('wrong') || lower.contains('otp') ||
        lower.contains('token')) {
      return 'Incorrect code. Please try again.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait before retrying.';
    }
    if (lower.contains('network') || lower.contains('socket') ||
        lower.contains('connection')) {
      return 'Network error. Please check your connection.';
    }
    // Show the raw message in a friendly way for unknown errors
    return 'Incorrect code or code expired. Please try again.';
  }

  // ── Formatted phone display ────────────────────────────────────────────────
  String get _displayPhone {
    // Show last 4 digits masked: +234 *** *** 7890
    final p = widget.phone;
    if (p.length > 4) {
      return '${p.substring(0, p.length - 4)}****';
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.sms_rounded,
                          size: 30, color: AppColors.accent),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Enter verification code',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: AppColors.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppColors.mutedForeground,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit code to '),
                          TextSpan(
                            text: _displayPhone,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // OTP boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) => _buildDigitBox(i)),
                    ),
                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.destructive.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.destructive.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 16, color: AppColors.destructive),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: AppColors.destructive,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_otpComplete && !_loading) ? _verify : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          disabledBackgroundColor:
                              AppColors.muted,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor:
                              AppColors.accent.withValues(alpha: 0.4),
                          shape: const StadiumBorder(),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white),
                              )
                            : Text(
                                'Verify Code',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Resend
                    Center(
                      child: _secondsLeft > 0
                          ? RichText(
                              text: TextSpan(
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: AppColors.mutedForeground,
                                ),
                                children: [
                                  const TextSpan(text: 'Resend code in '),
                                  TextSpan(
                                    text: '${_secondsLeft}s',
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: _resend,
                              child: Text(
                                'Resend code',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.accent,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.accent,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 28),
                    // Info note
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.mutedForeground),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Didn\'t receive the code? Check that your phone number is correct and that you have network coverage.',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AppColors.mutedForeground,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.foreground, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Verify Phone',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitBox(int index) {
    final filled = _digitCtrl[index].text.isNotEmpty;
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _digitCtrl[index],
        focusNode: _focus[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.jetBrainsMono(
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: AppColors.primary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: filled
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.input,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _error != null
                  ? AppColors.destructive
                  : filled
                      ? AppColors.primary
                      : AppColors.border,
              width: filled || _error != null ? 2 : 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _error != null
                  ? AppColors.destructive
                  : filled
                      ? AppColors.primary
                      : AppColors.border,
              width: filled || _error != null ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  _error != null ? AppColors.destructive : AppColors.accent,
              width: 2,
            ),
          ),
        ),
        onChanged: (v) => _onDigitChanged(index, v),
      ),
    );
  }
}
