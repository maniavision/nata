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
  /// **'Calculated per item size & weight'**
  String get pricingValue;

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

  /// No description provided for @step1of1.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 1'**
  String get step1of1;

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
  /// **'Send Delivery Request'**
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
  /// **'M-Pesa, MTN MoMo, Orange, Wave'**
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
  /// **'CarryWise protection & escrow fee'**
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
  /// **'Free cancellation anytime before physical handoff to traveler.'**
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
  /// **'Driver\'s Lic.'**
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
  /// **'Biometric face scans are processed locally to match against your passport.'**
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

  /// No description provided for @tripSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Trip submitted for review'**
  String get tripSubmitted;

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

  /// No description provided for @tripPrice.
  ///
  /// In en, this message translates to:
  /// **'PRICE PER ITEM'**
  String get tripPrice;

  /// No description provided for @tripPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Your fee for carrying one item'**
  String get tripPriceHint;

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

  /// No description provided for @errPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price.'**
  String get errPrice;

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
  /// **'Enter the recipient\'s phone number with the country code, e.g. +44 7700 900123.'**
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
  /// **'Send Delivery Request · {price}'**
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
  /// **'The traveler changed their price. Go back and open the request again to see the new price.'**
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
