import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Puts a phone number typed in its national form into international form
/// (+<country code><number>), using each country's own numbering rules.
///
/// In most countries a leading 0 is only dialled at home and is dropped
/// abroad (Nigeria 0803... -> +234 803..., UK 07911... -> +44 7911...). In
/// some it is part of the number and stays (Congo-Brazzaville 06 877 7804
/// -> +242 06 877 7804, also Côte d'Ivoire, Benin, Italy). The rules come
/// from Google's libphonenumber metadata (phone_numbers_parser).
///
/// [dialCode] is the country's code ("+242" or "242"); [isoCode] its
/// two-letter code when known ("CG"), which settles shared codes like +1.
/// A number typed with its own "+" code is kept as typed. Returns null when
/// there are no digits.
String? internationalPhoneNumber({
  required String dialCode,
  required String input,
  String? isoCode,
}) {
  final typed = input.trim();
  final code = dialCode.replaceAll(RegExp(r'\D'), '');
  if (typed.startsWith('+')) {
    final digits = typed.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : '+$digits';
  }
  var local = typed.replaceAll(RegExp(r'\D'), '');
  if (local.isEmpty) return null;
  // Typed with the country code but no "+" (2420687...).
  if (code.isNotEmpty && local.startsWith('00$code')) {
    local = local.substring(2 + code.length);
  }

  final keep = '+$code$local';
  final dropped = '+$code${local.replaceFirst(RegExp(r'^0+'), '')}';
  if (keep == dropped) return keep;

  bool valid(String e164) {
    try {
      final p = PhoneNumber.parse(e164);
      if (isoCode != null && isoCode.length == 2) {
        final iso = IsoCode.values.where(
          (c) => c.name == isoCode.toUpperCase(),
        );
        if (iso.isNotEmpty && p.isoCode != iso.first) return false;
      }
      return p.isValid();
    } catch (_) {
      return false;
    }
  }

  // Whichever form the country's rules accept; the usual "drop the 0" when
  // neither is recognised.
  if (valid(keep) && !valid(dropped)) return keep;
  return dropped;
}
