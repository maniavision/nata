import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Nata'**
  String get appName;

  /// No description provided for @splashTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Language & Currency'**
  String get splashTitle;

  /// No description provided for @splashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize your peer delivery experience across routes worldwide.'**
  String get splashSubtitle;

  /// No description provided for @splashWelcomePill.
  ///
  /// In en, this message translates to:
  /// **'Welcome · Bienvenue · Bienvenido'**
  String get splashWelcomePill;

  /// No description provided for @splashDetectedRegion.
  ///
  /// In en, this message translates to:
  /// **'DETECTED REGION'**
  String get splashDetectedRegion;

  /// No description provided for @splashDetectedValue.
  ///
  /// In en, this message translates to:
  /// **'United States · English & USD'**
  String get splashDetectedValue;

  /// No description provided for @splashQuickApply.
  ///
  /// In en, this message translates to:
  /// **'Quick Apply'**
  String get splashQuickApply;

  /// No description provided for @splashChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE LANGUAGE'**
  String get splashChooseLanguage;

  /// No description provided for @splashPreferredCurrency.
  ///
  /// In en, this message translates to:
  /// **'PREFERRED CURRENCY'**
  String get splashPreferredCurrency;

  /// No description provided for @splashSaveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & Continue'**
  String get splashSaveAndContinue;

  /// No description provided for @splashSettingsNote.
  ///
  /// In en, this message translates to:
  /// **'You can change your language and currency anytime in Profile Settings.'**
  String get splashSettingsNote;

  /// No description provided for @splashAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} available'**
  String splashAvailable(int count);

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langEnglishSub.
  ///
  /// In en, this message translates to:
  /// **'Default · International'**
  String get langEnglishSub;

  /// No description provided for @langSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get langSpanish;

  /// No description provided for @langSpanishSub.
  ///
  /// In en, this message translates to:
  /// **'Spanish · España & LatAm'**
  String get langSpanishSub;

  /// No description provided for @langFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get langFrench;

  /// No description provided for @langFrenchSub.
  ///
  /// In en, this message translates to:
  /// **'French · France & Afrique'**
  String get langFrenchSub;

  /// No description provided for @currUSD.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get currUSD;

  /// No description provided for @currEUR.
  ///
  /// In en, this message translates to:
  /// **'Euro'**
  String get currEUR;

  /// No description provided for @currGBP.
  ///
  /// In en, this message translates to:
  /// **'British Pound'**
  String get currGBP;

  /// No description provided for @currXOF.
  ///
  /// In en, this message translates to:
  /// **'Franc CFA'**
  String get currXOF;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email or Phone'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @faceId.
  ///
  /// In en, this message translates to:
  /// **'Face ID'**
  String get faceId;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// No description provided for @newToNata.
  ///
  /// In en, this message translates to:
  /// **'New to Nata?'**
  String get newToNata;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAccount;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Direct peer deliveries · 100% verified traveler network'**
  String get tagline;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @welcomeBackSub.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage deliveries, routes, and requests.'**
  String get welcomeBackSub;

  /// No description provided for @orWithEmail.
  ///
  /// In en, this message translates to:
  /// **'or with email'**
  String get orWithEmail;

  /// No description provided for @apple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get apple;

  /// No description provided for @google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @createYourAccountSub.
  ///
  /// In en, this message translates to:
  /// **'Send items with verified travelers heading to your destination.'**
  String get createYourAccountSub;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @orSignUpManually.
  ///
  /// In en, this message translates to:
  /// **'or sign up manually'**
  String get orSignUpManually;

  /// No description provided for @mandatoryIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Mandatory ID Verification'**
  String get mandatoryIdTitle;

  /// No description provided for @mandatoryIdBody.
  ///
  /// In en, this message translates to:
  /// **'Government ID & face scan verification will be requested right after sign-up before transacting.'**
  String get mandatoryIdBody;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account & Continue'**
  String get createAccountButton;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @signInHere.
  ///
  /// In en, this message translates to:
  /// **'Sign In here'**
  String get signInHere;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'GOOD MORNING'**
  String get goodMorning;

  /// No description provided for @homeHero.
  ///
  /// In en, this message translates to:
  /// **'Your parcel is already on its way.'**
  String get homeHero;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send it with someone going your way'**
  String get homeSubtitle;

  /// No description provided for @findATraveler.
  ///
  /// In en, this message translates to:
  /// **'FIND A TRAVELER'**
  String get findATraveler;

  /// No description provided for @trustedRoutes.
  ///
  /// In en, this message translates to:
  /// **'Trusted routes, verified users'**
  String get trustedRoutes;

  /// No description provided for @deliverTo.
  ///
  /// In en, this message translates to:
  /// **'DELIVER TO'**
  String get deliverTo;

  /// No description provided for @whereIsItGoing.
  ///
  /// In en, this message translates to:
  /// **'Where is it going?'**
  String get whereIsItGoing;

  /// No description provided for @deliveryDate.
  ///
  /// In en, this message translates to:
  /// **'DELIVERY DATE'**
  String get deliveryDate;

  /// No description provided for @chooseADate.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get chooseADate;

  /// No description provided for @selectedDate.
  ///
  /// In en, this message translates to:
  /// **'SELECTED DATE'**
  String get selectedDate;

  /// No description provided for @searchTravelers.
  ///
  /// In en, this message translates to:
  /// **'Search travelers'**
  String get searchTravelers;

  /// No description provided for @sendAnItem.
  ///
  /// In en, this message translates to:
  /// **'Send an item'**
  String get sendAnItem;

  /// No description provided for @addATrip.
  ///
  /// In en, this message translates to:
  /// **'Add a trip'**
  String get addATrip;

  /// No description provided for @communityFavorites.
  ///
  /// In en, this message translates to:
  /// **'COMMUNITY FAVORITES'**
  String get communityFavorites;

  /// No description provided for @activeTravelers.
  ///
  /// In en, this message translates to:
  /// **'Active travelers'**
  String get activeTravelers;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @recentRoutes.
  ///
  /// In en, this message translates to:
  /// **'Recent routes'**
  String get recentRoutes;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @sealedBoxPolicy.
  ///
  /// In en, this message translates to:
  /// **'Sealed Box Policy'**
  String get sealedBoxPolicy;

  /// No description provided for @sealedBoxPolicyBody.
  ///
  /// In en, this message translates to:
  /// **'Items must always be sealed in their original retail box for customs compliance and travel security.'**
  String get sealedBoxPolicyBody;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @searchForTravelers.
  ///
  /// In en, this message translates to:
  /// **'Search for Travelers'**
  String get searchForTravelers;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @whereItemStartsFrom.
  ///
  /// In en, this message translates to:
  /// **'Where is the item starting from?'**
  String get whereItemStartsFrom;

  /// No description provided for @departureCountry.
  ///
  /// In en, this message translates to:
  /// **'Departure country'**
  String get departureCountry;

  /// No description provided for @departureCity.
  ///
  /// In en, this message translates to:
  /// **'Departure city'**
  String get departureCity;

  /// No description provided for @whereItemNeedsToGo.
  ///
  /// In en, this message translates to:
  /// **'Where does the item need to go?'**
  String get whereItemNeedsToGo;

  /// No description provided for @destinationCountry.
  ///
  /// In en, this message translates to:
  /// **'Destination country'**
  String get destinationCountry;

  /// No description provided for @destinationCity.
  ///
  /// In en, this message translates to:
  /// **'Destination city'**
  String get destinationCity;

  /// No description provided for @desiredDeliveryDate.
  ///
  /// In en, this message translates to:
  /// **'Desired delivery date'**
  String get desiredDeliveryDate;

  /// No description provided for @flexibleDays.
  ///
  /// In en, this message translates to:
  /// **'Flexible within ±2 days'**
  String get flexibleDays;

  /// No description provided for @searchTravelersButton.
  ///
  /// In en, this message translates to:
  /// **'Search Travelers'**
  String get searchTravelersButton;

  /// No description provided for @originalPackagingTitle.
  ///
  /// In en, this message translates to:
  /// **'Original Packaging Requirement'**
  String get originalPackagingTitle;

  /// No description provided for @originalPackagingBody.
  ///
  /// In en, this message translates to:
  /// **'Items must be sealed in their original box. Pricing is calculated automatically based on item size and weight.'**
  String get originalPackagingBody;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'RECENT SEARCHES'**
  String get recentSearches;

  /// No description provided for @travelerResults.
  ///
  /// In en, this message translates to:
  /// **'Traveler Results'**
  String get travelerResults;

  /// No description provided for @routeAndDate.
  ///
  /// In en, this message translates to:
  /// **'ROUTE & DESIRED DATE'**
  String get routeAndDate;

  /// No description provided for @aroundDate.
  ///
  /// In en, this message translates to:
  /// **'Around June 22, 2025 · 4 travelers available'**
  String get aroundDate;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @itemsDelivered.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get itemsDelivered;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @needDifferentDate.
  ///
  /// In en, this message translates to:
  /// **'Need a different date?'**
  String get needDifferentDate;

  /// No description provided for @getNotified.
  ///
  /// In en, this message translates to:
  /// **'Get notified immediately when new travelers add trips on this route.'**
  String get getNotified;

  /// No description provided for @travelerProfile.
  ///
  /// In en, this message translates to:
  /// **'Traveler Profile'**
  String get travelerProfile;

  /// No description provided for @frequentTraveler.
  ///
  /// In en, this message translates to:
  /// **'Frequent traveler on LOS ⇄ LHR route'**
  String get frequentTraveler;

  /// No description provided for @itemsDeliveredStat.
  ///
  /// In en, this message translates to:
  /// **'Items delivered'**
  String get itemsDeliveredStat;

  /// No description provided for @senderReviews.
  ///
  /// In en, this message translates to:
  /// **'sender reviews'**
  String get senderReviews;

  /// No description provided for @onTimeRate.
  ///
  /// In en, this message translates to:
  /// **'On-time rate'**
  String get onTimeRate;

  /// No description provided for @travelDateAndRoute.
  ///
  /// In en, this message translates to:
  /// **'TRAVEL DATE AND ROUTE'**
  String get travelDateAndRoute;

  /// No description provided for @departure.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get departure;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @directFlight.
  ///
  /// In en, this message translates to:
  /// **'Direct flight'**
  String get directFlight;

  /// No description provided for @pricingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pricing:'**
  String get pricingLabel;

  /// No description provided for @pricingValue.
  ///
  /// In en, this message translates to:
  /// **'Calculated per distance, item size & weight'**
  String get pricingValue;

  /// No description provided for @sameDayDelivery.
  ///
  /// In en, this message translates to:
  /// **'Same day delivery'**
  String get sameDayDelivery;

  /// No description provided for @deliverInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deliver in 1 day} other{Deliver in {count} days}}'**
  String deliverInDays(int count);

  /// No description provided for @itemSizeAndWeight.
  ///
  /// In en, this message translates to:
  /// **'ITEM SIZE & WEIGHT LIMITS ACCEPTED'**
  String get itemSizeAndWeight;

  /// No description provided for @weightLimit.
  ///
  /// In en, this message translates to:
  /// **'Weight Limit'**
  String get weightLimit;

  /// No description provided for @sizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Size Limit'**
  String get sizeLimit;

  /// No description provided for @checkBaggage.
  ///
  /// In en, this message translates to:
  /// **'Checked baggage space'**
  String get checkBaggage;

  /// No description provided for @maxDimensions.
  ///
  /// In en, this message translates to:
  /// **'Max 30 × 20 × 15 cm'**
  String get maxDimensions;

  /// No description provided for @itemRequirement.
  ///
  /// In en, this message translates to:
  /// **'Item Requirement'**
  String get itemRequirement;

  /// No description provided for @itemRequirementBody.
  ///
  /// In en, this message translates to:
  /// **'Items must be sealed in their original box. This lets travelers carry items with confidence and helps with customs and security checks.'**
  String get itemRequirementBody;

  /// No description provided for @deliveryHistoryAndReviews.
  ///
  /// In en, this message translates to:
  /// **'DELIVERY HISTORY & REVIEWS'**
  String get deliveryHistoryAndReviews;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendRequest;

  /// No description provided for @deliveryRequest.
  ///
  /// In en, this message translates to:
  /// **'Delivery Request'**
  String get deliveryRequest;

  /// No description provided for @selectedTraveler.
  ///
  /// In en, this message translates to:
  /// **'SELECTED TRAVELER'**
  String get selectedTraveler;

  /// No description provided for @whatIsTheItem.
  ///
  /// In en, this message translates to:
  /// **'What is the item?'**
  String get whatIsTheItem;

  /// No description provided for @itemCategory.
  ///
  /// In en, this message translates to:
  /// **'Item Category'**
  String get itemCategory;

  /// No description provided for @electronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get electronics;

  /// No description provided for @apparel.
  ///
  /// In en, this message translates to:
  /// **'Apparel'**
  String get apparel;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @itemDescription.
  ///
  /// In en, this message translates to:
  /// **'Item Description'**
  String get itemDescription;

  /// No description provided for @packageWeight.
  ///
  /// In en, this message translates to:
  /// **'Package Weight'**
  String get packageWeight;

  /// No description provided for @packageDimensions.
  ///
  /// In en, this message translates to:
  /// **'Package Dimensions'**
  String get packageDimensions;

  /// No description provided for @itemPhotos.
  ///
  /// In en, this message translates to:
  /// **'Item Photos (Sealed Box)'**
  String get itemPhotos;

  /// No description provided for @photoAttached.
  ///
  /// In en, this message translates to:
  /// **'photo attached'**
  String get photoAttached;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @calculatedPrice.
  ///
  /// In en, this message translates to:
  /// **'Calculated Item Price'**
  String get calculatedPrice;

  /// No description provided for @sendDeliveryRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendDeliveryRequest;

  /// No description provided for @secureEscrowCheckout.
  ///
  /// In en, this message translates to:
  /// **'Secure Escrow Checkout'**
  String get secureEscrowCheckout;

  /// No description provided for @paymentWindowActive.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT WINDOW ACTIVE'**
  String get paymentWindowActive;

  /// No description provided for @requestExpires.
  ///
  /// In en, this message translates to:
  /// **'Request expires in'**
  String get requestExpires;

  /// No description provided for @howEscrowWorks.
  ///
  /// In en, this message translates to:
  /// **'How Escrow Protection Works'**
  String get howEscrowWorks;

  /// No description provided for @escrowBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment is held safely by Nata. The traveler is only paid after your recipient verifies delivery with your secret 4-digit code or photo proof.'**
  String get escrowBody;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'SELECT PAYMENT METHOD'**
  String get selectPaymentMethod;

  /// No description provided for @applePay.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get applePay;

  /// No description provided for @applePaySub.
  ///
  /// In en, this message translates to:
  /// **'Default · Fast & Secure 1-tap'**
  String get applePaySub;

  /// No description provided for @creditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit or Debit Card'**
  String get creditCard;

  /// No description provided for @creditCardSub.
  ///
  /// In en, this message translates to:
  /// **'Visa, Mastercard, Amex'**
  String get creditCardSub;

  /// No description provided for @mobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get mobileMoney;

  /// No description provided for @mobileMoneyPhoneSub.
  ///
  /// In en, this message translates to:
  /// **'MTN MoMo, Airtel, Orange, M-Pesa'**
  String get mobileMoneyPhoneSub;

  /// No description provided for @paymentBreakdown.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT BREAKDOWN'**
  String get paymentBreakdown;

  /// No description provided for @travelerReward.
  ///
  /// In en, this message translates to:
  /// **'Traveler reward'**
  String get travelerReward;

  /// No description provided for @platformFee.
  ///
  /// In en, this message translates to:
  /// **'Nata protection & escrow fee'**
  String get platformFee;

  /// No description provided for @totalEscrow.
  ///
  /// In en, this message translates to:
  /// **'Total to Hold in Escrow'**
  String get totalEscrow;

  /// No description provided for @payIntoEscrow.
  ///
  /// In en, this message translates to:
  /// **'Pay into Escrow'**
  String get payIntoEscrow;

  /// No description provided for @cancellationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancellation & Refund Guarantee'**
  String get cancellationTitle;

  /// No description provided for @refundBullet1.
  ///
  /// In en, this message translates to:
  /// **'Full 100% refund if traveler cancels or item is not delivered.'**
  String get refundBullet1;

  /// No description provided for @refundBullet2.
  ///
  /// In en, this message translates to:
  /// **'Cancelling is free until the traveler accepts. After that, a 10% cancellation fee applies until handoff.'**
  String get refundBullet2;

  /// No description provided for @refundBullet3.
  ///
  /// In en, this message translates to:
  /// **'3-day dispute window after delivery before funds are finalized.'**
  String get refundBullet3;

  /// No description provided for @escrowEncrypted.
  ///
  /// In en, this message translates to:
  /// **'256-Bit Encrypted Escrow by Nata Pay'**
  String get escrowEncrypted;

  /// No description provided for @deliveryRequests.
  ///
  /// In en, this message translates to:
  /// **'Delivery Requests'**
  String get deliveryRequests;

  /// No description provided for @requestsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get requestsActive;

  /// No description provided for @requestsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get requestsArchive;

  /// No description provided for @requestsArchiveCount.
  ///
  /// In en, this message translates to:
  /// **'Archive · {count}'**
  String requestsArchiveCount(int count);

  /// No description provided for @requestsArchiveNote.
  ///
  /// In en, this message translates to:
  /// **'Delivered, cancelled and expired requests move here 24 hours after they close, or when you swipe one away.'**
  String get requestsArchiveNote;

  /// No description provided for @requestsArchiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing archived yet.'**
  String get requestsArchiveEmpty;

  /// No description provided for @archiveAction.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveAction;

  /// No description provided for @requestArchived.
  ///
  /// In en, this message translates to:
  /// **'Moved to Archive'**
  String get requestArchived;

  /// No description provided for @errArchiveRequest.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t archive this request. Please try again.'**
  String get errArchiveRequest;

  /// No description provided for @incoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get incoming;

  /// No description provided for @outgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get outgoing;

  /// No description provided for @incomingSection.
  ///
  /// In en, this message translates to:
  /// **'INCOMING REQUESTS (AS TRAVELER)'**
  String get incomingSection;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'pending review'**
  String get pendingReview;

  /// No description provided for @outgoingSection.
  ///
  /// In en, this message translates to:
  /// **'OUTGOING REQUESTS (AS SENDER)'**
  String get outgoingSection;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get total;

  /// No description provided for @sender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get sender;

  /// No description provided for @successfulDeliveries.
  ///
  /// In en, this message translates to:
  /// **'successful deliveries'**
  String get successfulDeliveries;

  /// No description provided for @yourTrip.
  ///
  /// In en, this message translates to:
  /// **'Your Trip:'**
  String get yourTrip;

  /// No description provided for @travelDate.
  ///
  /// In en, this message translates to:
  /// **'Travel Date:'**
  String get travelDate;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item:'**
  String get item;

  /// No description provided for @weightAndSize.
  ///
  /// In en, this message translates to:
  /// **'Weight & Size:'**
  String get weightAndSize;

  /// No description provided for @sealedPhotoAttached.
  ///
  /// In en, this message translates to:
  /// **'factory-sealed photo attached'**
  String get sealedPhotoAttached;

  /// No description provided for @viewPhoto.
  ///
  /// In en, this message translates to:
  /// **'View Photo'**
  String get viewPhoto;

  /// No description provided for @viewPhotos.
  ///
  /// In en, this message translates to:
  /// **'View Photos'**
  String get viewPhotos;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @acceptRequest.
  ///
  /// In en, this message translates to:
  /// **'Accept Request'**
  String get acceptRequest;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @declined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declined;

  /// No description provided for @payInTime.
  ///
  /// In en, this message translates to:
  /// **'Pay in'**
  String get payInTime;

  /// No description provided for @payEscrow.
  ///
  /// In en, this message translates to:
  /// **'Pay Escrow'**
  String get payEscrow;

  /// No description provided for @refundCredited.
  ///
  /// In en, this message translates to:
  /// **'Refund credited to balance'**
  String get refundCredited;

  /// No description provided for @findAnotherTraveler.
  ///
  /// In en, this message translates to:
  /// **'Find another traveler'**
  String get findAnotherTraveler;

  /// No description provided for @arrangeHandoff.
  ///
  /// In en, this message translates to:
  /// **'Arrange handoff via chat'**
  String get arrangeHandoff;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @unreadUpdates.
  ///
  /// In en, this message translates to:
  /// **'3 unread delivery updates'**
  String get unreadUpdates;

  /// No description provided for @searchConversations.
  ///
  /// In en, this message translates to:
  /// **'Search conversations or tracking...'**
  String get searchConversations;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All (4)'**
  String get allFilter;

  /// No description provided for @activeDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Active Deliveries (2)'**
  String get activeDeliveries;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed (1)'**
  String get completed;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @accountAndProfile.
  ///
  /// In en, this message translates to:
  /// **'Account & Profile'**
  String get accountAndProfile;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String memberSince(String date);

  /// No description provided for @tripsCarried.
  ///
  /// In en, this message translates to:
  /// **'TRIPS CARRIED'**
  String get tripsCarried;

  /// No description provided for @parcelsSent.
  ///
  /// In en, this message translates to:
  /// **'PARCELS SENT'**
  String get parcelsSent;

  /// No description provided for @tripsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Trip} other{{count} Trips}}'**
  String tripsCount(int count);

  /// No description provided for @parcelsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Parcel} other{{count} Parcels}}'**
  String parcelsCount(int count);

  /// No description provided for @natawallet.
  ///
  /// In en, this message translates to:
  /// **'NATA WALLET'**
  String get natawallet;

  /// No description provided for @escrowProtected.
  ///
  /// In en, this message translates to:
  /// **'Escrow Protected'**
  String get escrowProtected;

  /// No description provided for @availableForPayout.
  ///
  /// In en, this message translates to:
  /// **'Available for Payout'**
  String get availableForPayout;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @heldInEscrow.
  ///
  /// In en, this message translates to:
  /// **'held in Escrow'**
  String get heldInEscrow;

  /// No description provided for @viewHistory.
  ///
  /// In en, this message translates to:
  /// **'View History'**
  String get viewHistory;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @identityVerification.
  ///
  /// In en, this message translates to:
  /// **'Identity Verification'**
  String get identityVerification;

  /// No description provided for @tier1Verified.
  ///
  /// In en, this message translates to:
  /// **'Tier 1 Verified · Passport & Biometrics'**
  String get tier1Verified;

  /// No description provided for @sealedBoxPolicySetting.
  ///
  /// In en, this message translates to:
  /// **'Sealed Box Policy'**
  String get sealedBoxPolicySetting;

  /// No description provided for @originalBoxCompliance.
  ///
  /// In en, this message translates to:
  /// **'Original box security compliance'**
  String get originalBoxCompliance;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @addATripTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a Trip'**
  String get addATripTitle;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @travelerMode.
  ///
  /// In en, this message translates to:
  /// **'TRAVELER MODE'**
  String get travelerMode;

  /// No description provided for @headingSomewhere.
  ///
  /// In en, this message translates to:
  /// **'Heading somewhere soon?'**
  String get headingSomewhere;

  /// No description provided for @luggageEarnings.
  ///
  /// In en, this message translates to:
  /// **'Turn unused luggage space into earnings by delivering sealed packages.'**
  String get luggageEarnings;

  /// No description provided for @departureDetails.
  ///
  /// In en, this message translates to:
  /// **'DEPARTURE DETAILS'**
  String get departureDetails;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @arrivalDetails.
  ///
  /// In en, this message translates to:
  /// **'ARRIVAL DETAILS'**
  String get arrivalDetails;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @departureDate.
  ///
  /// In en, this message translates to:
  /// **'DEPARTURE DATE'**
  String get departureDate;

  /// No description provided for @arrivalDate.
  ///
  /// In en, this message translates to:
  /// **'ARRIVAL DATE'**
  String get arrivalDate;

  /// No description provided for @flightTicket.
  ///
  /// In en, this message translates to:
  /// **'FLIGHT TICKET RECEIPT'**
  String get flightTicket;

  /// No description provided for @flightTicketSub.
  ///
  /// In en, this message translates to:
  /// **'Upload a copy of your flight booking receipt to confirm your trip'**
  String get flightTicketSub;

  /// No description provided for @uploadFlightReceipt.
  ///
  /// In en, this message translates to:
  /// **'Upload Flight Receipt (PDF / Image)'**
  String get uploadFlightReceipt;

  /// No description provided for @replaceFlightReceipt.
  ///
  /// In en, this message translates to:
  /// **'Replace Flight Receipt (PDF / Image)'**
  String get replaceFlightReceipt;

  /// No description provided for @luggageCapacity.
  ///
  /// In en, this message translates to:
  /// **'LUGGAGE CAPACITY YOU CAN CARRY'**
  String get luggageCapacity;

  /// No description provided for @maxWeight.
  ///
  /// In en, this message translates to:
  /// **'Max Weight'**
  String get maxWeight;

  /// No description provided for @maxItemSize.
  ///
  /// In en, this message translates to:
  /// **'Max Item Size'**
  String get maxItemSize;

  /// No description provided for @howMatchingWorks.
  ///
  /// In en, this message translates to:
  /// **'How search matching works'**
  String get howMatchingWorks;

  /// No description provided for @howMatchingBody.
  ///
  /// In en, this message translates to:
  /// **'Once saved, your trip will appear in search results for senders looking for this route and date. Senders will only request sealed boxes within your specified capacity.'**
  String get howMatchingBody;

  /// No description provided for @saveAndPublish.
  ///
  /// In en, this message translates to:
  /// **'Save & Publish Trip'**
  String get saveAndPublish;

  /// No description provided for @confirmDelivery.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery'**
  String get confirmDelivery;

  /// No description provided for @enter4DigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter 4-Digit Release Code'**
  String get enter4DigitCode;

  /// No description provided for @recipientWillGive.
  ///
  /// In en, this message translates to:
  /// **'Your recipient will give you this code when they receive the item.'**
  String get recipientWillGive;

  /// No description provided for @codeEntered.
  ///
  /// In en, this message translates to:
  /// **'Code entered — ready to confirm'**
  String get codeEntered;

  /// No description provided for @uploadHandoffPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Handoff Photo'**
  String get uploadHandoffPhoto;

  /// No description provided for @handoffPhotoSub.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of you and the recipient together, or a photo of the item being handed over.'**
  String get handoffPhotoSub;

  /// No description provided for @confirmDeliveryButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery & Release Payment'**
  String get confirmDeliveryButton;

  /// No description provided for @disputeWindow.
  ///
  /// In en, this message translates to:
  /// **'Payment releases after 3-day dispute window'**
  String get disputeWindow;

  /// No description provided for @leaveAReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a Review'**
  String get leaveAReview;

  /// No description provided for @howWasExperience.
  ///
  /// In en, this message translates to:
  /// **'How was your experience?'**
  String get howWasExperience;

  /// No description provided for @whatWentWell.
  ///
  /// In en, this message translates to:
  /// **'What went well?'**
  String get whatWentWell;

  /// No description provided for @leaveComment.
  ///
  /// In en, this message translates to:
  /// **'Leave a comment (optional)'**
  String get leaveComment;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your experience — this helps the community...'**
  String get commentHint;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review Submitted!'**
  String get reviewSubmitted;

  /// No description provided for @reviewThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for reviewing Amara Kalu. Your feedback helps the community stay trusted and safe.'**
  String get reviewThanks;

  /// No description provided for @returningHome.
  ///
  /// In en, this message translates to:
  /// **'Returning to home...'**
  String get returningHome;

  /// No description provided for @ratingPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor — not what I expected'**
  String get ratingPoor;

  /// No description provided for @ratingFair.
  ///
  /// In en, this message translates to:
  /// **'Fair — some issues'**
  String get ratingFair;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good — met expectations'**
  String get ratingGood;

  /// No description provided for @ratingGreat.
  ///
  /// In en, this message translates to:
  /// **'Great — exceeded expectations'**
  String get ratingGreat;

  /// No description provided for @ratingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent — would recommend!'**
  String get ratingExcellent;

  /// No description provided for @identityVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity Verification'**
  String get identityVerificationTitle;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'REQUIRED'**
  String get required;

  /// No description provided for @almostDone.
  ///
  /// In en, this message translates to:
  /// **'ALMOST DONE'**
  String get almostDone;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @step1of2.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 2'**
  String get step1of2;

  /// No description provided for @step2of2.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 2'**
  String get step2of2;

  /// No description provided for @skipForNowId.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNowId;

  /// No description provided for @actionRequired.
  ///
  /// In en, this message translates to:
  /// **'Action required before sending'**
  String get actionRequired;

  /// No description provided for @actionRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'You can browse travelers anytime, but identity verification is mandatory to send or accept parcel requests.'**
  String get actionRequiredBody;

  /// No description provided for @verifyIdentity.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity'**
  String get verifyIdentity;

  /// No description provided for @verifyIdentitySub.
  ///
  /// In en, this message translates to:
  /// **'Complete 2 quick steps to verify yourself in under 2 minutes.'**
  String get verifyIdentitySub;

  /// No description provided for @uploadOfficialId.
  ///
  /// In en, this message translates to:
  /// **'Upload official ID'**
  String get uploadOfficialId;

  /// No description provided for @passportOrId.
  ///
  /// In en, this message translates to:
  /// **'Passport, National ID or Driver\'s License'**
  String get passportOrId;

  /// No description provided for @activeStep.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeStep;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextStep;

  /// No description provided for @passportOption.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get passportOption;

  /// No description provided for @driversLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get driversLicense;

  /// No description provided for @nationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get nationalId;

  /// No description provided for @takePhotoOrUpload.
  ///
  /// In en, this message translates to:
  /// **'Take photo or upload front page'**
  String get takePhotoOrUpload;

  /// No description provided for @allCornersVisible.
  ///
  /// In en, this message translates to:
  /// **'Ensure all 4 corners are visible with no glare'**
  String get allCornersVisible;

  /// No description provided for @useCamera.
  ///
  /// In en, this message translates to:
  /// **'Use camera'**
  String get useCamera;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get chooseFile;

  /// No description provided for @faceScan.
  ///
  /// In en, this message translates to:
  /// **'3D Face Scan'**
  String get faceScan;

  /// No description provided for @faceScanSub.
  ///
  /// In en, this message translates to:
  /// **'Matches your live selfie with your ID photo'**
  String get faceScanSub;

  /// No description provided for @scanIdToContinue.
  ///
  /// In en, this message translates to:
  /// **'Scan ID to Continue'**
  String get scanIdToContinue;

  /// No description provided for @biometricNote.
  ///
  /// In en, this message translates to:
  /// **'Your biometric data is processed strictly for identity verification.'**
  String get biometricNote;

  /// No description provided for @step1Completed.
  ///
  /// In en, this message translates to:
  /// **'Step 1 Completed'**
  String get step1Completed;

  /// No description provided for @passportVerified.
  ///
  /// In en, this message translates to:
  /// **'Passport document verified · Fortune Niama'**
  String get passportVerified;

  /// No description provided for @editId.
  ///
  /// In en, this message translates to:
  /// **'Edit ID'**
  String get editId;

  /// No description provided for @faceScanTitle.
  ///
  /// In en, this message translates to:
  /// **'3D Biometric Face Scan'**
  String get faceScanTitle;

  /// No description provided for @faceScanBody.
  ///
  /// In en, this message translates to:
  /// **'Center your face within the frame to verify liveness and confirm ownership.'**
  String get faceScanBody;

  /// No description provided for @holdStill.
  ///
  /// In en, this message translates to:
  /// **'Hold still, look directly at the screen'**
  String get holdStill;

  /// No description provided for @nodHead.
  ///
  /// In en, this message translates to:
  /// **'Slowly nod your head when the border turns green.'**
  String get nodHead;

  /// No description provided for @goodLight.
  ///
  /// In en, this message translates to:
  /// **'Good Light'**
  String get goodLight;

  /// No description provided for @noGlasses.
  ///
  /// In en, this message translates to:
  /// **'No Glasses'**
  String get noGlasses;

  /// No description provided for @neutralFace.
  ///
  /// In en, this message translates to:
  /// **'Neutral Face'**
  String get neutralFace;

  /// No description provided for @startBiometricScan.
  ///
  /// In en, this message translates to:
  /// **'Start Biometric Scan'**
  String get startBiometricScan;

  /// No description provided for @biometricLocalNote.
  ///
  /// In en, this message translates to:
  /// **'Your selfie is compared with your ID photo by our secure verification service and stored privately.'**
  String get biometricLocalNote;

  /// No description provided for @fullyVerified.
  ///
  /// In en, this message translates to:
  /// **'You\'re Fully Verified!'**
  String get fullyVerified;

  /// No description provided for @fullyVerifiedSub.
  ///
  /// In en, this message translates to:
  /// **'Your identity documents and biometric scan have been authenticated successfully.'**
  String get fullyVerifiedSub;

  /// No description provided for @verificationReport.
  ///
  /// In en, this message translates to:
  /// **'VERIFICATION REPORT'**
  String get verificationReport;

  /// No description provided for @instantApproval.
  ///
  /// In en, this message translates to:
  /// **'Instant Approval ✓'**
  String get instantApproval;

  /// No description provided for @passportIdDoc.
  ///
  /// In en, this message translates to:
  /// **'Passport ID Document'**
  String get passportIdDoc;

  /// No description provided for @biometricLiveness.
  ///
  /// In en, this message translates to:
  /// **'3D Biometric Liveness'**
  String get biometricLiveness;

  /// No description provided for @trustLimit.
  ///
  /// In en, this message translates to:
  /// **'Trust & Escrow Limit'**
  String get trustLimit;

  /// No description provided for @unlockedPerks.
  ///
  /// In en, this message translates to:
  /// **'UNLOCKED MEMBER PERKS'**
  String get unlockedPerks;

  /// No description provided for @perk1.
  ///
  /// In en, this message translates to:
  /// **'Post unlimited trips'**
  String get perk1;

  /// No description provided for @perk2.
  ///
  /// In en, this message translates to:
  /// **'Fast payout release'**
  String get perk2;

  /// No description provided for @perk3.
  ///
  /// In en, this message translates to:
  /// **'Verified profile badge'**
  String get perk3;

  /// No description provided for @perk4.
  ///
  /// In en, this message translates to:
  /// **'Priority match rank'**
  String get perk4;

  /// No description provided for @continueToHome.
  ///
  /// In en, this message translates to:
  /// **'Continue to Home'**
  String get continueToHome;

  /// No description provided for @viewPublicProfile.
  ///
  /// In en, this message translates to:
  /// **'View Public Profile'**
  String get viewPublicProfile;

  /// No description provided for @encrypted256.
  ///
  /// In en, this message translates to:
  /// **'256-bit Encrypted'**
  String get encrypted256;

  /// No description provided for @instantAi.
  ///
  /// In en, this message translates to:
  /// **'Instant AI Verification'**
  String get instantAi;

  /// No description provided for @gdprCompliant.
  ///
  /// In en, this message translates to:
  /// **'GDPR & KYC Compliant'**
  String get gdprCompliant;

  /// No description provided for @trips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get trips;

  /// No description provided for @identityActionRequiredSub.
  ///
  /// In en, this message translates to:
  /// **'Action Required: Verify your identity'**
  String get identityActionRequiredSub;

  /// No description provided for @identityUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Verification is currently under review'**
  String get identityUnderReview;

  /// No description provided for @verificationReviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing'**
  String get verificationReviewing;

  /// No description provided for @ratingStat.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get ratingStat;

  /// No description provided for @upcomingTrips.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING TRIPS'**
  String get upcomingTrips;

  /// No description provided for @newTravelerRating.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newTravelerRating;

  /// No description provided for @upcomingTripsStat.
  ///
  /// In en, this message translates to:
  /// **'Upcoming trips'**
  String get upcomingTripsStat;

  /// No description provided for @travelerOnRoute.
  ///
  /// In en, this message translates to:
  /// **'Traveler on {from} ⇄ {to} route'**
  String travelerOnRoute(String from, String to);

  /// No description provided for @frequentTravelerOnRoute.
  ///
  /// In en, this message translates to:
  /// **'Frequent traveler on {from} ⇄ {to} route'**
  String frequentTravelerOnRoute(String from, String to);

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get myTrips;

  /// No description provided for @tabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tabUpcoming;

  /// No description provided for @tabPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get tabPast;

  /// No description provided for @tripPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get tripPublished;

  /// No description provided for @tripInReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get tripInReview;

  /// No description provided for @tripCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tripCompleted;

  /// No description provided for @tripCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tripCancelled;

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit Trip'**
  String get editTrip;

  /// No description provided for @viewRequests.
  ///
  /// In en, this message translates to:
  /// **'View Requests'**
  String get viewRequests;

  /// No description provided for @maxWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Max weight'**
  String get maxWeightLabel;

  /// No description provided for @maxSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Max size'**
  String get maxSizeLabel;

  /// No description provided for @noUpcomingTrips.
  ///
  /// In en, this message translates to:
  /// **'No upcoming trips'**
  String get noUpcomingTrips;

  /// No description provided for @noPastTrips.
  ///
  /// In en, this message translates to:
  /// **'No past trips yet'**
  String get noPastTrips;

  /// No description provided for @addTripPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add a trip to start earning from your luggage space.'**
  String get addTripPrompt;

  /// No description provided for @tripInReviewNote.
  ///
  /// In en, this message translates to:
  /// **'We\'re reviewing your trip. It goes live once approved.'**
  String get tripInReviewNote;

  /// No description provided for @couldNotLoadTrips.
  ///
  /// In en, this message translates to:
  /// **'Could not load your trips.'**
  String get couldNotLoadTrips;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @tripPublishedToast.
  ///
  /// In en, this message translates to:
  /// **'Trip published'**
  String get tripPublishedToast;

  /// No description provided for @tripUpdated.
  ///
  /// In en, this message translates to:
  /// **'Trip updated'**
  String get tripUpdated;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get selectCountry;

  /// No description provided for @selectCity.
  ///
  /// In en, this message translates to:
  /// **'Select city'**
  String get selectCity;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @errPickDeparture.
  ///
  /// In en, this message translates to:
  /// **'Choose where you are departing from.'**
  String get errPickDeparture;

  /// No description provided for @errPickArrival.
  ///
  /// In en, this message translates to:
  /// **'Choose your destination.'**
  String get errPickArrival;

  /// No description provided for @errSameCity.
  ///
  /// In en, this message translates to:
  /// **'Departure and arrival must be different cities.'**
  String get errSameCity;

  /// No description provided for @errPickDepDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a departure date.'**
  String get errPickDepDate;

  /// No description provided for @errPickArrDate.
  ///
  /// In en, this message translates to:
  /// **'Choose an arrival date.'**
  String get errPickArrDate;

  /// No description provided for @errArrivalBeforeDeparture.
  ///
  /// In en, this message translates to:
  /// **'Arrival can\'t be before departure.'**
  String get errArrivalBeforeDeparture;

  /// No description provided for @errAttachReceipt.
  ///
  /// In en, this message translates to:
  /// **'Attach your flight receipt.'**
  String get errAttachReceipt;

  /// No description provided for @errSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your trip. Please try again.'**
  String get errSaveFailed;

  /// No description provided for @itemsDeliveredCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item delivered} other{{count} items delivered}}'**
  String itemsDeliveredCount(int count);

  /// No description provided for @bookingReference.
  ///
  /// In en, this message translates to:
  /// **'Booking reference'**
  String get bookingReference;

  /// No description provided for @bookingReferenceSub.
  ///
  /// In en, this message translates to:
  /// **'Enter the reference code from your flight booking (PNR)'**
  String get bookingReferenceSub;

  /// No description provided for @errBookingReference.
  ///
  /// In en, this message translates to:
  /// **'Booking reference must be 5–8 letters or numbers.'**
  String get errBookingReference;

  /// No description provided for @bookingReferenceShort.
  ///
  /// In en, this message translates to:
  /// **'Ref {code}'**
  String bookingReferenceShort(String code);

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification pending'**
  String get verificationPending;

  /// No description provided for @verificationUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get verificationUnverified;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get uploadFile;

  /// No description provided for @errCamera.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera.'**
  String get errCamera;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @paymentsFilter.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsFilter;

  /// No description provided for @notifToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notifToday;

  /// No description provided for @notifEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notifEarlier;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @noNotificationsSub.
  ///
  /// In en, this message translates to:
  /// **'We\'ll let you know here when something happens with your trips, requests and payments.'**
  String get noNotificationsSub;

  /// No description provided for @couldNotLoadNotifications.
  ///
  /// In en, this message translates to:
  /// **'Could not load your notifications.'**
  String get couldNotLoadNotifications;

  /// No description provided for @notifDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get notifDelete;

  /// No description provided for @errNotifDelete.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the notification. Please try again.'**
  String get errNotifDelete;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @yesterdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterdayLabel;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hr ago'**
  String hoursAgo(int count);

  /// No description provided for @notifFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notifFilterAll;

  /// No description provided for @faceIdReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you to sign in to Nata'**
  String get faceIdReason;

  /// No description provided for @faceIdSignInFirst.
  ///
  /// In en, this message translates to:
  /// **'To use Face ID, sign in with your phone number first and keep \"Remember me\" ticked.'**
  String get faceIdSignInFirst;

  /// No description provided for @faceIdUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Face ID isn\'t available on this device.'**
  String get faceIdUnavailable;

  /// No description provided for @faceIdNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up Face ID in your device settings first.'**
  String get faceIdNotSetUp;

  /// No description provided for @faceIdFailed.
  ///
  /// In en, this message translates to:
  /// **'Face ID didn\'t recognise you. Try again or sign in with your phone number.'**
  String get faceIdFailed;

  /// No description provided for @faceIdLocked.
  ///
  /// In en, this message translates to:
  /// **'Face ID is locked for now. Sign in with your phone number.'**
  String get faceIdLocked;

  /// No description provided for @splashDetectedSummary.
  ///
  /// In en, this message translates to:
  /// **'{country} · {language} & {currency}'**
  String splashDetectedSummary(
    String country,
    String language,
    String currency,
  );

  /// No description provided for @messagesCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get messagesCaughtUp;

  /// No description provided for @searchChats.
  ///
  /// In en, this message translates to:
  /// **'Search by name, route or item'**
  String get searchChats;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversations;

  /// No description provided for @noConversationsSub.
  ///
  /// In en, this message translates to:
  /// **'When you send or receive a delivery request, your chat with the traveler or sender appears here.'**
  String get noConversationsSub;

  /// No description provided for @noChatMatches.
  ///
  /// In en, this message translates to:
  /// **'No conversations match your search'**
  String get noChatMatches;

  /// No description provided for @couldNotLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Could not load your messages.'**
  String get couldNotLoadMessages;

  /// No description provided for @couldNotLoadChat.
  ///
  /// In en, this message translates to:
  /// **'Could not load this chat.'**
  String get couldNotLoadChat;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get typeMessage;

  /// No description provided for @msgSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get msgSending;

  /// No description provided for @msgSent.
  ///
  /// In en, this message translates to:
  /// **'Sent ✓'**
  String get msgSent;

  /// No description provided for @msgRead.
  ///
  /// In en, this message translates to:
  /// **'Read ✓✓'**
  String get msgRead;

  /// No description provided for @msgFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent · tap to retry'**
  String get msgFailed;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get chatEmpty;

  /// No description provided for @chatPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhotoLabel;

  /// No description provided for @chatChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get chatChoosePhoto;

  /// No description provided for @chatPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the photo.'**
  String get chatPhotoFailed;

  /// No description provided for @chatCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera or photos.'**
  String get chatCameraFailed;

  /// No description provided for @chatPhotoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable'**
  String get chatPhotoLoadFailed;

  /// No description provided for @unreadMessagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread message} other{{count} unread messages}}'**
  String unreadMessagesCount(int count);

  /// No description provided for @filterAllCount.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String filterAllCount(int count);

  /// No description provided for @filterActiveCount.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String filterActiveCount(int count);

  /// No description provided for @filterCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String filterCompletedCount(int count);

  /// No description provided for @chatYouPrefix.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String chatYouPrefix(String text);

  /// No description provided for @recipientDetails.
  ///
  /// In en, this message translates to:
  /// **'Recipient Details'**
  String get recipientDetails;

  /// No description provided for @recipientName.
  ///
  /// In en, this message translates to:
  /// **'Recipient Name'**
  String get recipientName;

  /// No description provided for @recipientNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full name as on their ID'**
  String get recipientNameHint;

  /// No description provided for @recipientPhone.
  ///
  /// In en, this message translates to:
  /// **'Recipient Phone Number'**
  String get recipientPhone;

  /// No description provided for @recipientPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. +44 7700 900123'**
  String get recipientPhoneHint;

  /// No description provided for @recipientPhoneNote.
  ///
  /// In en, this message translates to:
  /// **'Shared with the traveler only after they accept your request'**
  String get recipientPhoneNote;

  /// No description provided for @recipientSmsConsent.
  ///
  /// In en, this message translates to:
  /// **'By adding this number, you confirm the recipient agreed to get their delivery code from Nata by SMS.'**
  String get recipientSmsConsent;

  /// No description provided for @sizeAndWeight.
  ///
  /// In en, this message translates to:
  /// **'Size and Weight'**
  String get sizeAndWeight;

  /// No description provided for @travelerLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Traveler limit: {limit}'**
  String travelerLimitLabel(String limit);

  /// No description provided for @itemNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sony Headphones, Sealed Cosmetics, etc.'**
  String get itemNameHint;

  /// No description provided for @itemDescHint.
  ///
  /// In en, this message translates to:
  /// **'Provide details about the item and packaging...'**
  String get itemDescHint;

  /// No description provided for @weightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 0.9 kg'**
  String get weightHint;

  /// No description provided for @dimensionsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 24 × 24 × 8 cm'**
  String get dimensionsHint;

  /// No description provided for @photoMustShowSeal.
  ///
  /// In en, this message translates to:
  /// **'Photo must show sealed factory seal'**
  String get photoMustShowSeal;

  /// No description provided for @travelerPriceLine.
  ///
  /// In en, this message translates to:
  /// **'Traveler\'s price'**
  String get travelerPriceLine;

  /// No description provided for @platformProtectionLine.
  ///
  /// In en, this message translates to:
  /// **'Platform protection & escrow'**
  String get platformProtectionLine;

  /// No description provided for @priceNoteNothingCharged.
  ///
  /// In en, this message translates to:
  /// **'Nothing is charged now. The traveler can accept or decline this request, and you pay only after they accept.'**
  String get priceNoteNothingCharged;

  /// No description provided for @choosePhotoSource.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get choosePhotoSource;

  /// No description provided for @errItemName.
  ///
  /// In en, this message translates to:
  /// **'Tell us what the item is.'**
  String get errItemName;

  /// No description provided for @emergencyContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact'**
  String get emergencyContactLabel;

  /// No description provided for @ecStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 2'**
  String get ecStepOf;

  /// No description provided for @ecTitle.
  ///
  /// In en, this message translates to:
  /// **'Add an emergency contact'**
  String get ecTitle;

  /// No description provided for @ecBody.
  ///
  /// In en, this message translates to:
  /// **'Someone we can reach if something goes wrong during a delivery.'**
  String get ecBody;

  /// No description provided for @ecFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get ecFullName;

  /// No description provided for @ecFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Contact\'s full name'**
  String get ecFullNameHint;

  /// No description provided for @ecPhone.
  ///
  /// In en, this message translates to:
  /// **'Telephone Number'**
  String get ecPhone;

  /// No description provided for @ecPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 7700 900123'**
  String get ecPhoneHint;

  /// No description provided for @ecRelationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get ecRelationship;

  /// No description provided for @relFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get relFriend;

  /// No description provided for @relRelative.
  ///
  /// In en, this message translates to:
  /// **'Relative'**
  String get relRelative;

  /// No description provided for @relPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get relPartner;

  /// No description provided for @relColleague.
  ///
  /// In en, this message translates to:
  /// **'Colleague'**
  String get relColleague;

  /// No description provided for @ecPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your emergency contact is never shown to senders or travelers and is only used by our support team if we cannot reach you.'**
  String get ecPrivacy;

  /// No description provided for @ecFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish Verification'**
  String get ecFinish;

  /// No description provided for @ecFootnote.
  ///
  /// In en, this message translates to:
  /// **'Your details are stored securely and used only for safety purposes.'**
  String get ecFootnote;

  /// No description provided for @errContactName.
  ///
  /// In en, this message translates to:
  /// **'Enter the contact\'s full name.'**
  String get errContactName;

  /// No description provided for @errContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number for the selected country code.'**
  String get errContactPhone;

  /// No description provided for @errIdNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look like an ID document. Upload a clear photo of the whole ID page.'**
  String get errIdNotRecognized;

  /// No description provided for @errIdNoFace.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find the ID photo. Upload a clear picture of the page showing your face.'**
  String get errIdNoFace;

  /// No description provided for @errIdUnreadable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read the text on this ID. Upload a sharp, well-lit photo of the whole ID.'**
  String get errIdUnreadable;

  /// No description provided for @idTypePassport.
  ///
  /// In en, this message translates to:
  /// **'passport'**
  String get idTypePassport;

  /// No description provided for @idTypeDriversLicense.
  ///
  /// In en, this message translates to:
  /// **'driver\'s license'**
  String get idTypeDriversLicense;

  /// No description provided for @idTypeNationalId.
  ///
  /// In en, this message translates to:
  /// **'national ID card'**
  String get idTypeNationalId;

  /// No description provided for @errIdWrongType.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look like a {document}. Choose the right ID type above, or upload your {document}.'**
  String errIdWrongType(String document);

  /// No description provided for @faceScanIntro.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be asked to blink and turn your head, then we\'ll compare your face with your ID photo.'**
  String get faceScanIntro;

  /// No description provided for @livenessNoFace.
  ///
  /// In en, this message translates to:
  /// **'Position your face in the oval'**
  String get livenessNoFace;

  /// No description provided for @livenessMultipleFaces.
  ///
  /// In en, this message translates to:
  /// **'Only you should be in the frame'**
  String get livenessMultipleFaces;

  /// No description provided for @livenessBlink.
  ///
  /// In en, this message translates to:
  /// **'Blink slowly'**
  String get livenessBlink;

  /// No description provided for @livenessTurnHead.
  ///
  /// In en, this message translates to:
  /// **'Turn your head to the left, then to the right'**
  String get livenessTurnHead;

  /// No description provided for @livenessLookStraight.
  ///
  /// In en, this message translates to:
  /// **'Look straight at the camera and hold still'**
  String get livenessLookStraight;

  /// No description provided for @faceScanVerifying.
  ///
  /// In en, this message translates to:
  /// **'Comparing your face with your ID…'**
  String get faceScanVerifying;

  /// No description provided for @faceScanVerified.
  ///
  /// In en, this message translates to:
  /// **'Face matched. You\'re verified!'**
  String get faceScanVerified;

  /// No description provided for @faceScanNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Your face didn\'t match the photo on your ID. Attempts left: {count}.'**
  String faceScanNoMatch(int count);

  /// No description provided for @faceScanNoFace.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t see your face clearly. Try again in good light. Attempts left: {count}.'**
  String faceScanNoFace(int count);

  /// No description provided for @faceScanManualReview.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm your face automatically. Our team will review your ID.'**
  String get faceScanManualReview;

  /// No description provided for @faceScanTimeout.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up. Make sure your face is well lit and try again.'**
  String get faceScanTimeout;

  /// No description provided for @faceScanCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in Settings to scan your face.'**
  String get faceScanCameraDenied;

  /// No description provided for @faceScanError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get faceScanError;

  /// No description provided for @faceScanTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get faceScanTryAgain;

  /// No description provided for @faceScanContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get faceScanContinue;

  /// No description provided for @faceScanSkip.
  ///
  /// In en, this message translates to:
  /// **'Continue without face match (manual review)'**
  String get faceScanSkip;

  /// No description provided for @acceptedInProgress.
  ///
  /// In en, this message translates to:
  /// **'Accepted & In Progress'**
  String get acceptedInProgress;

  /// No description provided for @activeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Active'**
  String activeCount(int count);

  /// No description provided for @yourPayout.
  ///
  /// In en, this message translates to:
  /// **'Your payout'**
  String get yourPayout;

  /// No description provided for @tripLabel.
  ///
  /// In en, this message translates to:
  /// **'Trip:'**
  String get tripLabel;

  /// No description provided for @nextAction.
  ///
  /// In en, this message translates to:
  /// **'Next Action:'**
  String get nextAction;

  /// No description provided for @attachReceivedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Attach Received Photo'**
  String get attachReceivedPhoto;

  /// No description provided for @manageDeliveryAttachProof.
  ///
  /// In en, this message translates to:
  /// **'Manage Delivery & Attach Proof'**
  String get manageDeliveryAttachProof;

  /// No description provided for @pendingRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'PENDING REQUESTS ({count})'**
  String pendingRequestsCount(int count);

  /// No description provided for @awaitingYourResponse.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your response'**
  String get awaitingYourResponse;

  /// No description provided for @deliveryTaskDetails.
  ///
  /// In en, this message translates to:
  /// **'Delivery Task Details'**
  String get deliveryTaskDetails;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderNumber(String id);

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @senderVerifiedIdentity.
  ///
  /// In en, this message translates to:
  /// **'Sender · Verified Identity'**
  String get senderVerifiedIdentity;

  /// No description provided for @inEscrow.
  ///
  /// In en, this message translates to:
  /// **'(In Escrow)'**
  String get inEscrow;

  /// No description provided for @deliveryRoute.
  ///
  /// In en, this message translates to:
  /// **'Delivery Route'**
  String get deliveryRoute;

  /// No description provided for @itemToCarry.
  ///
  /// In en, this message translates to:
  /// **'Item To Carry'**
  String get itemToCarry;

  /// No description provided for @itemReceivedFromSender.
  ///
  /// In en, this message translates to:
  /// **'Item Received from Sender'**
  String get itemReceivedFromSender;

  /// No description provided for @attached.
  ///
  /// In en, this message translates to:
  /// **'Attached'**
  String get attached;

  /// No description provided for @itemReceivedNote.
  ///
  /// In en, this message translates to:
  /// **'Verify that the product is completely sealed in its factory box before taking custody.'**
  String get itemReceivedNote;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @itemDeliveredToRecipient.
  ///
  /// In en, this message translates to:
  /// **'Item Delivered to Recipient'**
  String get itemDeliveredToRecipient;

  /// No description provided for @pendingDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pending Delivery'**
  String get pendingDelivery;

  /// No description provided for @handoverNote.
  ///
  /// In en, this message translates to:
  /// **'Attach a photo of handover to recipient at the {city} destination to unlock instant escrow payout.'**
  String handoverNote(String city);

  /// No description provided for @takeOrUploadHandoverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take or Upload Handover Photo'**
  String get takeOrUploadHandoverPhoto;

  /// No description provided for @handoverPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Attach photo with recipient or at delivery spot'**
  String get handoverPhotoHint;

  /// No description provided for @handoverPhotoAttached.
  ///
  /// In en, this message translates to:
  /// **'Handover photo attached'**
  String get handoverPhotoAttached;

  /// No description provided for @recipientNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient Name:'**
  String get recipientNameLabel;

  /// No description provided for @recipientPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient Phone:'**
  String get recipientPhoneLabel;

  /// No description provided for @meetingSpotLabel.
  ///
  /// In en, this message translates to:
  /// **'Meeting Spot:'**
  String get meetingSpotLabel;

  /// No description provided for @confirmDeliveryClaim.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery & Claim {amount} Payout'**
  String confirmDeliveryClaim(String amount);

  /// No description provided for @escrowReleaseNote.
  ///
  /// In en, this message translates to:
  /// **'Funds held safely in escrow will be released immediately to your wallet.'**
  String get escrowReleaseNote;

  /// No description provided for @attachHandoverFirst.
  ///
  /// In en, this message translates to:
  /// **'Attach the handover photo first.'**
  String get attachHandoverFirst;

  /// No description provided for @recipientLocalPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 7700 900123'**
  String get recipientLocalPhoneHint;

  /// No description provided for @paymentSettings.
  ///
  /// In en, this message translates to:
  /// **'Payment Settings'**
  String get paymentSettings;

  /// No description provided for @paymentSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Payment methods & payout account'**
  String get paymentSettingsSub;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethods;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @payoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Payout Account'**
  String get payoutAccount;

  /// No description provided for @payoutAccountNote.
  ///
  /// In en, this message translates to:
  /// **'Earnings are sent to this account as soon as the recipient\'s delivery code is confirmed.'**
  String get payoutAccountNote;

  /// No description provided for @addPayoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Add payout account'**
  String get addPayoutAccount;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default Currency'**
  String get defaultCurrency;

  /// No description provided for @defaultCurrencySub.
  ///
  /// In en, this message translates to:
  /// **'Used for payouts and receipts'**
  String get defaultCurrencySub;

  /// No description provided for @payoutSchedule.
  ///
  /// In en, this message translates to:
  /// **'Payout Schedule'**
  String get payoutSchedule;

  /// No description provided for @payoutScheduleSub.
  ///
  /// In en, this message translates to:
  /// **'After delivery is confirmed'**
  String get payoutScheduleSub;

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @addPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Add Payment Method'**
  String get addPaymentMethod;

  /// No description provided for @paymentSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'Your payment details are encrypted and stored securely. Payments are held in escrow until delivery is confirmed.'**
  String get paymentSecurityNote;

  /// No description provided for @paymentKindCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentKindCard;

  /// No description provided for @paymentKindCardSub.
  ///
  /// In en, this message translates to:
  /// **'Debit or credit'**
  String get paymentKindCardSub;

  /// No description provided for @paymentKindMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get paymentKindMobile;

  /// No description provided for @paymentKindAppleSub.
  ///
  /// In en, this message translates to:
  /// **'Quick checkout'**
  String get paymentKindAppleSub;

  /// No description provided for @cardDetails.
  ///
  /// In en, this message translates to:
  /// **'Card Details'**
  String get cardDetails;

  /// No description provided for @nameOnCard.
  ///
  /// In en, this message translates to:
  /// **'Name on Card'**
  String get nameOnCard;

  /// No description provided for @nameOnCardHint.
  ///
  /// In en, this message translates to:
  /// **'Full name as on card'**
  String get nameOnCardHint;

  /// No description provided for @cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get cardNumber;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get expiryDate;

  /// No description provided for @mobileMoneyDetails.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money Details'**
  String get mobileMoneyDetails;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @registeredName.
  ///
  /// In en, this message translates to:
  /// **'Registered Name'**
  String get registeredName;

  /// No description provided for @registeredNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name registered with the provider'**
  String get registeredNameHint;

  /// No description provided for @applePayNote.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay will be linked to your Apple ID wallet. You\'ll confirm it with Face ID on your device.'**
  String get applePayNote;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// No description provided for @setAsDefaultSub.
  ///
  /// In en, this message translates to:
  /// **'Use this method for future requests'**
  String get setAsDefaultSub;

  /// No description provided for @savePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Save Payment Method'**
  String get savePaymentMethod;

  /// No description provided for @errCardName.
  ///
  /// In en, this message translates to:
  /// **'Enter the name as it appears on the card.'**
  String get errCardName;

  /// No description provided for @errCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid card number.'**
  String get errCardNumber;

  /// No description provided for @errCardExpiry.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid expiry date (MM/YY).'**
  String get errCardExpiry;

  /// No description provided for @errCardCvv.
  ///
  /// In en, this message translates to:
  /// **'Enter the 3 or 4 digit security code.'**
  String get errCardCvv;

  /// No description provided for @errMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter the mobile number with the country code, e.g. +254 712 345 678.'**
  String get errMobileNumber;

  /// No description provided for @errRegisteredName.
  ///
  /// In en, this message translates to:
  /// **'Enter the name registered with the provider.'**
  String get errRegisteredName;

  /// No description provided for @cardExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String cardExpires(String date);

  /// No description provided for @holdersIphone.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s iPhone'**
  String holdersIphone(String name);

  /// No description provided for @errPaymentSettingsLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load your payment settings. Please try again.'**
  String get errPaymentSettingsLoad;

  /// No description provided for @errPaymentSettingsSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save the change. Please try again.'**
  String get errPaymentSettingsSave;

  /// No description provided for @noPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'No payment method yet. Add one to pay for delivery requests.'**
  String get noPaymentMethods;

  /// No description provided for @noPayoutAccount.
  ///
  /// In en, this message translates to:
  /// **'No payout account yet.'**
  String get noPayoutAccount;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @faceScanLivenessNote.
  ///
  /// In en, this message translates to:
  /// **'Biometric AI performs real-time liveness check to confirm you are the verified document holder.'**
  String get faceScanLivenessNote;

  /// No description provided for @deliveryPayoutRelease.
  ///
  /// In en, this message translates to:
  /// **'Delivery & Payout Release'**
  String get deliveryPayoutRelease;

  /// No description provided for @confirmDeliveryStep.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 4: Confirm Delivery'**
  String get confirmDeliveryStep;

  /// No description provided for @itemArrivedAtDestination.
  ///
  /// In en, this message translates to:
  /// **'Item Arrived at Destination'**
  String get itemArrivedAtDestination;

  /// No description provided for @confirmHandoffNote.
  ///
  /// In en, this message translates to:
  /// **'Ask the recipient for their 4-digit delivery code and enter it below. The right code confirms the delivery and sends your payout.'**
  String get confirmHandoffNote;

  /// No description provided for @pinOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'4-Digit Delivery Code'**
  String get pinOptionTitle;

  /// No description provided for @instantRelease.
  ///
  /// In en, this message translates to:
  /// **'Instant Release'**
  String get instantRelease;

  /// No description provided for @pinOptionNote.
  ///
  /// In en, this message translates to:
  /// **'The sender shared a secret 4-digit code with the recipient. Enter it below:'**
  String get pinOptionNote;

  /// No description provided for @pinConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Valid recipient PIN confirmed'**
  String get pinConfirmed;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'This PIN doesn\'t match the recipient\'s code.'**
  String get pinMismatch;

  /// No description provided for @photoOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Option 2: Handoff Photo Proof'**
  String get photoOptionTitle;

  /// No description provided for @alternative.
  ///
  /// In en, this message translates to:
  /// **'Alternative'**
  String get alternative;

  /// No description provided for @noHandoffPhoto.
  ///
  /// In en, this message translates to:
  /// **'No handoff photo yet'**
  String get noHandoffPhoto;

  /// No description provided for @handoffPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'A photo of the sealed item being handed over'**
  String get handoffPhotoHint;

  /// No description provided for @sealIntactPhoto.
  ///
  /// In en, this message translates to:
  /// **'Package seal intact'**
  String get sealIntactPhoto;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @payoutDestination.
  ///
  /// In en, this message translates to:
  /// **'Traveler Payout Destination'**
  String get payoutDestination;

  /// No description provided for @payoutAmount.
  ///
  /// In en, this message translates to:
  /// **'+{amount} Payout'**
  String payoutAmount(String amount);

  /// No description provided for @noPayoutAccountForRelease.
  ///
  /// In en, this message translates to:
  /// **'No payout account yet. Add one in Payment Settings; the payout will be sent there.'**
  String get noPayoutAccountForRelease;

  /// No description provided for @mobileMoneyPayoutSpeed.
  ///
  /// In en, this message translates to:
  /// **'Mobile money · Instant release'**
  String get mobileMoneyPayoutSpeed;

  /// No description provided for @bankPayoutSpeed.
  ///
  /// In en, this message translates to:
  /// **'Direct bank transfer · 1 business day'**
  String get bankPayoutSpeed;

  /// No description provided for @disputeProtectionWindow.
  ///
  /// In en, this message translates to:
  /// **'Dispute Protection Window'**
  String get disputeProtectionWindow;

  /// No description provided for @threeDaysActive.
  ///
  /// In en, this message translates to:
  /// **'3 Days Active'**
  String get threeDaysActive;

  /// No description provided for @disputeProtectionNote.
  ///
  /// In en, this message translates to:
  /// **'Your payout is sent as soon as the code is confirmed. The sender can still report a problem within 3 days.'**
  String get disputeProtectionNote;

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an issue or open a dispute'**
  String get reportIssue;

  /// No description provided for @confirmReleasePayout.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Release Payout ({amount})'**
  String confirmReleasePayout(String amount);

  /// No description provided for @requestUpdated.
  ///
  /// In en, this message translates to:
  /// **'Request updated'**
  String get requestUpdated;

  /// No description provided for @errRequestNotFound.
  ///
  /// In en, this message translates to:
  /// **'This request no longer exists.'**
  String get errRequestNotFound;

  /// No description provided for @errRequestNotEditable.
  ///
  /// In en, this message translates to:
  /// **'The traveler already answered this request, so it can\'t be changed anymore.'**
  String get errRequestNotEditable;

  /// No description provided for @editRequest.
  ///
  /// In en, this message translates to:
  /// **'Edit Request'**
  String get editRequest;

  /// No description provided for @saveChangesWithPrice.
  ///
  /// In en, this message translates to:
  /// **'Save changes · {price}'**
  String saveChangesWithPrice(String price);

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @statusInTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get statusInTransit;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @noSentRequests.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t sent any requests yet.'**
  String get noSentRequests;

  /// No description provided for @errLoadRequests.
  ///
  /// In en, this message translates to:
  /// **'Could not load your requests.'**
  String get errLoadRequests;

  /// No description provided for @tapToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit'**
  String get tapToEdit;

  /// No description provided for @errIdNameMismatch.
  ///
  /// In en, this message translates to:
  /// **'The name on this ID doesn\'t match the name on your profile. Upload an ID showing your first and last name, or update your profile name.'**
  String get errIdNameMismatch;

  /// No description provided for @errContactSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save the contact. Please try again.'**
  String get errContactSave;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Nata {latest} is available. You are using version {current}.'**
  String updateAvailableBody(String latest, String current);

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version of Nata is no longer supported. Please update to keep using the app.'**
  String get updateRequiredBody;

  /// No description provided for @updateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updateWhatsNew;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the store. Please search for Nata in your app store.'**
  String get updateOpenFailed;

  /// No description provided for @errAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found for this number. Please sign up first.'**
  String get errAccountNotFound;

  /// No description provided for @itemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsTitle;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// No description provided for @itemNumber.
  ///
  /// In en, this message translates to:
  /// **'Item {number}'**
  String itemNumber(int number);

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeItem;

  /// No description provided for @addAnotherItem.
  ///
  /// In en, this message translates to:
  /// **'Add another item'**
  String get addAnotherItem;

  /// No description provided for @errItemNameN.
  ///
  /// In en, this message translates to:
  /// **'Tell us what item {number} is.'**
  String errItemNameN(int number);

  /// No description provided for @itemsMaxNote.
  ///
  /// In en, this message translates to:
  /// **'You can send up to {max} items in one request.'**
  String itemsMaxNote(int max);

  /// No description provided for @errRecipientName.
  ///
  /// In en, this message translates to:
  /// **'Enter the recipient\'s full name.'**
  String get errRecipientName;

  /// No description provided for @errRecipientPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number for the recipient.'**
  String get errRecipientPhone;

  /// No description provided for @errWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter the package weight, e.g. 0.9 kg.'**
  String get errWeight;

  /// No description provided for @errPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one photo of the sealed item.'**
  String get errPhotoRequired;

  /// No description provided for @errPhotoTooBig.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large (max 10 MB).'**
  String get errPhotoTooBig;

  /// No description provided for @errPhotoLimit.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 3 photos.'**
  String get errPhotoLimit;

  /// No description provided for @errTripUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This trip is no longer available.'**
  String get errTripUnavailable;

  /// No description provided for @errOwnTrip.
  ///
  /// In en, this message translates to:
  /// **'You can\'t send a parcel with your own trip.'**
  String get errOwnTrip;

  /// No description provided for @errDuplicate.
  ///
  /// In en, this message translates to:
  /// **'You already have an open request on this trip.'**
  String get errDuplicate;

  /// No description provided for @errDestinationLimit.
  ///
  /// In en, this message translates to:
  /// **'You already have 5 open requests going to {city}. You can send another once one of them is delivered, declined or expires.'**
  String errDestinationLimit(String city);

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get cancelRequest;

  /// No description provided for @cancelRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this request?'**
  String get cancelRequestTitle;

  /// No description provided for @cancelRequestFreeBody.
  ///
  /// In en, this message translates to:
  /// **'The traveler hasn\'t accepted yet, so cancelling is free.'**
  String get cancelRequestFreeBody;

  /// No description provided for @cancelRequestFeeBody.
  ///
  /// In en, this message translates to:
  /// **'The traveler already accepted this request. Cancelling now costs a 10% cancellation fee of {fee}.'**
  String cancelRequestFeeBody(String fee);

  /// No description provided for @keepRequest.
  ///
  /// In en, this message translates to:
  /// **'Keep request'**
  String get keepRequest;

  /// No description provided for @cancelWithFee.
  ///
  /// In en, this message translates to:
  /// **'Cancel and pay {fee}'**
  String cancelWithFee(String fee);

  /// No description provided for @requestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get requestCancelled;

  /// No description provided for @cancellationFeeCharged.
  ///
  /// In en, this message translates to:
  /// **'Cancellation fee: {fee}'**
  String cancellationFeeCharged(String fee);

  /// No description provided for @cancelledFreeOfCharge.
  ///
  /// In en, this message translates to:
  /// **'Cancelled free of charge'**
  String get cancelledFreeOfCharge;

  /// No description provided for @errFeeChanged.
  ///
  /// In en, this message translates to:
  /// **'The traveler just answered this request, so the cancellation fee has changed. Please check and try again.'**
  String get errFeeChanged;

  /// No description provided for @errNotCancellable.
  ///
  /// In en, this message translates to:
  /// **'This request can no longer be cancelled.'**
  String get errNotCancellable;

  /// No description provided for @errCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel your request. Please try again.'**
  String get errCancelFailed;

  /// No description provided for @sentRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'SENT REQUESTS ({count})'**
  String sentRequestsCount(int count);

  /// No description provided for @waitingForTraveler.
  ///
  /// In en, this message translates to:
  /// **'Waiting for traveler'**
  String get waitingForTraveler;

  /// No description provided for @routeLabel.
  ///
  /// In en, this message translates to:
  /// **'Route:'**
  String get routeLabel;

  /// No description provided for @travelerDeliveries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Traveler · New} =1{Traveler · 1 delivery} other{Traveler · {count} deliveries}}'**
  String travelerDeliveries(int count);

  /// No description provided for @errSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get errSessionExpired;

  /// No description provided for @errInvalidRequest.
  ///
  /// In en, this message translates to:
  /// **'Some details were rejected. Please check the form.'**
  String get errInvalidRequest;

  /// No description provided for @errRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your request. Please try again.'**
  String get errRequestFailed;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. The traveler will review it.'**
  String get requestSent;

  /// No description provided for @travelerMaxKg.
  ///
  /// In en, this message translates to:
  /// **'Max {kg} kg'**
  String travelerMaxKg(String kg);

  /// No description provided for @errWeightTooHeavy.
  ///
  /// In en, this message translates to:
  /// **'This traveler accepts up to {max} kg.'**
  String errWeightTooHeavy(String max);

  /// No description provided for @photosAttachedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No photos} =1{1 photo attached} other{{count} photos attached}}'**
  String photosAttachedCount(int count);

  /// No description provided for @sendRequestWithPrice.
  ///
  /// In en, this message translates to:
  /// **'Send Request · {price}'**
  String sendRequestWithPrice(String price);

  /// No description provided for @packageSize.
  ///
  /// In en, this message translates to:
  /// **'Package Size'**
  String get packageSize;

  /// No description provided for @sizeEnvelope.
  ///
  /// In en, this message translates to:
  /// **'Envelope / Document'**
  String get sizeEnvelope;

  /// No description provided for @sizeShoebox.
  ///
  /// In en, this message translates to:
  /// **'Shoebox'**
  String get sizeShoebox;

  /// No description provided for @sizeBackpack.
  ///
  /// In en, this message translates to:
  /// **'Backpack'**
  String get sizeBackpack;

  /// No description provided for @errSizeRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the package size.'**
  String get errSizeRequired;

  /// No description provided for @errSizeTooBig.
  ///
  /// In en, this message translates to:
  /// **'This package is bigger than the traveler accepts.'**
  String get errSizeTooBig;

  /// No description provided for @errPriceChanged.
  ///
  /// In en, this message translates to:
  /// **'The price has changed since you opened this request. Go back and open it again to see the new price.'**
  String get errPriceChanged;

  /// No description provided for @priceEnterWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter the package weight to see the final price.'**
  String get priceEnterWeight;

  /// No description provided for @priceRateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate unavailable, so prices are shown in US dollars.'**
  String get priceRateUnavailable;

  /// No description provided for @priceCredit.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates by Exchange Rate API'**
  String get priceCredit;

  /// No description provided for @priceCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating the price…'**
  String get priceCalculating;

  /// No description provided for @errQuoteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate the price. Check your connection and try again.'**
  String get errQuoteUnavailable;

  /// No description provided for @priceBasedOn.
  ///
  /// In en, this message translates to:
  /// **'Based on distance ({km} km), weight & delivery date'**
  String priceBasedOn(String km);

  /// No description provided for @priceRateLine.
  ///
  /// In en, this message translates to:
  /// **'1 USD = {rate} {currency} · updated {date}'**
  String priceRateLine(String rate, String currency, String date);

  /// No description provided for @departingFrom.
  ///
  /// In en, this message translates to:
  /// **'Departing From'**
  String get departingFrom;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello,'**
  String get hello;

  /// No description provided for @whereAreYouSending.
  ///
  /// In en, this message translates to:
  /// **'Where are you sending?'**
  String get whereAreYouSending;

  /// No description provided for @whereSendingFrom.
  ///
  /// In en, this message translates to:
  /// **'Where are you sending from?'**
  String get whereSendingFrom;

  /// No description provided for @destinationExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. London, United Kingdom'**
  String get destinationExample;

  /// No description provided for @anytimeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Anytime this month'**
  String get anytimeThisMonth;

  /// No description provided for @flexibleShort.
  ///
  /// In en, this message translates to:
  /// **'(±3d)'**
  String get flexibleShort;

  /// No description provided for @availableTravelers.
  ///
  /// In en, this message translates to:
  /// **'Available Travelers'**
  String get availableTravelers;

  /// No description provided for @errLoadTravelers.
  ///
  /// In en, this message translates to:
  /// **'Could not load travelers.'**
  String get errLoadTravelers;

  /// No description provided for @noTravelersOnRoute.
  ///
  /// In en, this message translates to:
  /// **'No travelers on this route yet.'**
  String get noTravelersOnRoute;

  /// No description provided for @desiredDeliveryDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Desired Delivery Date'**
  String get desiredDeliveryDateTitle;

  /// No description provided for @upToKg.
  ///
  /// In en, this message translates to:
  /// **'Up to {weight} kg'**
  String upToKg(String weight);

  /// No description provided for @dateAnytime.
  ///
  /// In en, this message translates to:
  /// **'Anytime'**
  String get dateAnytime;

  /// No description provided for @dateThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get dateThisWeek;

  /// No description provided for @dateNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next Week'**
  String get dateNextWeek;

  /// No description provided for @dateFlexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible (±3d)'**
  String get dateFlexible;

  /// No description provided for @travelerFlightsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 traveler flight} other{{count} traveler flights}}'**
  String travelerFlightsCount(int count);

  /// No description provided for @flightsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 flight} other{{count} flights}}'**
  String flightsCount(int count);

  /// No description provided for @plusMinus3Days.
  ///
  /// In en, this message translates to:
  /// **'±3 days'**
  String get plusMinus3Days;

  /// No description provided for @anyDate.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get anyDate;

  /// No description provided for @selectADate.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get selectADate;

  /// No description provided for @confirmDateOn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Date ({date})'**
  String confirmDateOn(String date);

  /// No description provided for @confirmDateAnytime.
  ///
  /// In en, this message translates to:
  /// **'Confirm Date (Anytime)'**
  String get confirmDateAnytime;

  /// No description provided for @searchCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Search country...'**
  String get searchCountryHint;

  /// No description provided for @searchCityIn.
  ///
  /// In en, this message translates to:
  /// **'Search city in {country}...'**
  String searchCityIn(String country);

  /// No description provided for @selectCityTitle.
  ///
  /// In en, this message translates to:
  /// **'Select City'**
  String get selectCityTitle;

  /// No description provided for @noCountriesFound.
  ///
  /// In en, this message translates to:
  /// **'No countries found'**
  String get noCountriesFound;

  /// No description provided for @noCitiesFoundIn.
  ///
  /// In en, this message translates to:
  /// **'No cities found in {country}'**
  String noCitiesFoundIn(String country);

  /// No description provided for @selectCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Select Country Code'**
  String get selectCountryCode;

  /// No description provided for @errLoadTravelersRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load travelers. Please try again.'**
  String get errLoadTravelersRetry;

  /// No description provided for @anywhere.
  ///
  /// In en, this message translates to:
  /// **'Anywhere'**
  String get anywhere;

  /// No description provided for @byDate.
  ///
  /// In en, this message translates to:
  /// **'by {date}'**
  String byDate(String date);

  /// No description provided for @noTravelersOnRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'No travelers on this route yet'**
  String get noTravelersOnRouteTitle;

  /// No description provided for @tryAnotherDateOrRoute.
  ///
  /// In en, this message translates to:
  /// **'Try another date or route, or turn on alerts below.'**
  String get tryAnotherDateOrRoute;

  /// No description provided for @travelersFound.
  ///
  /// In en, this message translates to:
  /// **'Travelers Found'**
  String get travelersFound;

  /// No description provided for @notifyNewTravelers.
  ///
  /// In en, this message translates to:
  /// **'Get notified immediately when new travelers add trips on this route.'**
  String get notifyNewTravelers;

  /// No description provided for @capacityNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Capacity not specified'**
  String get capacityNotSpecified;

  /// No description provided for @acceptsUpToKg.
  ///
  /// In en, this message translates to:
  /// **'Accepts up to {weight} kg'**
  String acceptsUpToKg(String weight);

  /// No description provided for @arrivingIn.
  ///
  /// In en, this message translates to:
  /// **'Arriving In'**
  String get arrivingIn;

  /// No description provided for @departureDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Departure Date'**
  String get departureDateTitle;

  /// No description provided for @arrivalDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrival Date'**
  String get arrivalDateTitle;

  /// No description provided for @errOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open that file.'**
  String get errOpenFile;

  /// No description provided for @errFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is too large (max 10 MB).'**
  String get errFileTooLarge;

  /// No description provided for @departureDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Departure details'**
  String get departureDetailsTitle;

  /// No description provided for @arrivalDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrival details'**
  String get arrivalDetailsTitle;

  /// No description provided for @departureCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'DEPARTURE COUNTRY'**
  String get departureCountryLabel;

  /// No description provided for @departureCityLabel.
  ///
  /// In en, this message translates to:
  /// **'DEPARTURE CITY'**
  String get departureCityLabel;

  /// No description provided for @arrivalCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'ARRIVAL COUNTRY'**
  String get arrivalCountryLabel;

  /// No description provided for @arrivalCityLabel.
  ///
  /// In en, this message translates to:
  /// **'ARRIVAL CITY'**
  String get arrivalCityLabel;

  /// No description provided for @receiptOnFile.
  ///
  /// In en, this message translates to:
  /// **'Receipt on file'**
  String get receiptOnFile;

  /// No description provided for @bookingRefHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. X7KQ9R'**
  String get bookingRefHint;

  /// No description provided for @deliveriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 delivery} other{{count} deliveries}}'**
  String deliveriesCount(int count);

  /// No description provided for @availableCount.
  ///
  /// In en, this message translates to:
  /// **'{count} available'**
  String availableCount(int count);

  /// No description provided for @deliveredCount.
  ///
  /// In en, this message translates to:
  /// **'{count} delivered'**
  String deliveredCount(int count);

  /// No description provided for @flightsShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 flt} other{{count} flts}}'**
  String flightsShort(int count);

  /// No description provided for @amountPerDelivery.
  ///
  /// In en, this message translates to:
  /// **'{amount} / delivery'**
  String amountPerDelivery(String amount);

  /// No description provided for @countries180.
  ///
  /// In en, this message translates to:
  /// **'180+ Countries'**
  String get countries180;

  /// No description provided for @errEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number.'**
  String get errEnterPhone;

  /// No description provided for @errTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment.'**
  String get errTooManyRequests;

  /// No description provided for @errTooManyRequestsRetry.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get errTooManyRequestsRetry;

  /// No description provided for @errInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number. Please check and try again.'**
  String get errInvalidPhone;

  /// No description provided for @errSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errSomethingWrong;

  /// No description provided for @errFillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields.'**
  String get errFillAllFields;

  /// No description provided for @countryOfResidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'COUNTRY OF RESIDENCE'**
  String get countryOfResidenceLabel;

  /// No description provided for @errVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Please try again.'**
  String get errVerificationFailed;

  /// No description provided for @errCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Please request a new one.'**
  String get errCodeExpired;

  /// No description provided for @errOtpDisabled.
  ///
  /// In en, this message translates to:
  /// **'Phone verification is not enabled. Please contact support.'**
  String get errOtpDisabled;

  /// No description provided for @errIncorrectCode.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. Please try again.'**
  String get errIncorrectCode;

  /// No description provided for @errTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait before retrying.'**
  String get errTooManyAttempts;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get errNetwork;

  /// No description provided for @errIncorrectOrExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code or code expired. Please try again.'**
  String get errIncorrectOrExpiredCode;

  /// No description provided for @enterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get enterVerificationCode;

  /// No description provided for @otpSentToPrefix.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to '**
  String get otpSentToPrefix;

  /// No description provided for @verifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyCode;

  /// No description provided for @resendCodeInPrefix.
  ///
  /// In en, this message translates to:
  /// **'Resend code in '**
  String get resendCodeInPrefix;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @otpNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? Check that your phone number is correct and that you have network coverage.'**
  String get otpNotReceived;

  /// No description provided for @verifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhone;

  /// No description provided for @errCaptureIdFirst.
  ///
  /// In en, this message translates to:
  /// **'Please capture or upload your ID document first.'**
  String get errCaptureIdFirst;

  /// No description provided for @errUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get errUploadFailed;

  /// No description provided for @uploadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploadingEllipsis;

  /// No description provided for @submitForVerification.
  ///
  /// In en, this message translates to:
  /// **'Submit for Verification'**
  String get submitForVerification;

  /// No description provided for @documentSelected.
  ///
  /// In en, this message translates to:
  /// **'Document selected'**
  String get documentSelected;

  /// No description provided for @errCameraDetail.
  ///
  /// In en, this message translates to:
  /// **'Camera error: {error}'**
  String errCameraDetail(String error);

  /// No description provided for @errFilePicker.
  ///
  /// In en, this message translates to:
  /// **'File picker error: {error}'**
  String errFilePicker(String error);

  /// No description provided for @verifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedLabel;

  /// No description provided for @matchPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent} Match'**
  String matchPercent(String percent);

  /// No description provided for @requestExpiresInPrefix.
  ///
  /// In en, this message translates to:
  /// **'Request expires in '**
  String get requestExpiresInPrefix;

  /// No description provided for @escrowNotePart1.
  ///
  /// In en, this message translates to:
  /// **'Your payment is held safely by Nata. The traveler is only paid '**
  String get escrowNotePart1;

  /// No description provided for @escrowNotePart2.
  ///
  /// In en, this message translates to:
  /// **'after your recipient verifies delivery'**
  String get escrowNotePart2;

  /// No description provided for @escrowNotePart3.
  ///
  /// In en, this message translates to:
  /// **' with your secret 4-digit code or photo proof.'**
  String get escrowNotePart3;

  /// No description provided for @itemPlain.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get itemPlain;

  /// No description provided for @weightPlain.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightPlain;

  /// No description provided for @refundFullBold.
  ///
  /// In en, this message translates to:
  /// **'Full 100% refund'**
  String get refundFullBold;

  /// No description provided for @refundFullRest.
  ///
  /// In en, this message translates to:
  /// **'if traveler cancels or item is not delivered.'**
  String get refundFullRest;

  /// No description provided for @cancelFeeBold.
  ///
  /// In en, this message translates to:
  /// **'10% cancellation fee'**
  String get cancelFeeBold;

  /// No description provided for @cancelFeeRest.
  ///
  /// In en, this message translates to:
  /// **'if you cancel after the traveler accepted, until handoff.'**
  String get cancelFeeRest;

  /// No description provided for @disputeWindowBold.
  ///
  /// In en, this message translates to:
  /// **'3 days to report a problem'**
  String get disputeWindowBold;

  /// No description provided for @disputeWindowRest.
  ///
  /// In en, this message translates to:
  /// **'after delivery; support follows up on every report.'**
  String get disputeWindowRest;

  /// No description provided for @reviewTagIntact.
  ///
  /// In en, this message translates to:
  /// **'Item was intact'**
  String get reviewTagIntact;

  /// No description provided for @reviewTagOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get reviewTagOnTime;

  /// No description provided for @reviewTagCommunicator.
  ///
  /// In en, this message translates to:
  /// **'Great communicator'**
  String get reviewTagCommunicator;

  /// No description provided for @reviewTagRules.
  ///
  /// In en, this message translates to:
  /// **'Followed all rules'**
  String get reviewTagRules;

  /// No description provided for @reviewTagHandoff.
  ///
  /// In en, this message translates to:
  /// **'Smooth handoff'**
  String get reviewTagHandoff;

  /// No description provided for @reviewTagAgain.
  ///
  /// In en, this message translates to:
  /// **'Would use again'**
  String get reviewTagAgain;

  /// No description provided for @deliveredYourItem.
  ///
  /// In en, this message translates to:
  /// **'Delivered your {item} · {date}'**
  String deliveredYourItem(String item, String date);

  /// No description provided for @expiryHint.
  ///
  /// In en, this message translates to:
  /// **'MM/YY'**
  String get expiryHint;

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated successfully'**
  String get profilePictureUpdated;

  /// No description provided for @errUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload image: {error}'**
  String errUploadImage(String error);

  /// No description provided for @senderEscrowFunded.
  ///
  /// In en, this message translates to:
  /// **'Sender · Escrow Funded'**
  String get senderEscrowFunded;

  /// No description provided for @senderDeliveries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Sender · 1 delivery} other{Sender · {count} deliveries}}'**
  String senderDeliveries(int count);

  /// No description provided for @sealedPhotosAttached.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 factory-sealed photo attached} other{{count} factory-sealed photos attached}}'**
  String sealedPhotosAttached(int count);

  /// No description provided for @capturedAt.
  ///
  /// In en, this message translates to:
  /// **'Captured at {place} · {time}'**
  String capturedAt(String place, String time);

  /// No description provided for @txDeliveryOf.
  ///
  /// In en, this message translates to:
  /// **'{item} delivery'**
  String txDeliveryOf(String item);

  /// No description provided for @txReleasedFromEscrow.
  ///
  /// In en, this message translates to:
  /// **'Released from escrow · {date}'**
  String txReleasedFromEscrow(String date);

  /// No description provided for @txEscrowHold.
  ///
  /// In en, this message translates to:
  /// **'Escrow hold'**
  String get txEscrowHold;

  /// No description provided for @txDeliveryRequest.
  ///
  /// In en, this message translates to:
  /// **'Delivery request · {date}'**
  String txDeliveryRequest(String date);

  /// No description provided for @priceEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'This is an estimate in {currency} at today\'s rate. The price is fixed when the traveler accepts.'**
  String priceEstimateNote(String currency);

  /// No description provided for @estimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get estimateLabel;

  /// No description provided for @errRateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The exchange rate isn\'t available right now, so the price can\'t be fixed. Please try again later.'**
  String get errRateUnavailable;

  /// No description provided for @errRequestNotPending.
  ///
  /// In en, this message translates to:
  /// **'This request has already been answered.'**
  String get errRequestNotPending;

  /// No description provided for @chatLockedUntilPayment.
  ///
  /// In en, this message translates to:
  /// **'Chat unlocks once the delivery is paid. Your payment stays in escrow until delivery is confirmed.'**
  String get chatLockedUntilPayment;

  /// No description provided for @chatMeetInPublicTitle.
  ///
  /// In en, this message translates to:
  /// **'Meet in a public place'**
  String get chatMeetInPublicTitle;

  /// No description provided for @chatMeetInPublicBody.
  ///
  /// In en, this message translates to:
  /// **'For pickup and handover, always meet somewhere busy and public, like an airport, a station or a café. Never go to a private address.'**
  String get chatMeetInPublicBody;

  /// No description provided for @chatClosedAfterDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery complete. This chat is closed, but you can still read it.'**
  String get chatClosedAfterDelivery;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @messageLocked.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageLocked;

  /// No description provided for @messageUnlocksAfterPayment.
  ///
  /// In en, this message translates to:
  /// **'Messaging unlocks after payment.'**
  String get messageUnlocksAfterPayment;

  /// No description provided for @escrowFunded.
  ///
  /// In en, this message translates to:
  /// **'Escrow funded'**
  String get escrowFunded;

  /// No description provided for @maxDims.
  ///
  /// In en, this message translates to:
  /// **'Max {dims}'**
  String maxDims(String dims);

  /// No description provided for @errRequestNotPayable.
  ///
  /// In en, this message translates to:
  /// **'This request can no longer be paid.'**
  String get errRequestNotPayable;

  /// No description provided for @step1ValidateTicket.
  ///
  /// In en, this message translates to:
  /// **'STEP 1 · VALIDATE FLIGHT TICKET'**
  String get step1ValidateTicket;

  /// No description provided for @step2PaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'STEP 2 · SELECT PAYMENT METHOD'**
  String get step2PaymentMethod;

  /// No description provided for @idMeetingTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Check their ID when you meet.'**
  String get idMeetingTipTitle;

  /// No description provided for @idMeetingTipBody.
  ///
  /// In en, this message translates to:
  /// **'When you hand over the item, ask {name} to show their ID and make sure the name matches the ticket.'**
  String idMeetingTipBody(String name);

  /// No description provided for @ticketNotValidated.
  ///
  /// In en, this message translates to:
  /// **'Not validated'**
  String get ticketNotValidated;

  /// No description provided for @ticketValidated.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get ticketValidated;

  /// No description provided for @ticketIntro.
  ///
  /// In en, this message translates to:
  /// **'{name} uploaded their flight ticket for this trip. Check it matches the route and date before you pay.'**
  String ticketIntro(String name);

  /// No description provided for @viewFullTicket.
  ///
  /// In en, this message translates to:
  /// **'View full ticket'**
  String get viewFullTicket;

  /// No description provided for @ticketPdf.
  ///
  /// In en, this message translates to:
  /// **'Flight ticket (PDF)'**
  String get ticketPdf;

  /// No description provided for @ticketRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get ticketRoute;

  /// No description provided for @ticketDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get ticketDeparture;

  /// No description provided for @ticketBookingRef.
  ///
  /// In en, this message translates to:
  /// **'Booking reference'**
  String get ticketBookingRef;

  /// No description provided for @ticketTraveler.
  ///
  /// In en, this message translates to:
  /// **'Traveler'**
  String get ticketTraveler;

  /// No description provided for @iCheckedTicket.
  ///
  /// In en, this message translates to:
  /// **'I\'ve checked this ticket'**
  String get iCheckedTicket;

  /// No description provided for @errTicketLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load the ticket.'**
  String get errTicketLoad;

  /// No description provided for @noTicketUploaded.
  ///
  /// In en, this message translates to:
  /// **'The traveler hasn\'t uploaded a ticket for this trip yet, so payment stays locked.'**
  String get noTicketUploaded;

  /// No description provided for @validateToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Validate ticket to unlock payment'**
  String get validateToUnlock;

  /// No description provided for @payAmountIntoEscrow.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} into Escrow'**
  String payAmountIntoEscrow(String amount);

  /// No description provided for @requestExpiredPayment.
  ///
  /// In en, this message translates to:
  /// **'This request has expired and can no longer be paid.'**
  String get requestExpiredPayment;

  /// No description provided for @hoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String hoursMinutes(int hours, int minutes);

  /// No description provided for @idSharedWithSendersNote.
  ///
  /// In en, this message translates to:
  /// **'When you accept a request, that sender will see the photo on your ID and your verified name, so they can check you match your ticket. The rest of your ID stays private.'**
  String get idSharedWithSendersNote;

  /// No description provided for @errTicketNameMismatch.
  ///
  /// In en, this message translates to:
  /// **'The name on this ticket doesn\'t match your profile name. Upload a ticket in your name, or update your profile name.'**
  String get errTicketNameMismatch;

  /// No description provided for @errTicketDateMismatch.
  ///
  /// In en, this message translates to:
  /// **'This ticket isn\'t for {date}. Check the trip\'s dates, or upload the ticket for this flight.'**
  String errTicketDateMismatch(String date);

  /// No description provided for @errTicketUnreadable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read this ticket. Upload a sharp photo or the PDF of your boarding pass or e-ticket.'**
  String get errTicketUnreadable;

  /// No description provided for @checkingTicket.
  ///
  /// In en, this message translates to:
  /// **'Checking your ticket…'**
  String get checkingTicket;

  /// No description provided for @noIncomingRequests.
  ///
  /// In en, this message translates to:
  /// **'No delivery requests yet. They\'ll appear here when senders ask you to carry something on your trips.'**
  String get noIncomingRequests;

  /// No description provided for @senderAwaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Sender · Awaiting payment'**
  String get senderAwaitingPayment;

  /// No description provided for @senderItemWithYou.
  ///
  /// In en, this message translates to:
  /// **'Sender · Item with you'**
  String get senderItemWithYou;

  /// No description provided for @senderDelivered.
  ///
  /// In en, this message translates to:
  /// **'Sender · Delivered'**
  String get senderDelivered;

  /// No description provided for @nextWaitPayment.
  ///
  /// In en, this message translates to:
  /// **'Wait for the sender\'s payment'**
  String get nextWaitPayment;

  /// No description provided for @nextPickUp.
  ///
  /// In en, this message translates to:
  /// **'Pick up the item'**
  String get nextPickUp;

  /// No description provided for @nextDeliver.
  ///
  /// In en, this message translates to:
  /// **'Deliver and enter the code'**
  String get nextDeliver;

  /// No description provided for @nextDone.
  ///
  /// In en, this message translates to:
  /// **'Payout released'**
  String get nextDone;

  /// No description provided for @viewRequest.
  ///
  /// In en, this message translates to:
  /// **'View Request'**
  String get viewRequest;

  /// No description provided for @requestAcceptedSnack.
  ///
  /// In en, this message translates to:
  /// **'Request accepted. The sender has 24 hours to pay.'**
  String get requestAcceptedSnack;

  /// No description provided for @requestDeclinedSnack.
  ///
  /// In en, this message translates to:
  /// **'Request declined.'**
  String get requestDeclinedSnack;

  /// No description provided for @declineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this request?'**
  String get declineTitle;

  /// No description provided for @declineBody.
  ///
  /// In en, this message translates to:
  /// **'The sender will be told you can\'t carry it.'**
  String get declineBody;

  /// No description provided for @declineReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get declineReasonHint;

  /// No description provided for @keepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepIt;

  /// No description provided for @errAcceptFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not accept the request. Please try again.'**
  String get errAcceptFailed;

  /// No description provided for @errDeclineFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not decline the request. Please try again.'**
  String get errDeclineFailed;

  /// No description provided for @requestDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Details'**
  String get requestDetailsTitle;

  /// No description provided for @answerWithin.
  ///
  /// In en, this message translates to:
  /// **'Answer within {time}'**
  String answerWithin(String time);

  /// No description provided for @payDueWithin.
  ///
  /// In en, this message translates to:
  /// **'The sender must pay within {time}'**
  String payDueWithin(String time);

  /// No description provided for @itemPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'PHOTOS OF THE SEALED ITEM'**
  String get itemPhotosTitle;

  /// No description provided for @recipientHiddenNote.
  ///
  /// In en, this message translates to:
  /// **'The recipient\'s name and phone are shared once you accept.'**
  String get recipientHiddenNote;

  /// No description provided for @senderVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get senderVerifiedBadge;

  /// No description provided for @rateYourTraveler.
  ///
  /// In en, this message translates to:
  /// **'Rate Your Traveler'**
  String get rateYourTraveler;

  /// No description provided for @deliveryCompleteLabel.
  ///
  /// In en, this message translates to:
  /// **'DELIVERY COMPLETE'**
  String get deliveryCompleteLabel;

  /// No description provided for @itemArrivedSafely.
  ///
  /// In en, this message translates to:
  /// **'Your item arrived safely'**
  String get itemArrivedSafely;

  /// No description provided for @reviewHelpsOthers.
  ///
  /// In en, this message translates to:
  /// **'Your review helps other senders find trusted travelers.'**
  String get reviewHelpsOthers;

  /// No description provided for @overallRating.
  ///
  /// In en, this message translates to:
  /// **'OVERALL RATING'**
  String get overallRating;

  /// No description provided for @tapStarToRate.
  ///
  /// In en, this message translates to:
  /// **'Tap a star to rate'**
  String get tapStarToRate;

  /// No description provided for @whatStoodOut.
  ///
  /// In en, this message translates to:
  /// **'WHAT STOOD OUT?'**
  String get whatStoodOut;

  /// No description provided for @tagCommunication.
  ///
  /// In en, this message translates to:
  /// **'Great communication'**
  String get tagCommunication;

  /// No description provided for @tagCareful.
  ///
  /// In en, this message translates to:
  /// **'Careful with item'**
  String get tagCareful;

  /// No description provided for @tagFlexiblePickup.
  ///
  /// In en, this message translates to:
  /// **'Flexible pickup'**
  String get tagFlexiblePickup;

  /// No description provided for @writtenReview.
  ///
  /// In en, this message translates to:
  /// **'WRITTEN REVIEW'**
  String get writtenReview;

  /// No description provided for @reviewHint.
  ///
  /// In en, this message translates to:
  /// **'Share how the handoff and delivery went. Keep it respectful and factual.'**
  String get reviewHint;

  /// No description provided for @reviewsFinal.
  ///
  /// In en, this message translates to:
  /// **'Reviews cannot be edited after they are published.'**
  String get reviewsFinal;

  /// No description provided for @reviewSharedNote.
  ///
  /// In en, this message translates to:
  /// **'Your rating is shared with {name} after you submit, and it is added to their public delivery history.'**
  String reviewSharedNote(String name);

  /// No description provided for @reviewThanksName.
  ///
  /// In en, this message translates to:
  /// **'Thanks for reviewing {name}. Your feedback helps the community stay trusted and safe.'**
  String reviewThanksName(String name);

  /// No description provided for @errReviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your review. Please try again.'**
  String get errReviewFailed;

  /// No description provided for @errAlreadyReviewed.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already reviewed this delivery.'**
  String get errAlreadyReviewed;

  /// No description provided for @errNotDelivered.
  ///
  /// In en, this message translates to:
  /// **'This item isn\'t marked as delivered yet.'**
  String get errNotDelivered;

  /// No description provided for @confirmReceipt.
  ///
  /// In en, this message translates to:
  /// **'Confirm Receipt'**
  String get confirmReceipt;

  /// No description provided for @youReviewed.
  ///
  /// In en, this message translates to:
  /// **'You reviewed this delivery'**
  String get youReviewed;

  /// No description provided for @errConfirmReceiptFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm receipt. Please try again.'**
  String get errConfirmReceiptFailed;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 review} other{{count} reviews}}'**
  String reviewsCount(int count);

  /// No description provided for @ticketImageHidden.
  ///
  /// In en, this message translates to:
  /// **'The ticket itself isn\'t shown because its booking reference couldn\'t be hidden. Nata checked the traveler\'s name and travel date on it when it was uploaded.'**
  String get ticketImageHidden;

  /// No description provided for @bookingRefHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden to protect the traveler\'s booking'**
  String get bookingRefHidden;

  /// No description provided for @completeYourPayment.
  ///
  /// In en, this message translates to:
  /// **'Complete your payment'**
  String get completeYourPayment;

  /// No description provided for @completeYourPaymentSub.
  ///
  /// In en, this message translates to:
  /// **'Finish paying on the payment page. This page updates by itself once the payment goes through.'**
  String get completeYourPaymentSub;

  /// No description provided for @openPaymentPage.
  ///
  /// In en, this message translates to:
  /// **'Open payment page'**
  String get openPaymentPage;

  /// No description provided for @iPaidCheckNow.
  ///
  /// In en, this message translates to:
  /// **'I\'ve paid, check now'**
  String get iPaidCheckNow;

  /// No description provided for @chooseAnotherWayToPay.
  ///
  /// In en, this message translates to:
  /// **'Choose another way to pay'**
  String get chooseAnotherWayToPay;

  /// No description provided for @paymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received. The money is held in escrow until the delivery is done.'**
  String get paymentReceived;

  /// No description provided for @paymentNotReceivedYet.
  ///
  /// In en, this message translates to:
  /// **'We haven\'t received the payment yet. If you just paid, it can take a minute.'**
  String get paymentNotReceivedYet;

  /// No description provided for @errPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'The payment didn\'t go through. Please try again or choose another way to pay.'**
  String get errPaymentFailed;

  /// No description provided for @errPaymentStart.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the payment page. Please try again.'**
  String get errPaymentStart;

  /// No description provided for @errPaymentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payments aren\'t available right now. Please try again later.'**
  String get errPaymentsUnavailable;

  /// No description provided for @mobileMoneyCountry.
  ///
  /// In en, this message translates to:
  /// **'Mobile money country'**
  String get mobileMoneyCountry;

  /// No description provided for @chooseCountry.
  ///
  /// In en, this message translates to:
  /// **'Choose a country'**
  String get chooseCountry;

  /// No description provided for @mobileMoneyChargedAs.
  ///
  /// In en, this message translates to:
  /// **'Charged in your wallet\'s currency at today\'s rate: {local}. The delivery price stays {price}.'**
  String mobileMoneyChargedAs(String local, String price);

  /// No description provided for @errMobileMoneyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Mobile money isn\'t available for this country. Please choose another country or pay by card.'**
  String get errMobileMoneyUnavailable;

  /// No description provided for @errMobileMoneyOptions.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the mobile money countries.'**
  String get errMobileMoneyOptions;

  /// No description provided for @mobileMoneyNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get mobileMoneyNetwork;

  /// No description provided for @mobileMoneyNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile money number'**
  String get mobileMoneyNumber;

  /// No description provided for @mobileMoneyNumberNote.
  ///
  /// In en, this message translates to:
  /// **'You\'ll approve the payment on this phone, with no payment page.'**
  String get mobileMoneyNumberNote;

  /// No description provided for @enterMobileNumberToPay.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile money number'**
  String get enterMobileNumberToPay;

  /// No description provided for @approveOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Approve the payment on your phone'**
  String get approveOnPhone;

  /// No description provided for @approveOnPhoneSub.
  ///
  /// In en, this message translates to:
  /// **'We sent a request for {amount} to {phone}. Enter your PIN in the prompt to approve it. This page updates by itself.'**
  String approveOnPhoneSub(String amount, String phone);

  /// No description provided for @iApprovedCheckNow.
  ///
  /// In en, this message translates to:
  /// **'I\'ve approved, check now'**
  String get iApprovedCheckNow;

  /// No description provided for @errPhoneRejected.
  ///
  /// In en, this message translates to:
  /// **'This number can\'t be charged. Check the number and network, or choose another way to pay.'**
  String get errPhoneRejected;

  /// No description provided for @errMobileAmountOutOfBounds.
  ///
  /// In en, this message translates to:
  /// **'This amount is more or less than your mobile money network allows. Please choose another way to pay.'**
  String get errMobileAmountOutOfBounds;

  /// No description provided for @errMobileNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your mobile money network isn\'t answering right now. Please try again in a few minutes.'**
  String get errMobileNetworkUnavailable;

  /// No description provided for @signInPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInPromptTitle;

  /// No description provided for @signInPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Create a free account to send items with travelers, post your trips and follow your deliveries.'**
  String get signInPromptBody;

  /// No description provided for @signInPromptTraveler.
  ///
  /// In en, this message translates to:
  /// **'Create a free account to see {name}\'s profile and send a delivery request.'**
  String signInPromptTraveler(String name);

  /// No description provided for @signInPromptAddTrip.
  ///
  /// In en, this message translates to:
  /// **'Create a free account to post your trip and earn by carrying items.'**
  String get signInPromptAddTrip;

  /// No description provided for @signInBenefitVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified travelers only'**
  String get signInBenefitVerified;

  /// No description provided for @signInBenefitEscrow.
  ///
  /// In en, this message translates to:
  /// **'Payment held safely until delivery'**
  String get signInBenefitEscrow;

  /// No description provided for @signInBenefitPhone.
  ///
  /// In en, this message translates to:
  /// **'Sign up with your phone number in a minute'**
  String get signInBenefitPhone;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @cameraOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get cameraOffTitle;

  /// No description provided for @cameraOffBody.
  ///
  /// In en, this message translates to:
  /// **'Nata needs your camera to take this photo. Turn on Camera for Nata in your phone\'s Settings, then come back and try again.'**
  String get cameraOffBody;

  /// No description provided for @cameraOffPath.
  ///
  /// In en, this message translates to:
  /// **'Settings > Nata Delivery > Camera'**
  String get cameraOffPath;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @verifyPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity first'**
  String get verifyPromptTitle;

  /// No description provided for @verifyPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Your identity check is under review'**
  String get verifyPendingTitle;

  /// No description provided for @verifyPendingBody.
  ///
  /// In en, this message translates to:
  /// **'You can post trips and send requests once your ID is approved. We\'ll notify you.'**
  String get verifyPendingBody;

  /// No description provided for @verifyMyIdentity.
  ///
  /// In en, this message translates to:
  /// **'Verify my identity'**
  String get verifyMyIdentity;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @verifyToAddTrip.
  ///
  /// In en, this message translates to:
  /// **'Only verified travelers can post trips. It takes a few minutes: a photo of your ID and a selfie.'**
  String get verifyToAddTrip;

  /// No description provided for @verifyToSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Only verified members can send delivery requests. It takes a few minutes: a photo of your ID and a selfie.'**
  String get verifyToSendRequest;

  /// No description provided for @errNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity first: only verified members can do this.'**
  String get errNotVerified;

  /// No description provided for @errTripFull.
  ///
  /// In en, this message translates to:
  /// **'This trip already has 3 deliveries in progress. A place frees up when one is delivered.'**
  String get errTripFull;

  /// No description provided for @errSenderOnTrip.
  ///
  /// In en, this message translates to:
  /// **'You already have a delivery in progress from this sender on this trip.'**
  String get errSenderOnTrip;

  /// No description provided for @continueBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Continue browsing'**
  String get continueBrowsing;

  /// No description provided for @sortByDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by date'**
  String get sortByDate;

  /// No description provided for @sortEarliest.
  ///
  /// In en, this message translates to:
  /// **'Earliest'**
  String get sortEarliest;

  /// No description provided for @sortLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get sortLatest;

  /// No description provided for @sendWithTrustedTravelers.
  ///
  /// In en, this message translates to:
  /// **'Send with trusted travelers'**
  String get sendWithTrustedTravelers;

  /// No description provided for @guestHeroBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified travelers · Escrow payments'**
  String get guestHeroBadge;

  /// No description provided for @guestHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Send items abroad with a traveler already going there'**
  String get guestHeroTitle;

  /// No description provided for @guestHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Find a trusted traveler heading to your destination. Your payment is held safely until your recipient confirms delivery.'**
  String get guestHeroBody;

  /// No description provided for @createFreeAccount.
  ///
  /// In en, this message translates to:
  /// **'Create a free account'**
  String get createFreeAccount;

  /// No description provided for @travelersGoingSoon.
  ///
  /// In en, this message translates to:
  /// **'Travelers Going Soon'**
  String get travelersGoingSoon;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorks;

  /// No description provided for @howStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get howStep1Title;

  /// No description provided for @howStep1Body.
  ///
  /// In en, this message translates to:
  /// **'for a traveler going to your destination.'**
  String get howStep1Body;

  /// No description provided for @howStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Pay into escrow'**
  String get howStep2Title;

  /// No description provided for @howStep2Body.
  ///
  /// In en, this message translates to:
  /// **'once you have checked their ticket.'**
  String get howStep2Body;

  /// No description provided for @howStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Traveler is paid'**
  String get howStep3Title;

  /// No description provided for @howStep3Body.
  ///
  /// In en, this message translates to:
  /// **'after your recipient confirms delivery.'**
  String get howStep3Body;

  /// No description provided for @pickedUpItem.
  ///
  /// In en, this message translates to:
  /// **'I\'ve picked up the item'**
  String get pickedUpItem;

  /// No description provided for @pickedUpOn.
  ///
  /// In en, this message translates to:
  /// **'Picked up on {date}'**
  String pickedUpOn(String date);

  /// No description provided for @pickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get pickedUp;

  /// No description provided for @notYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get notYet;

  /// No description provided for @pickUpFirst.
  ///
  /// In en, this message translates to:
  /// **'Mark the item as picked up first.'**
  String get pickUpFirst;

  /// No description provided for @errPickUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark it as picked up. Please try again.'**
  String get errPickUpFailed;

  /// No description provided for @handoverCodeNote.
  ///
  /// In en, this message translates to:
  /// **'Meet the recipient in {city}, hand over the item and ask them for the delivery code.'**
  String handoverCodeNote(String city);

  /// No description provided for @wrongCodeAttempts.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. {count, plural, =1{1 try left} other{{count} tries left}}.'**
  String wrongCodeAttempts(int count);

  /// No description provided for @codeLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Contact support to unlock this delivery.'**
  String get codeLocked;

  /// No description provided for @codeNotReady.
  ///
  /// In en, this message translates to:
  /// **'The sender didn\'t have a code yet. Ask them to share the code that\'s now in their app.'**
  String get codeNotReady;

  /// No description provided for @deliveredPayoutQueued.
  ///
  /// In en, this message translates to:
  /// **'Delivered! Your payout of {amount} is on its way.'**
  String deliveredPayoutQueued(String amount);

  /// No description provided for @deliveryCode.
  ///
  /// In en, this message translates to:
  /// **'Delivery code'**
  String get deliveryCode;

  /// No description provided for @deliveryCodeNote.
  ///
  /// In en, this message translates to:
  /// **'Give this code to {name}. The traveler needs it to confirm the delivery.'**
  String deliveryCodeNote(String name);

  /// No description provided for @textCodeTo.
  ///
  /// In en, this message translates to:
  /// **'Text it to {name}'**
  String textCodeTo(String name);

  /// No description provided for @codeTextedResend.
  ///
  /// In en, this message translates to:
  /// **'Sent by SMS · Resend'**
  String get codeTextedResend;

  /// No description provided for @codeTexted.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {name} by SMS.'**
  String codeTexted(String name);

  /// No description provided for @errSmsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Texting isn\'t available right now. Please share the code with the recipient yourself.'**
  String get errSmsUnavailable;

  /// No description provided for @errSmsTooSoon.
  ///
  /// In en, this message translates to:
  /// **'The code was just sent. Please wait a couple of minutes before resending.'**
  String get errSmsTooSoon;

  /// No description provided for @payoutCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get payoutCountry;

  /// No description provided for @bankAccount.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get bankAccount;

  /// No description provided for @bankLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get bankLabel;

  /// No description provided for @providerLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get providerLabel;

  /// No description provided for @chooseBank.
  ///
  /// In en, this message translates to:
  /// **'Choose your bank'**
  String get chooseBank;

  /// No description provided for @chooseProvider.
  ///
  /// In en, this message translates to:
  /// **'Choose your provider'**
  String get chooseProvider;

  /// No description provided for @accountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get accountNumber;

  /// No description provided for @accountHolderName.
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get accountHolderName;

  /// No description provided for @savePayoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Save payout account'**
  String get savePayoutAccount;

  /// No description provided for @payoutAccountNoteSecure.
  ///
  /// In en, this message translates to:
  /// **'Your full account number is kept securely on our server and only used to send your payouts. The app only shows its last 4 digits.'**
  String get payoutAccountNoteSecure;

  /// No description provided for @noPayoutOptions.
  ///
  /// In en, this message translates to:
  /// **'Nata can\'t pay out to {country} yet.'**
  String noPayoutOptions(String country);

  /// No description provided for @errLoadPayoutOptions.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the banks for this country.'**
  String get errLoadPayoutOptions;

  /// No description provided for @errPayoutAccountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the account number and the holder’s name.'**
  String get errPayoutAccountInvalid;

  /// No description provided for @errPayoutNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This bank can\'t receive payouts yet. Please choose another one.'**
  String get errPayoutNotSupported;

  /// No description provided for @payoutCountryNote.
  ///
  /// In en, this message translates to:
  /// **'Your country of residence. Payouts are sent to an account there.'**
  String get payoutCountryNote;

  /// No description provided for @errPayoutCountryMismatch.
  ///
  /// In en, this message translates to:
  /// **'Payout accounts must be in your country of residence.'**
  String get errPayoutCountryMismatch;

  /// No description provided for @errSavePayoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the payout account. Please try again.'**
  String get errSavePayoutAccount;

  /// No description provided for @payoutAccountSaved.
  ///
  /// In en, this message translates to:
  /// **'Payout account saved.'**
  String get payoutAccountSaved;

  /// No description provided for @withdrawSent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your payout is on its way.} other{{count} payouts are on their way.}}'**
  String withdrawSent(int count);

  /// No description provided for @withdrawNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to send right now. If you\'re waiting for a payout, check you have a payout account in Payment Settings.'**
  String get withdrawNothing;

  /// No description provided for @backToProfile.
  ///
  /// In en, this message translates to:
  /// **'Back to Profile'**
  String get backToProfile;

  /// No description provided for @idStatusVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your identity is verified'**
  String get idStatusVerifiedTitle;

  /// No description provided for @idStatusVerifiedBody.
  ///
  /// In en, this message translates to:
  /// **'Senders and travelers can see you\'re verified. Your ID details are never shown to other users.'**
  String get idStatusVerifiedBody;

  /// No description provided for @idStatusReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re checking your ID'**
  String get idStatusReviewTitle;

  /// No description provided for @idStatusReviewBody.
  ///
  /// In en, this message translates to:
  /// **'This usually takes less than 24 hours. You can browse in the meantime, but you can\'t send or accept requests yet.'**
  String get idStatusReviewBody;

  /// No description provided for @idStatusDocument.
  ///
  /// In en, this message translates to:
  /// **'ID document'**
  String get idStatusDocument;

  /// No description provided for @idStatusFaceMatch.
  ///
  /// In en, this message translates to:
  /// **'Face match'**
  String get idStatusFaceMatch;

  /// No description provided for @idStatusVerifiedOn.
  ///
  /// In en, this message translates to:
  /// **'Verified on'**
  String get idStatusVerifiedOn;

  /// No description provided for @idStatusSubmittedOn.
  ///
  /// In en, this message translates to:
  /// **'Submitted on'**
  String get idStatusSubmittedOn;

  /// No description provided for @idStatusPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get idStatusPassed;

  /// No description provided for @idStatusInReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get idStatusInReview;

  /// No description provided for @idStatusReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get idStatusReceived;

  /// No description provided for @idStatusPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only your photo and first name appear on your profile.'**
  String get idStatusPrivacy;

  /// No description provided for @idDocPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get idDocPassport;

  /// No description provided for @idDocDriversLicense.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s license'**
  String get idDocDriversLicense;

  /// No description provided for @idDocNationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get idDocNationalId;

  /// No description provided for @walletHistory.
  ///
  /// In en, this message translates to:
  /// **'Wallet History'**
  String get walletHistory;

  /// No description provided for @walletAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get walletAvailable;

  /// No description provided for @walletInEscrow.
  ///
  /// In en, this message translates to:
  /// **'In escrow'**
  String get walletInEscrow;

  /// No description provided for @walletFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get walletFilterAll;

  /// No description provided for @walletFilterPayouts.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get walletFilterPayouts;

  /// No description provided for @walletFilterPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get walletFilterPayments;

  /// No description provided for @walletPayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout · {item}'**
  String walletPayoutTitle(String item);

  /// No description provided for @walletPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment · {item}'**
  String walletPaymentTitle(String item);

  /// No description provided for @walletPayoutFallback.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get walletPayoutFallback;

  /// No description provided for @walletPaymentFallback.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get walletPaymentFallback;

  /// No description provided for @walletPaymentTo.
  ///
  /// In en, this message translates to:
  /// **'Delivery request to {name}'**
  String walletPaymentTo(String name);

  /// No description provided for @walletStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get walletStatusPending;

  /// No description provided for @walletStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get walletStatusSending;

  /// No description provided for @walletStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get walletStatusPaid;

  /// No description provided for @walletStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed · retrying'**
  String get walletStatusFailed;

  /// No description provided for @walletStatusInEscrow.
  ///
  /// In en, this message translates to:
  /// **'In escrow'**
  String get walletStatusInEscrow;

  /// No description provided for @walletStatusReleased.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get walletStatusReleased;

  /// No description provided for @walletStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get walletStatusRefunded;

  /// No description provided for @walletEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet. Payments and payouts will appear here.'**
  String get walletEmpty;

  /// No description provided for @errWalletHistory.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your history.'**
  String get errWalletHistory;

  /// No description provided for @sbpTitle.
  ///
  /// In en, this message translates to:
  /// **'Why items travel sealed'**
  String get sbpTitle;

  /// No description provided for @sbpBody.
  ///
  /// In en, this message translates to:
  /// **'Every item must be in its original, factory-sealed box. It keeps travelers safe at customs and protects senders from disputes.'**
  String get sbpBody;

  /// No description provided for @sbpRule1.
  ///
  /// In en, this message translates to:
  /// **'Original packaging, unopened'**
  String get sbpRule1;

  /// No description provided for @sbpRule2.
  ///
  /// In en, this message translates to:
  /// **'Shown in photos before the request'**
  String get sbpRule2;

  /// No description provided for @sbpRule3.
  ///
  /// In en, this message translates to:
  /// **'Traveler checks the seal at pickup and can refuse a box that\'s been opened'**
  String get sbpRule3;

  /// No description provided for @sbpRule4.
  ///
  /// In en, this message translates to:
  /// **'No prohibited items: cash, medicines without a prescription, batteries over 100Wh, liquids over 100ml, anything illegal at the destination'**
  String get sbpRule4;

  /// No description provided for @sbpCustoms.
  ///
  /// In en, this message translates to:
  /// **'If customs opens the box, the traveler isn\'t responsible for the item.'**
  String get sbpCustoms;

  /// No description provided for @ecScreenBody.
  ///
  /// In en, this message translates to:
  /// **'Someone we can reach if something goes wrong during a delivery. Never shown to other users.'**
  String get ecScreenBody;

  /// No description provided for @ecSaveContact.
  ///
  /// In en, this message translates to:
  /// **'Save contact'**
  String get ecSaveContact;

  /// No description provided for @ecSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact saved.'**
  String get ecSavedToast;

  /// No description provided for @ecProfileAdd.
  ///
  /// In en, this message translates to:
  /// **'Add someone we can reach'**
  String get ecProfileAdd;

  /// No description provided for @errLoadContact.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your emergency contact.'**
  String get errLoadContact;

  /// No description provided for @notifRequestNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New delivery request'**
  String get notifRequestNewTitle;

  /// No description provided for @notifRequestNewBody.
  ///
  /// In en, this message translates to:
  /// **'{name} wants you to carry an item on {route}.'**
  String notifRequestNewBody(String name, String route);

  /// No description provided for @notifAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request accepted'**
  String get notifAcceptedTitle;

  /// No description provided for @notifAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your request. Pay within 24 hours to confirm it.'**
  String notifAcceptedBody(String name);

  /// No description provided for @notifDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get notifDeclinedTitle;

  /// No description provided for @notifDeclinedBody.
  ///
  /// In en, this message translates to:
  /// **'{name} can\'t take your item. Find another traveler on {route}.'**
  String notifDeclinedBody(String name, String route);

  /// No description provided for @notifExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Request expired'**
  String get notifExpiredTitle;

  /// No description provided for @notifExpiredUnansweredBody.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t answer in time. Find another traveler.'**
  String notifExpiredUnansweredBody(String name);

  /// No description provided for @notifExpiredUnpaidBody.
  ///
  /// In en, this message translates to:
  /// **'The 24 hours to pay have passed, so the request was closed.'**
  String get notifExpiredUnpaidBody;

  /// No description provided for @notifExpiredUnpaidTravelerBody.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t pay in time, so the request was closed.'**
  String notifExpiredUnpaidTravelerBody(String name);

  /// No description provided for @notifCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get notifCancelledTitle;

  /// No description provided for @notifCancelledByTravelerBody.
  ///
  /// In en, this message translates to:
  /// **'{name} cancelled your request.'**
  String notifCancelledByTravelerBody(String name);

  /// No description provided for @notifCancelledBySenderBody.
  ///
  /// In en, this message translates to:
  /// **'{name} cancelled their request on {route}.'**
  String notifCancelledBySenderBody(String name, String route);

  /// No description provided for @notifPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment secured'**
  String get notifPaidTitle;

  /// No description provided for @notifPaidBody.
  ///
  /// In en, this message translates to:
  /// **'{name} paid. The money is held safely until delivery, and chat is open.'**
  String notifPaidBody(String name);

  /// No description provided for @notifPickedUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Item picked up'**
  String get notifPickedUpTitle;

  /// No description provided for @notifPickedUpBody.
  ///
  /// In en, this message translates to:
  /// **'{name} has your item and is on the way.'**
  String notifPickedUpBody(String name);

  /// No description provided for @notifDeliveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Item delivered'**
  String get notifDeliveredTitle;

  /// No description provided for @notifDeliveredBody.
  ///
  /// In en, this message translates to:
  /// **'{name} delivered your item. Confirm you received it.'**
  String notifDeliveredBody(String name);

  /// No description provided for @notifPayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout sent'**
  String get notifPayoutTitle;

  /// No description provided for @notifPayoutBody.
  ///
  /// In en, this message translates to:
  /// **'Your payout of {amount} is on its way.'**
  String notifPayoutBody(String amount);

  /// No description provided for @notifVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity verified'**
  String get notifVerifiedTitle;

  /// No description provided for @notifVerifiedBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re verified. You can now send and accept delivery requests.'**
  String get notifVerifiedBody;

  /// No description provided for @notifRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity check failed'**
  String get notifRejectedTitle;

  /// No description provided for @notifRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify your ID. Please try again with a clear photo.'**
  String get notifRejectedBody;

  /// No description provided for @crHeadline.
  ///
  /// In en, this message translates to:
  /// **'{traveler} says your item was delivered to {recipient}'**
  String crHeadline(String traveler, String recipient);

  /// No description provided for @crBody.
  ///
  /// In en, this message translates to:
  /// **'Check that it arrived safely. Confirming lets you rate {traveler}.'**
  String crBody(String traveler);

  /// No description provided for @crItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get crItem;

  /// No description provided for @crRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get crRoute;

  /// No description provided for @crRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get crRecipient;

  /// No description provided for @crYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, it arrived'**
  String get crYes;

  /// No description provided for @reportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblem;

  /// No description provided for @crReportNote.
  ///
  /// In en, this message translates to:
  /// **'You can report a problem for 3 days'**
  String get crReportNote;

  /// No description provided for @rpBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us what went wrong. Our support team will contact you.'**
  String get rpBody;

  /// No description provided for @rpReason.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get rpReason;

  /// No description provided for @rpNotReceived.
  ///
  /// In en, this message translates to:
  /// **'The item didn\'t arrive'**
  String get rpNotReceived;

  /// No description provided for @rpDamaged.
  ///
  /// In en, this message translates to:
  /// **'It arrived damaged'**
  String get rpDamaged;

  /// No description provided for @rpWrongItem.
  ///
  /// In en, this message translates to:
  /// **'It\'s not the item I sent'**
  String get rpWrongItem;

  /// No description provided for @rpOpened.
  ///
  /// In en, this message translates to:
  /// **'The box was opened'**
  String get rpOpened;

  /// No description provided for @rpOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get rpOther;

  /// No description provided for @rpDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get rpDetails;

  /// No description provided for @rpDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add anything that will help us look into it'**
  String get rpDetailsHint;

  /// No description provided for @rpSend.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get rpSend;

  /// No description provided for @rpSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks. We\'ve received your report and will contact you.'**
  String get rpSent;

  /// No description provided for @errAlreadyReported.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already reported a problem on this delivery.'**
  String get errAlreadyReported;

  /// No description provided for @errReportWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'The 3 days to report a problem have passed.'**
  String get errReportWindowClosed;

  /// No description provided for @notifProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Problem reported'**
  String get notifProblemTitle;

  /// No description provided for @notifProblemBody.
  ///
  /// In en, this message translates to:
  /// **'A problem was reported on one of your deliveries. Our support team will contact you.'**
  String get notifProblemBody;

  /// No description provided for @notifTripMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'A traveler is going your way'**
  String get notifTripMatchTitle;

  /// No description provided for @notifTripMatchBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is flying {route}. Send your item with them.'**
  String notifTripMatchBody(String name, String route);

  /// No description provided for @routeAlerts.
  ///
  /// In en, this message translates to:
  /// **'Route alerts'**
  String get routeAlerts;

  /// No description provided for @routeAlertsSub.
  ///
  /// In en, this message translates to:
  /// **'Get notified when a traveler flies your routes'**
  String get routeAlertsSub;

  /// No description provided for @routeAlertsIntro.
  ///
  /// In en, this message translates to:
  /// **'Save the routes you often send on. When a verified traveler posts a trip on one of them, we\'ll notify you.'**
  String get routeAlertsIntro;

  /// No description provided for @routeAlertsSaved.
  ///
  /// In en, this message translates to:
  /// **'SAVED ROUTES'**
  String get routeAlertsSaved;

  /// No description provided for @routeAlertsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of 5'**
  String routeAlertsCount(int count);

  /// No description provided for @routeAlertsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a route'**
  String get routeAlertsAdd;

  /// No description provided for @routeAlertsMax.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 routes'**
  String get routeAlertsMax;

  /// No description provided for @routeAlertsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No routes yet'**
  String get routeAlertsEmptyTitle;

  /// No description provided for @routeAlertsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add the routes you send on and we\'ll tell you when a traveler flies them.'**
  String get routeAlertsEmptyBody;

  /// No description provided for @routeAlertsFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get routeAlertsFrom;

  /// No description provided for @routeAlertsTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get routeAlertsTo;

  /// No description provided for @routeAlertsChooseCity.
  ///
  /// In en, this message translates to:
  /// **'Choose a city'**
  String get routeAlertsChooseCity;

  /// No description provided for @routeAlertsSave.
  ///
  /// In en, this message translates to:
  /// **'Save route'**
  String get routeAlertsSave;

  /// No description provided for @routeAlertsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove route'**
  String get routeAlertsRemove;

  /// No description provided for @routeAlertsSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Route saved. We\'ll let you know when a traveler flies it.'**
  String get routeAlertsSavedToast;

  /// No description provided for @routeAlertsErrSame.
  ///
  /// In en, this message translates to:
  /// **'Pick two different cities.'**
  String get routeAlertsErrSame;

  /// No description provided for @routeAlertsErrLimit.
  ///
  /// In en, this message translates to:
  /// **'You can save up to 5 routes. Remove one to add another.'**
  String get routeAlertsErrLimit;

  /// No description provided for @routeAlertsErrExists.
  ///
  /// In en, this message translates to:
  /// **'You already have this route.'**
  String get routeAlertsErrExists;

  /// No description provided for @routeAlertsErrFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the route. Please try again.'**
  String get routeAlertsErrFailed;

  /// No description provided for @routeAlertsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your routes.'**
  String get routeAlertsLoadFailed;

  /// No description provided for @routeAlertsNotifyAbout.
  ///
  /// In en, this message translates to:
  /// **'Notify me about'**
  String get routeAlertsNotifyAbout;

  /// No description provided for @routeAlertsTravelers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 traveler} other{{count} travelers}}'**
  String routeAlertsTravelers(int count);

  /// No description provided for @routeAlertsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get routeAlertsAll;

  /// No description provided for @routeAlertsStopAfter.
  ///
  /// In en, this message translates to:
  /// **'We stop after {count, plural, =1{1 traveler} other{{count} travelers}}. You can restart it anytime.'**
  String routeAlertsStopAfter(int count);

  /// No description provided for @routeAlertsEveryTravelerNote.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tell you about every traveler on this route.'**
  String get routeAlertsEveryTravelerNote;

  /// No description provided for @routeAlertsEveryTraveler.
  ///
  /// In en, this message translates to:
  /// **'Every traveler'**
  String get routeAlertsEveryTraveler;

  /// No description provided for @routeAlertsProgress.
  ///
  /// In en, this message translates to:
  /// **'{sent} of {max} travelers found'**
  String routeAlertsProgress(int sent, int max);

  /// No description provided for @routeAlertsDone.
  ///
  /// In en, this message translates to:
  /// **'Done · {sent} of {max} travelers found'**
  String routeAlertsDone(int sent, int max);

  /// No description provided for @routeAlertsRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get routeAlertsRestart;

  /// No description provided for @routeAlertsRestarted.
  ///
  /// In en, this message translates to:
  /// **'Restarted. We\'ll let you know about the next travelers.'**
  String get routeAlertsRestarted;

  /// No description provided for @routeAlertsErrRestart.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restart this route. Please try again.'**
  String get routeAlertsErrRestart;

  /// No description provided for @homeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get homeGetStarted;

  /// No description provided for @homeVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity'**
  String get homeVerifyTitle;

  /// No description provided for @homeVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'Takes 2 minutes. Needed to send or carry items.'**
  String get homeVerifyBody;

  /// No description provided for @homeVerifyAction.
  ///
  /// In en, this message translates to:
  /// **'Verify now'**
  String get homeVerifyAction;

  /// No description provided for @homeRoutesTitle.
  ///
  /// In en, this message translates to:
  /// **'Get alerts for your routes'**
  String get homeRoutesTitle;

  /// No description provided for @homeRoutesBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tell you when a traveler flies the routes you send on.'**
  String get homeRoutesBody;

  /// No description provided for @homeRoutesAction.
  ///
  /// In en, this message translates to:
  /// **'Add a route'**
  String get homeRoutesAction;

  /// No description provided for @homeFaceIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Face ID'**
  String get homeFaceIdTitle;

  /// No description provided for @homeFaceIdBody.
  ///
  /// In en, this message translates to:
  /// **'Next time, your face signs you in. No code needed.'**
  String get homeFaceIdBody;

  /// No description provided for @homeFaceIdAction.
  ///
  /// In en, this message translates to:
  /// **'Turn on Face ID'**
  String get homeFaceIdAction;

  /// No description provided for @faceIdEnableReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you to turn on Face ID'**
  String get faceIdEnableReason;

  /// No description provided for @faceIdTurnedOn.
  ///
  /// In en, this message translates to:
  /// **'Face ID is on. Next time, your face signs you in.'**
  String get faceIdTurnedOn;

  /// No description provided for @faceIdEnableFailed.
  ///
  /// In en, this message translates to:
  /// **'Face ID didn\'t recognise you. Try again.'**
  String get faceIdEnableFailed;

  /// No description provided for @nameEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get nameEditTooltip;

  /// No description provided for @nameEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit your name'**
  String get nameEditTitle;

  /// No description provided for @nameEditHelper.
  ///
  /// In en, this message translates to:
  /// **'Use your name exactly as it appears on your ID. It can\'t be changed once your identity is verified.'**
  String get nameEditHelper;

  /// No description provided for @nameSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get nameSave;

  /// No description provided for @nameErrEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter your first and last name.'**
  String get nameErrEmpty;

  /// No description provided for @nameErrLocked.
  ///
  /// In en, this message translates to:
  /// **'Your name can\'t be changed now that your identity check has started.'**
  String get nameErrLocked;

  /// No description provided for @nameErrFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your name. Please try again.'**
  String get nameErrFailed;

  /// No description provided for @nameLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your name matches your ID'**
  String get nameLockedTitle;

  /// No description provided for @nameLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your name was checked against your ID, so it can\'t be changed in the app. If it\'s wrong or has legally changed, our support team can update it.'**
  String get nameLockedBody;

  /// No description provided for @nameContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get nameContactSupport;

  /// No description provided for @nameSupportSubject.
  ///
  /// In en, this message translates to:
  /// **'Name change request'**
  String get nameSupportSubject;

  /// No description provided for @nameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated.'**
  String get nameUpdated;

  /// No description provided for @notifMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'New message from {name}'**
  String notifMessageTitle(String name);

  /// No description provided for @notifMessageBody.
  ///
  /// In en, this message translates to:
  /// **'{message}'**
  String notifMessageBody(String message);

  /// No description provided for @notifMessagePhotoBody.
  ///
  /// In en, this message translates to:
  /// **'Sent you a photo'**
  String get notifMessagePhotoBody;

  /// No description provided for @chatTyping.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get chatTyping;

  /// No description provided for @pickupPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of the sealed box as you receive it.'**
  String get pickupPhotoHint;

  /// No description provided for @errPhotoUpload.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the photo. Please try again.'**
  String get errPhotoUpload;

  /// No description provided for @notifRefundTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund sent'**
  String get notifRefundTitle;

  /// No description provided for @notifRefundBody.
  ///
  /// In en, this message translates to:
  /// **'Your refund of {amount} is on its way.'**
  String notifRefundBody(String amount);

  /// No description provided for @viewCode.
  ///
  /// In en, this message translates to:
  /// **'View code'**
  String get viewCode;

  /// No description provided for @chatCodeNote.
  ///
  /// In en, this message translates to:
  /// **'Your recipient gives this code to the traveler at handover. Don\'t share it before then.'**
  String get chatCodeNote;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportTitle;

  /// No description provided for @supportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nata staff · Reports, locks and failed payments'**
  String get supportSubtitle;

  /// No description provided for @supportProblemsCard.
  ///
  /// In en, this message translates to:
  /// **'Reported problems'**
  String get supportProblemsCard;

  /// No description provided for @supportOpenSuffix.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get supportOpenSuffix;

  /// No description provided for @supportProblemsLine.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a decision'**
  String get supportProblemsLine;

  /// No description provided for @supportLockedCard.
  ///
  /// In en, this message translates to:
  /// **'Locked deliveries'**
  String get supportLockedCard;

  /// No description provided for @supportLockedSuffix.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get supportLockedSuffix;

  /// No description provided for @supportLockedLine.
  ///
  /// In en, this message translates to:
  /// **'Locked after 5 wrong delivery codes'**
  String get supportLockedLine;

  /// No description provided for @supportFailedCard.
  ///
  /// In en, this message translates to:
  /// **'Failed payments'**
  String get supportFailedCard;

  /// No description provided for @supportFailedSuffix.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get supportFailedSuffix;

  /// No description provided for @supportFailedLine.
  ///
  /// In en, this message translates to:
  /// **'Failed payouts and refunds to retry'**
  String get supportFailedLine;

  /// No description provided for @supportRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get supportRecentActivity;

  /// No description provided for @supportNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No support actions yet.'**
  String get supportNoActivity;

  /// No description provided for @supportActResolved.
  ///
  /// In en, this message translates to:
  /// **'Problem resolved'**
  String get supportActResolved;

  /// No description provided for @supportActRefunded.
  ///
  /// In en, this message translates to:
  /// **'Sender refunded'**
  String get supportActRefunded;

  /// No description provided for @supportActPayoutRetried.
  ///
  /// In en, this message translates to:
  /// **'Payout retried'**
  String get supportActPayoutRetried;

  /// No description provided for @supportActRefundRetried.
  ///
  /// In en, this message translates to:
  /// **'Refund retried'**
  String get supportActRefundRetried;

  /// No description provided for @supportActUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Delivery unlocked'**
  String get supportActUnlocked;

  /// No description provided for @supportProblemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reported Problems'**
  String get supportProblemsTitle;

  /// No description provided for @supportOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get supportOpen;

  /// No description provided for @supportResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get supportResolved;

  /// No description provided for @supportReportedBySender.
  ///
  /// In en, this message translates to:
  /// **'Reported by Sender'**
  String get supportReportedBySender;

  /// No description provided for @supportReportedByTraveler.
  ///
  /// In en, this message translates to:
  /// **'Reported by Traveler'**
  String get supportReportedByTraveler;

  /// No description provided for @supportInEscrow.
  ///
  /// In en, this message translates to:
  /// **'In escrow'**
  String get supportInEscrow;

  /// No description provided for @supportViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get supportViewDetails;

  /// No description provided for @supportNoProblems.
  ///
  /// In en, this message translates to:
  /// **'No problems here.'**
  String get supportNoProblems;

  /// No description provided for @supportProblemDetail.
  ///
  /// In en, this message translates to:
  /// **'Problem Detail'**
  String get supportProblemDetail;

  /// No description provided for @supportReporterDetails.
  ///
  /// In en, this message translates to:
  /// **'Reporter\'s details'**
  String get supportReporterDetails;

  /// No description provided for @supportNoDetails.
  ///
  /// In en, this message translates to:
  /// **'No details given.'**
  String get supportNoDetails;

  /// No description provided for @supportPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get supportPeople;

  /// No description provided for @supportSender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get supportSender;

  /// No description provided for @supportTraveler.
  ///
  /// In en, this message translates to:
  /// **'Traveler'**
  String get supportTraveler;

  /// No description provided for @supportTimeline.
  ///
  /// In en, this message translates to:
  /// **'Delivery timeline'**
  String get supportTimeline;

  /// No description provided for @supportPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get supportPaid;

  /// No description provided for @supportPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get supportPickedUp;

  /// No description provided for @supportDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get supportDelivered;

  /// No description provided for @supportReported.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get supportReported;

  /// No description provided for @supportPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment status'**
  String get supportPaymentStatus;

  /// No description provided for @supportHeld.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get supportHeld;

  /// No description provided for @supportHeldLine.
  ///
  /// In en, this message translates to:
  /// **'{amount} held in escrow'**
  String supportHeldLine(String amount);

  /// No description provided for @supportHeldSub.
  ///
  /// In en, this message translates to:
  /// **'Not paid out until resolved'**
  String get supportHeldSub;

  /// No description provided for @supportReleased.
  ///
  /// In en, this message translates to:
  /// **'Paid out'**
  String get supportReleased;

  /// No description provided for @supportReleasedLine.
  ///
  /// In en, this message translates to:
  /// **'{amount} paid to the traveler'**
  String supportReleasedLine(String amount);

  /// No description provided for @supportRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get supportRefunded;

  /// No description provided for @supportRefundedLine.
  ///
  /// In en, this message translates to:
  /// **'{amount} returned to the sender'**
  String supportRefundedLine(String amount);

  /// No description provided for @supportResolutionNote.
  ///
  /// In en, this message translates to:
  /// **'Resolution note'**
  String get supportResolutionNote;

  /// No description provided for @supportResolutionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what was decided and why…'**
  String get supportResolutionHint;

  /// No description provided for @supportMarkResolved.
  ///
  /// In en, this message translates to:
  /// **'Mark resolved'**
  String get supportMarkResolved;

  /// No description provided for @supportRefundSender.
  ///
  /// In en, this message translates to:
  /// **'Refund sender'**
  String get supportRefundSender;

  /// No description provided for @supportRefundConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund {amount} to {name}?'**
  String supportRefundConfirmTitle(String amount, String name);

  /// No description provided for @supportRefundConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The escrow goes back to the sender and the traveler isn\'t paid. This can\'t be undone.'**
  String get supportRefundConfirmBody;

  /// No description provided for @supportConfirmRefund.
  ///
  /// In en, this message translates to:
  /// **'Confirm refund'**
  String get supportConfirmRefund;

  /// No description provided for @supportResolvedSnack.
  ///
  /// In en, this message translates to:
  /// **'Problem resolved.'**
  String get supportResolvedSnack;

  /// No description provided for @supportRefundSnack.
  ///
  /// In en, this message translates to:
  /// **'Refund queued. It goes out within 15 minutes.'**
  String get supportRefundSnack;

  /// No description provided for @supportPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments & Locks'**
  String get supportPaymentsTitle;

  /// No description provided for @supportFailedTab.
  ///
  /// In en, this message translates to:
  /// **'Failed payments'**
  String get supportFailedTab;

  /// No description provided for @supportLockedTab.
  ///
  /// In en, this message translates to:
  /// **'Locked deliveries'**
  String get supportLockedTab;

  /// No description provided for @supportPayout.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get supportPayout;

  /// No description provided for @supportRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get supportRefund;

  /// No description provided for @supportRefundRequeued.
  ///
  /// In en, this message translates to:
  /// **'Refund queued again. It goes out within 15 minutes.'**
  String get supportRefundRequeued;

  /// No description provided for @supportLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get supportLocked;

  /// No description provided for @supportWrongAttempts.
  ///
  /// In en, this message translates to:
  /// **'Wrong code attempts'**
  String get supportWrongAttempts;

  /// No description provided for @supportUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock delivery'**
  String get supportUnlock;

  /// No description provided for @supportUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock this delivery?'**
  String get supportUnlockTitle;

  /// No description provided for @supportUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'{name} gets 5 more attempts at the delivery code. Confirm the traveler is with the item before unlocking.'**
  String supportUnlockBody(String name);

  /// No description provided for @supportConfirmUnlock.
  ///
  /// In en, this message translates to:
  /// **'Confirm unlock'**
  String get supportConfirmUnlock;

  /// No description provided for @supportUnlockedSnack.
  ///
  /// In en, this message translates to:
  /// **'Delivery unlocked.'**
  String get supportUnlockedSnack;

  /// No description provided for @supportNothingFailed.
  ///
  /// In en, this message translates to:
  /// **'No failed payments.'**
  String get supportNothingFailed;

  /// No description provided for @supportNothingLocked.
  ///
  /// In en, this message translates to:
  /// **'No locked deliveries.'**
  String get supportNothingLocked;

  /// No description provided for @supportRowSub.
  ///
  /// In en, this message translates to:
  /// **'Nata staff · Reports, locks & payments'**
  String get supportRowSub;

  /// No description provided for @supportAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get supportAdmin;

  /// No description provided for @supportLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this. Pull down to try again.'**
  String get supportLoadFailed;

  /// No description provided for @supportActionFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Please try again.'**
  String get supportActionFailed;

  /// No description provided for @deleteAccountRow.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountRow;

  /// No description provided for @deleteAccountRowSub.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your Nata account'**
  String get deleteAccountRowSub;

  /// No description provided for @daTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get daTitle;

  /// No description provided for @daBody.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get daBody;

  /// No description provided for @daWhatWeDelete.
  ///
  /// In en, this message translates to:
  /// **'What we delete'**
  String get daWhatWeDelete;

  /// No description provided for @daDeleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile, name and photo'**
  String get daDeleteProfile;

  /// No description provided for @daDeleteId.
  ///
  /// In en, this message translates to:
  /// **'Your ID documents and selfie'**
  String get daDeleteId;

  /// No description provided for @daDeletePayment.
  ///
  /// In en, this message translates to:
  /// **'Saved payment methods and payout accounts'**
  String get daDeletePayment;

  /// No description provided for @daDeleteMessages.
  ///
  /// In en, this message translates to:
  /// **'Your messages, trips and open requests'**
  String get daDeleteMessages;

  /// No description provided for @daDeleteNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications and devices'**
  String get daDeleteNotifications;

  /// No description provided for @daWhatWeKeep.
  ///
  /// In en, this message translates to:
  /// **'What we keep'**
  String get daWhatWeKeep;

  /// No description provided for @daKeepPayments.
  ///
  /// In en, this message translates to:
  /// **'Payment and payout records, anonymised'**
  String get daKeepPayments;

  /// No description provided for @daKeepPaymentsSub.
  ///
  /// In en, this message translates to:
  /// **'Needed for accounting'**
  String get daKeepPaymentsSub;

  /// No description provided for @daKeepDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Completed deliveries and reviews'**
  String get daKeepDeliveries;

  /// No description provided for @daKeepDeliveriesSub.
  ///
  /// In en, this message translates to:
  /// **'Shown as \"Deleted user\"'**
  String get daKeepDeliveriesSub;

  /// No description provided for @daUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I understand this is permanent'**
  String get daUnderstand;

  /// No description provided for @daConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get daConfirmButton;

  /// No description provided for @daFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Please try again.'**
  String get daFailed;

  /// No description provided for @daLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check your account.'**
  String get daLoadFailed;

  /// No description provided for @daBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'You can\'t delete your account yet'**
  String get daBlockedTitle;

  /// No description provided for @daBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Finish or resolve these first, then try again.'**
  String get daBlockedBody;

  /// No description provided for @daBlockedEscrow.
  ///
  /// In en, this message translates to:
  /// **'Money held in escrow'**
  String get daBlockedEscrow;

  /// No description provided for @daBlockedPayments.
  ///
  /// In en, this message translates to:
  /// **'Payouts or refunds on the way'**
  String get daBlockedPayments;

  /// No description provided for @daBlockedDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Deliveries in progress'**
  String get daBlockedDeliveries;

  /// No description provided for @daBlockedDisputes.
  ///
  /// In en, this message translates to:
  /// **'Open problem reports'**
  String get daBlockedDisputes;

  /// No description provided for @daBlockedStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff accounts are removed by Nata support'**
  String get daBlockedStaff;

  /// No description provided for @daNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help? Contact Nata support.'**
  String get daNeedHelp;

  /// No description provided for @tipSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tipSkip;

  /// No description provided for @tipNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tipNext;

  /// No description provided for @tipGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tipGotIt;

  /// No description provided for @tipAddTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Do you have an upcoming trip?'**
  String get tipAddTripTitle;

  /// No description provided for @tipAddTripBody.
  ///
  /// In en, this message translates to:
  /// **'Add it here and get paid to carry parcels for people on your route.'**
  String get tipAddTripBody;

  /// No description provided for @tipSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Need to send something?'**
  String get tipSearchTitle;

  /// No description provided for @tipSearchBody.
  ///
  /// In en, this message translates to:
  /// **'Choose where it leaves from and where it is going to find travelers on that route.'**
  String get tipSearchBody;

  /// No description provided for @tipBellTitle.
  ///
  /// In en, this message translates to:
  /// **'Your updates'**
  String get tipBellTitle;

  /// No description provided for @tipBellBody.
  ///
  /// In en, this message translates to:
  /// **'New requests, payments and deliveries show up here.'**
  String get tipBellBody;

  /// No description provided for @tipNavTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything in one place'**
  String get tipNavTitle;

  /// No description provided for @tipNavBody.
  ///
  /// In en, this message translates to:
  /// **'Follow your parcels in Requests, your trips in Trips and chat with travelers and senders in Messages.'**
  String get tipNavBody;

  /// No description provided for @tipRequestsTabsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sent and received'**
  String get tipRequestsTabsTitle;

  /// No description provided for @tipRequestsTabsBody.
  ///
  /// In en, this message translates to:
  /// **'Outgoing has the parcels you send. Incoming has the requests senders make on your trips.'**
  String get tipRequestsTabsBody;

  /// No description provided for @tipArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Active and Archive'**
  String get tipArchiveTitle;

  /// No description provided for @tipArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'Delivered, cancelled and expired requests move to the Archive after 24 hours. Swipe one left to archive it now.'**
  String get tipArchiveBody;

  /// No description provided for @tipTripsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Post a trip'**
  String get tipTripsAddTitle;

  /// No description provided for @tipTripsAddBody.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a trip you are already taking. Senders on your route can then ask you to carry their parcels.'**
  String get tipTripsAddBody;

  /// No description provided for @tipTripsTabsTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming and past'**
  String get tipTripsTabsTitle;

  /// No description provided for @tipTripsTabsBody.
  ///
  /// In en, this message translates to:
  /// **'Your trips still to come, and the ones you have already made.'**
  String get tipTripsTabsBody;

  /// No description provided for @tipChatSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a chat'**
  String get tipChatSearchTitle;

  /// No description provided for @tipChatSearchBody.
  ///
  /// In en, this message translates to:
  /// **'Search by name, route or item.'**
  String get tipChatSearchBody;

  /// No description provided for @tipChatFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'When chats open'**
  String get tipChatFiltersTitle;

  /// No description provided for @tipChatFiltersBody.
  ///
  /// In en, this message translates to:
  /// **'A chat opens once the sender pays and closes after delivery. Closed chats stay here under Completed, to read.'**
  String get tipChatFiltersBody;

  /// No description provided for @tipWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Nata Wallet'**
  String get tipWalletTitle;

  /// No description provided for @tipWalletBody.
  ///
  /// In en, this message translates to:
  /// **'Money held in escrow and money ready to withdraw. What you earn carrying parcels shows here.'**
  String get tipWalletBody;

  /// No description provided for @tipPayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Get paid'**
  String get tipPayoutTitle;

  /// No description provided for @tipPayoutBody.
  ///
  /// In en, this message translates to:
  /// **'Add a bank or mobile money account in Payment settings so your payouts reach you.'**
  String get tipPayoutBody;

  /// No description provided for @tipRouteAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Route alerts'**
  String get tipRouteAlertsTitle;

  /// No description provided for @tipRouteAlertsBody.
  ///
  /// In en, this message translates to:
  /// **'Save the routes you send on and hear when a traveler is flying them.'**
  String get tipRouteAlertsBody;

  /// No description provided for @paidSecurelyThroughStripe.
  ///
  /// In en, this message translates to:
  /// **'Paid securely through Stripe. Your card details never reach Nata.'**
  String get paidSecurelyThroughStripe;

  /// No description provided for @paymentMobileOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'You live in {country}, so you pay by mobile money.'**
  String paymentMobileOnlyNote(String country);

  /// No description provided for @errChooseNetwork.
  ///
  /// In en, this message translates to:
  /// **'Choose your network.'**
  String get errChooseNetwork;

  /// No description provided for @errPaymentMethodNotOffered.
  ///
  /// In en, this message translates to:
  /// **'This way to pay isn\'t offered where you live.'**
  String get errPaymentMethodNotOffered;

  /// No description provided for @errWholeMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter the whole mobile number.'**
  String get errWholeMobileNumber;

  /// No description provided for @checkoutMobileOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'You and the traveler both live in Africa, so this delivery is paid by mobile money.'**
  String get checkoutMobileOnlyNote;

  /// No description provided for @errMethodNotOffered.
  ///
  /// In en, this message translates to:
  /// **'This way to pay isn\'t offered for this delivery. Please choose another.'**
  String get errMethodNotOffered;

  /// No description provided for @confirmingPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirming your payment'**
  String get confirmingPayment;

  /// No description provided for @confirmingPaymentSub.
  ///
  /// In en, this message translates to:
  /// **'Payment made. We\'re confirming it with Stripe, which takes a few seconds.'**
  String get confirmingPaymentSub;

  /// No description provided for @supportReasonSaid.
  ///
  /// In en, this message translates to:
  /// **'Reason: \"{reason}\"'**
  String supportReasonSaid(String reason);

  /// No description provided for @supportPayoutRequeued.
  ///
  /// In en, this message translates to:
  /// **'Payout queued again. It goes out within 15 minutes.'**
  String get supportPayoutRequeued;

  /// No description provided for @stripePendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stripe is checking your details'**
  String get stripePendingTitle;

  /// No description provided for @stripePendingBody.
  ///
  /// In en, this message translates to:
  /// **'This usually takes a few minutes. Your payouts go to your bank once Stripe approves it.'**
  String get stripePendingBody;

  /// No description provided for @stripeConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your bank is connected'**
  String get stripeConnectedTitle;

  /// No description provided for @stripeConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'{bank} •••• {last4}, connected with Stripe.'**
  String stripeConnectedBody(String bank, String last4);

  /// No description provided for @stripeConnectedAdded.
  ///
  /// In en, this message translates to:
  /// **'It\'s already one of your payout accounts.'**
  String get stripeConnectedAdded;

  /// No description provided for @stripeUseBank.
  ///
  /// In en, this message translates to:
  /// **'Use this bank'**
  String get stripeUseBank;

  /// No description provided for @stripeChangeBank.
  ///
  /// In en, this message translates to:
  /// **'Use another bank account'**
  String get stripeChangeBank;

  /// No description provided for @stripeDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get stripeDone;

  /// No description provided for @stripeCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get stripeCheckAgain;

  /// No description provided for @errStripeOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Stripe. Please try again.'**
  String get errStripeOpen;

  /// No description provided for @stripeEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email for Stripe'**
  String get stripeEmailLabel;

  /// No description provided for @stripeEmailNote.
  ///
  /// In en, this message translates to:
  /// **'Stripe sends you updates about your payouts here. It isn\'t shown to anyone.'**
  String get stripeEmailNote;

  /// No description provided for @stripeEmailNeeded.
  ///
  /// In en, this message translates to:
  /// **'Stripe needs your email to set up payouts. Enter it above.'**
  String get stripeEmailNeeded;

  /// No description provided for @stripeYourDetails.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get stripeYourDetails;

  /// No description provided for @stripeDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get stripeDateOfBirth;

  /// No description provided for @stripeHomeAddress.
  ///
  /// In en, this message translates to:
  /// **'Home address'**
  String get stripeHomeAddress;

  /// No description provided for @stripeStreet.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get stripeStreet;

  /// No description provided for @stripeCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get stripeCity;

  /// No description provided for @stripeState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get stripeState;

  /// No description provided for @stripeProvince.
  ///
  /// In en, this message translates to:
  /// **'Province'**
  String get stripeProvince;

  /// No description provided for @stripeZip.
  ///
  /// In en, this message translates to:
  /// **'ZIP code'**
  String get stripeZip;

  /// No description provided for @stripePostcode.
  ///
  /// In en, this message translates to:
  /// **'Postcode'**
  String get stripePostcode;

  /// No description provided for @stripeIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get stripeIdentity;

  /// No description provided for @stripeSsnLast4.
  ///
  /// In en, this message translates to:
  /// **'Last 4 digits of your SSN'**
  String get stripeSsnLast4;

  /// No description provided for @stripeSsnHelp.
  ///
  /// In en, this message translates to:
  /// **'Stripe uses this to confirm who you are. Nata doesn\'t keep it.'**
  String get stripeSsnHelp;

  /// No description provided for @stripeBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get stripeBankAccount;

  /// No description provided for @stripeRoutingNumber.
  ///
  /// In en, this message translates to:
  /// **'Routing number'**
  String get stripeRoutingNumber;

  /// No description provided for @stripeTransitNumber.
  ///
  /// In en, this message translates to:
  /// **'Transit number'**
  String get stripeTransitNumber;

  /// No description provided for @stripeInstitutionNumber.
  ///
  /// In en, this message translates to:
  /// **'Institution number'**
  String get stripeInstitutionNumber;

  /// No description provided for @stripeSortCode.
  ///
  /// In en, this message translates to:
  /// **'Sort code'**
  String get stripeSortCode;

  /// No description provided for @stripeIban.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get stripeIban;

  /// No description provided for @stripeHolderNote.
  ///
  /// In en, this message translates to:
  /// **'The account must be in your own name.'**
  String get stripeHolderNote;

  /// No description provided for @stripeAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get stripeAgreePrefix;

  /// No description provided for @stripeAgreementName.
  ///
  /// In en, this message translates to:
  /// **'Stripe Connected Account Agreement'**
  String get stripeAgreementName;

  /// No description provided for @stripeSaveBank.
  ///
  /// In en, this message translates to:
  /// **'Save bank account'**
  String get stripeSaveBank;

  /// No description provided for @stripeFormNote.
  ///
  /// In en, this message translates to:
  /// **'Your details go to Stripe, Nata\'s payment partner. Nata only keeps the last 4 digits of your account.'**
  String get stripeFormNote;

  /// No description provided for @stripeFormIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Fill in every field and accept the agreement.'**
  String get stripeFormIncomplete;

  /// No description provided for @stripeMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Stripe needs a little more'**
  String get stripeMoreTitle;

  /// No description provided for @stripeMoreBody.
  ///
  /// In en, this message translates to:
  /// **'To finish, Stripe needs something Nata\'s form doesn\'t ask for, such as a photo of your ID.'**
  String get stripeMoreBody;

  /// No description provided for @stripeFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish with Stripe'**
  String get stripeFinish;

  /// No description provided for @removePayoutAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this payout account?'**
  String get removePayoutAccountTitle;

  /// No description provided for @removePayoutAccountBody.
  ///
  /// In en, this message translates to:
  /// **'{name} {summary} will no longer be paid. Payouts waiting for it go to your default payout account.'**
  String removePayoutAccountBody(String name, String summary);

  /// No description provided for @removePaymentMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this payment method?'**
  String get removePaymentMethodTitle;

  /// No description provided for @removePaymentMethodBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from your payment methods.'**
  String removePaymentMethodBody(String name);

  /// No description provided for @removeDefaultPaymentMethodBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is your default payment method. Your most recently added method becomes the default.'**
  String removeDefaultPaymentMethodBody(String name);

  /// No description provided for @payoutAccountLimitNote.
  ///
  /// In en, this message translates to:
  /// **'You can have up to {count} payout accounts. Remove one to add another.'**
  String payoutAccountLimitNote(int count);

  /// No description provided for @tapToMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Tap to make default'**
  String get tapToMakeDefault;

  /// No description provided for @notifPaymentReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get notifPaymentReceivedTitle;

  /// No description provided for @notifPaymentReceivedBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment is held safely until delivery. You can now chat with {name}.'**
  String notifPaymentReceivedBody(String name);

  /// No description provided for @notifDeliveryConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery confirmed'**
  String get notifDeliveryConfirmedTitle;

  /// No description provided for @notifDeliveryConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'You delivered {name}\'s item. Your payout is on its way.'**
  String notifDeliveryConfirmedBody(String name);

  /// No description provided for @routeAlertsWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight to send (optional)'**
  String get routeAlertsWeight;

  /// No description provided for @routeAlertsWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5'**
  String get routeAlertsWeightHint;

  /// No description provided for @routeAlertsWeightNote.
  ///
  /// In en, this message translates to:
  /// **'Only travelers who can carry at least this much. Leave it empty for any traveler.'**
  String get routeAlertsWeightNote;

  /// No description provided for @routeAlertsWeightChip.
  ///
  /// In en, this message translates to:
  /// **'{kg} kg+'**
  String routeAlertsWeightChip(String kg);

  /// No description provided for @routeAlertsErrWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter a weight between 0.1 and {max} kg, or leave it empty.'**
  String routeAlertsErrWeight(String max);

  /// No description provided for @resultsWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight to send'**
  String get resultsWeight;

  /// No description provided for @resultsWeightAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get resultsWeightAny;

  /// No description provided for @resultsWeightNone.
  ///
  /// In en, this message translates to:
  /// **'No traveler here can carry {kg} kg'**
  String resultsWeightNone(String kg);

  /// No description provided for @resultsWeightNoneHint.
  ///
  /// In en, this message translates to:
  /// **'Try a lighter weight, or see everyone going your way.'**
  String get resultsWeightNoneHint;

  /// No description provided for @resultsWeightClear.
  ///
  /// In en, this message translates to:
  /// **'Show all travelers'**
  String get resultsWeightClear;

  /// No description provided for @resultsWeightAnyNote.
  ///
  /// In en, this message translates to:
  /// **'Every traveler, whatever they can carry'**
  String get resultsWeightAnyNote;

  /// No description provided for @resultsWeightAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Travelers who can carry {kg} kg or more'**
  String resultsWeightAtLeast(String kg);

  /// No description provided for @resultsWeightButton.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get resultsWeightButton;

  /// No description provided for @ecRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'An emergency contact is required to finish verification'**
  String get ecRequiredTitle;

  /// No description provided for @ecRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'It stays private and is only used if something goes wrong during a delivery.'**
  String get ecRequiredBody;

  /// No description provided for @verifyContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost verified'**
  String get verifyContactTitle;

  /// No description provided for @verifyContactBody.
  ///
  /// In en, this message translates to:
  /// **'Add an emergency contact to finish verifying your identity.'**
  String get verifyContactBody;

  /// No description provided for @verifyAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add emergency contact'**
  String get verifyAddContact;

  /// No description provided for @identityNeedsContact.
  ///
  /// In en, this message translates to:
  /// **'Add an emergency contact to finish'**
  String get identityNeedsContact;

  /// No description provided for @ecProfileRequired.
  ///
  /// In en, this message translates to:
  /// **'Required to be verified'**
  String get ecProfileRequired;

  /// No description provided for @rateYourSender.
  ///
  /// In en, this message translates to:
  /// **'Rate Your Sender'**
  String get rateYourSender;

  /// No description provided for @senderItemDelivered.
  ///
  /// In en, this message translates to:
  /// **'You delivered the item'**
  String get senderItemDelivered;

  /// No description provided for @senderReviewHelps.
  ///
  /// In en, this message translates to:
  /// **'Your review helps other travelers know who they carry for.'**
  String get senderReviewHelps;

  /// No description provided for @senderTagInstructions.
  ///
  /// In en, this message translates to:
  /// **'Clear instructions'**
  String get senderTagInstructions;

  /// No description provided for @senderTagPacked.
  ///
  /// In en, this message translates to:
  /// **'Well packed'**
  String get senderTagPacked;

  /// No description provided for @senderTagOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time for pickup'**
  String get senderTagOnTime;

  /// No description provided for @senderTagFriendly.
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get senderTagFriendly;

  /// No description provided for @senderTagAgain.
  ///
  /// In en, this message translates to:
  /// **'Would carry again'**
  String get senderTagAgain;

  /// No description provided for @reviewLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get reviewLater;

  /// No description provided for @nextRateSender.
  ///
  /// In en, this message translates to:
  /// **'Rate the sender'**
  String get nextRateSender;

  /// No description provided for @rateSenderButton.
  ///
  /// In en, this message translates to:
  /// **'Rate {name}'**
  String rateSenderButton(String name);

  /// No description provided for @senderReviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get senderReviewSubmitted;

  /// No description provided for @senderReviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews from travelers'**
  String get senderReviewsTitle;

  /// No description provided for @senderRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating as a sender'**
  String get senderRatingLabel;

  /// No description provided for @senderNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews from travelers yet'**
  String get senderNoReviews;

  /// No description provided for @senderNoReviewsSub.
  ///
  /// In en, this message translates to:
  /// **'Reviews appear here after this sender\'s first completed delivery.'**
  String get senderNoReviewsSub;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
