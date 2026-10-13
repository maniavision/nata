import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'country_service.dart';
import 'preferences_service.dart';

/// The country the app is being used in, with the language and currency that
/// usually go with it.
class DetectedRegion {
  final String isoCode;
  final String countryName;
  final AppLanguage language;
  final AppCurrency currency;

  const DetectedRegion({
    required this.isoCode,
    required this.countryName,
    required this.language,
    required this.currency,
  });
}

/// What the user allowed this app to do with their location.
enum LocationAccess { granted, denied, deniedForever }

/// The device's location, behind a small interface so the rest of the logic can
/// be tested without a phone.
abstract class DeviceLocation {
  /// Is location switched on in the device settings?
  Future<bool> isServiceEnabled();

  /// The current permission, without asking the user anything.
  Future<LocationAccess> access();

  /// Asks the user for permission (shows the system prompt).
  Future<LocationAccess> requestAccess();

  /// The country the device is in right now, or null if it cannot be found.
  Future<({String isoCode, String? name})?> country();
}

/// [DeviceLocation] on a real phone (geolocator + geocoding).
class PhoneLocation implements DeviceLocation {
  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  LocationAccess _map(LocationPermission p) {
    switch (p) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationAccess.granted;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
    }
  }

  @override
  Future<LocationAccess> access() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<LocationAccess> requestAccess() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<({String isoCode, String? name})?> country() async {
    // A rough, recent position is plenty to know the country, and is quick.
    final position =
        await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
    final places = await Geocoding().placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    for (final p in places) {
      final iso = p.isoCountryCode?.trim();
      if (iso != null && iso.length == 2) {
        return (isoCode: iso.toUpperCase(), name: p.country);
      }
    }
    return null;
  }
}

/// Finds the country the app is used in, and suggests a language and currency.
class RegionService {
  final DeviceLocation _device;

  RegionService({DeviceLocation? device}) : _device = device ?? PhoneLocation();

  /// The detected region, or null when it cannot be known: location is switched
  /// off, the user did not allow it, or the country could not be found.
  /// Never throws.
  Future<DetectedRegion?> detect() async {
    try {
      if (!await _device.isServiceEnabled()) return null;

      var access = await _device.access();
      if (access == LocationAccess.denied) {
        access = await _device.requestAccess();
      }
      if (access != LocationAccess.granted) return null;

      final found = await _device.country();
      if (found == null) return null;

      final iso = found.isoCode.trim().toUpperCase();
      final known = await CountryService().byIsoCode(iso);
      final name = (known?.name.isNotEmpty ?? false)
          ? known!.name
          : ((found.name?.trim().isNotEmpty ?? false)
                ? found.name!.trim()
                : iso);

      return DetectedRegion(
        isoCode: iso,
        countryName: name,
        language: languageForCountry(iso),
        currency: currencyForCountry(iso),
      );
    } catch (e) {
      debugPrint('[RegionService] could not detect the country: $e');
      return null;
    }
  }

  static const _spanish = {
    'ES',
    'MX',
    'AR',
    'CO',
    'CL',
    'PE',
    'VE',
    'EC',
    'GT',
    'CU',
    'BO',
    'DO',
    'HN',
    'PY',
    'SV',
    'NI',
    'CR',
    'PA',
    'UY',
    'PR',
    'GQ',
  };

  static const _french = {
    'FR',
    'MC',
    'SN',
    'CI',
    'CM',
    'CD',
    'CG',
    'GA',
    'BF',
    'ML',
    'NE',
    'TG',
    'BJ',
    'GN',
    'MG',
    'BI',
    'DJ',
    'TD',
    'CF',
    'KM',
    'HT',
  };

  static const _euro = {
    'AT',
    'BE',
    'CY',
    'EE',
    'FI',
    'FR',
    'DE',
    'GR',
    'IE',
    'IT',
    'LV',
    'LT',
    'LU',
    'MT',
    'NL',
    'PT',
    'SK',
    'SI',
    'ES',
    'HR',
    'MC',
    'SM',
    'VA',
    'AD',
  };

  static const _westAfricanFranc = {
    'SN',
    'CI',
    'BF',
    'ML',
    'NE',
    'TG',
    'BJ',
    'GW',
  };

  /// African countries and territories (ISO 3166-1 alpha-2).
  static const _africa = {
    'DZ',
    'AO',
    'BJ',
    'BW',
    'BF',
    'BI',
    'CV',
    'CM',
    'CF',
    'TD',
    'KM',
    'CG',
    'CD',
    'CI',
    'DJ',
    'EG',
    'GQ',
    'ER',
    'SZ',
    'ET',
    'GA',
    'GM',
    'GH',
    'GN',
    'GW',
    'KE',
    'LS',
    'LR',
    'LY',
    'MG',
    'MW',
    'ML',
    'MR',
    'MU',
    'MA',
    'MZ',
    'NA',
    'NE',
    'NG',
    'RW',
    'ST',
    'SN',
    'SC',
    'SL',
    'SO',
    'ZA',
    'SS',
    'SD',
    'TZ',
    'TG',
    'TN',
    'UG',
    'ZM',
    'ZW',
    'EH',
    'RE',
    'YT',
    'SH',
  };

  /// South American countries and territories (ISO 3166-1 alpha-2).
  static const _southAmerica = {
    'AR',
    'BO',
    'BR',
    'CL',
    'CO',
    'EC',
    'GY',
    'PY',
    'PE',
    'SR',
    'UY',
    'VE',
    'GF',
    'FK',
  };

  /// True for a country in Africa or South America.
  static bool isAfricanOrSouthAmerican(String isoCode) {
    final iso = isoCode.trim().toUpperCase();
    return _africa.contains(iso) || _southAmerica.contains(iso);
  }

  /// The app's language for a country (English unless Spanish or French is the
  /// usual language there).
  static AppLanguage languageForCountry(String isoCode) {
    final iso = isoCode.trim().toUpperCase();
    if (_spanish.contains(iso)) return AppLanguage.spanish;
    if (_french.contains(iso)) return AppLanguage.french;
    return AppLanguage.english;
  }

  /// The app's currency for a country (the app offers USD, EUR, GBP and XOF;
  /// anywhere else defaults to USD).
  static AppCurrency currencyForCountry(String isoCode) {
    final iso = isoCode.trim().toUpperCase();
    if (iso == 'GB') return AppCurrency.gbp;
    if (_westAfricanFranc.contains(iso)) return AppCurrency.xof;
    if (_euro.contains(iso)) return AppCurrency.eur;
    return AppCurrency.usd;
  }
}
