// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Nata';

  @override
  String get splashTitle => 'Sélectionner la langue et la devise';

  @override
  String get splashSubtitle =>
      'Personnalisez votre expérience de livraison entre pairs à travers le monde.';

  @override
  String get splashWelcomePill => 'Welcome · Bienvenue · Bienvenido';

  @override
  String get splashDetectedRegion => 'RÉGION DÉTECTÉE';

  @override
  String get splashDetectedValue => 'États-Unis · Anglais et USD';

  @override
  String get splashQuickApply => 'Appliquer';

  @override
  String get splashChooseLanguage => 'CHOISIR LA LANGUE';

  @override
  String get splashPreferredCurrency => 'DEVISE PRÉFÉRÉE';

  @override
  String get splashSaveAndContinue => 'Enregistrer et continuer';

  @override
  String get splashSettingsNote =>
      'Vous pouvez modifier votre langue et votre devise à tout moment dans les paramètres de profil.';

  @override
  String splashAvailable(int count) {
    return '$count disponibles';
  }

  @override
  String get langEnglish => 'English';

  @override
  String get langEnglishSub => 'Par défaut · International';

  @override
  String get langSpanish => 'Español';

  @override
  String get langSpanishSub => 'Espagnol · Espagne et Amérique latine';

  @override
  String get langFrench => 'Français';

  @override
  String get langFrenchSub => 'Français · France et Afrique';

  @override
  String get currUSD => 'Dollar américain';

  @override
  String get currEUR => 'Euro';

  @override
  String get currGBP => 'Livre sterling';

  @override
  String get currXOF => 'Franc CFA';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get email => 'E-mail ou téléphone';

  @override
  String get password => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get rememberMe => 'Se souvenir de moi';

  @override
  String get faceId => 'Face ID';

  @override
  String get signInButton => 'Se connecter';

  @override
  String get newToNata => 'Nouveau sur Nata ?';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get tagline =>
      'Livraisons entre pairs · Réseau de voyageurs vérifiés à 100%';

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get welcomeBackSub =>
      'Connectez-vous pour gérer vos livraisons, itinéraires et demandes.';

  @override
  String get orWithEmail => 'ou avec e-mail';

  @override
  String get apple => 'Apple';

  @override
  String get google => 'Google';

  @override
  String get createYourAccount => 'Créez votre compte';

  @override
  String get createYourAccountSub =>
      'Envoyez des articles avec des voyageurs vérifiés se rendant à votre destination.';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom de famille';

  @override
  String get emailAddress => 'Adresse e-mail';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get orSignUpManually => 'ou inscrivez-vous manuellement';

  @override
  String get mandatoryIdTitle => 'Vérification d\'identité obligatoire';

  @override
  String get mandatoryIdBody =>
      'Une vérification par pièce d\'identité officielle et scan du visage sera demandée juste après l\'inscription avant toute transaction.';

  @override
  String get createAccountButton => 'Créer un compte et continuer';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get signInHere => 'Connectez-vous ici';

  @override
  String get goodMorning => 'BONJOUR';

  @override
  String get homeHero => 'Votre colis est déjà en route.';

  @override
  String get homeSubtitle =>
      'Envoyez-le avec quelqu\'un qui va dans votre direction';

  @override
  String get findATraveler => 'TROUVER UN VOYAGEUR';

  @override
  String get trustedRoutes => 'Itinéraires de confiance, utilisateurs vérifiés';

  @override
  String get deliverTo => 'LIVRER À';

  @override
  String get whereIsItGoing => 'Où va-t-il ?';

  @override
  String get deliveryDate => 'DATE DE LIVRAISON';

  @override
  String get chooseADate => 'Choisir une date';

  @override
  String get selectedDate => 'DATE SÉLECTIONNÉE';

  @override
  String get searchTravelers => 'Rechercher des voyageurs';

  @override
  String get sendAnItem => 'Envoyer un article';

  @override
  String get addATrip => 'Ajouter un voyage';

  @override
  String get communityFavorites => 'FAVORIS DE LA COMMUNAUTÉ';

  @override
  String get activeTravelers => 'Voyageurs actifs';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get recentRoutes => 'Itinéraires récents';

  @override
  String get viewAll => 'Voir tout';

  @override
  String get sealedBoxPolicy => 'Politique de boîte scellée';

  @override
  String get sealedBoxPolicyBody =>
      'Les articles doivent toujours être scellés dans leur boîte commerciale d\'origine pour la conformité douanière et la sécurité des voyages.';

  @override
  String get available => 'Disponible';

  @override
  String get home => 'Accueil';

  @override
  String get requests => 'Demandes';

  @override
  String get messages => 'Messages';

  @override
  String get profile => 'Profil';

  @override
  String get searchForTravelers => 'Rechercher des voyageurs';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get whereItemStartsFrom => 'D\'où part l\'article ?';

  @override
  String get departureCountry => 'Pays de départ';

  @override
  String get departureCity => 'Ville de départ';

  @override
  String get whereItemNeedsToGo => 'Où doit aller l\'article ?';

  @override
  String get destinationCountry => 'Pays de destination';

  @override
  String get destinationCity => 'Ville de destination';

  @override
  String get desiredDeliveryDate => 'Date de livraison souhaitée';

  @override
  String get flexibleDays => 'Flexible à ±2 jours';

  @override
  String get searchTravelersButton => 'Rechercher des voyageurs';

  @override
  String get originalPackagingTitle => 'Exigence d\'emballage original';

  @override
  String get originalPackagingBody =>
      'Les articles doivent être scellés dans leur boîte d\'origine. Le prix est calculé automatiquement en fonction de la taille et du poids.';

  @override
  String get recentSearches => 'RECHERCHES RÉCENTES';

  @override
  String get travelerResults => 'Résultats des voyageurs';

  @override
  String get routeAndDate => 'ITINÉRAIRE ET DATE SOUHAITÉE';

  @override
  String get aroundDate => 'Vers le 22 juin 2025 · 4 voyageurs disponibles';

  @override
  String get edit => 'Modifier';

  @override
  String get itemsDelivered => 'articles';

  @override
  String get viewProfile => 'Voir le profil';

  @override
  String get needDifferentDate => 'Besoin d\'une autre date ?';

  @override
  String get getNotified =>
      'Soyez notifié dès que de nouveaux voyageurs ajoutent des trajets sur cet itinéraire.';

  @override
  String get travelerProfile => 'Profil du voyageur';

  @override
  String get frequentTraveler => 'Voyageur fréquent sur la route LOS ⇄ LHR';

  @override
  String get itemsDeliveredStat => 'Articles livrés';

  @override
  String get senderReviews => 'avis d\'expéditeurs';

  @override
  String get onTimeRate => 'Ponctualité';

  @override
  String get travelDateAndRoute => 'DATE ET ITINÉRAIRE DE VOYAGE';

  @override
  String get departure => 'Départ';

  @override
  String get destination => 'Destination';

  @override
  String get directFlight => 'Vol direct';

  @override
  String get pricingLabel => 'Tarif :';

  @override
  String get pricingValue =>
      'Calculé selon la taille et le poids de l\'article';

  @override
  String get itemSizeAndWeight => 'LIMITES DE TAILLE ET DE POIDS ACCEPTÉES';

  @override
  String get weightLimit => 'Limite de poids';

  @override
  String get sizeLimit => 'Limite de taille';

  @override
  String get checkBaggage => 'Espace en bagage enregistré';

  @override
  String get maxDimensions => 'Max. 30 × 20 × 15 cm';

  @override
  String get itemRequirement => 'Exigence relative à l\'article';

  @override
  String get itemRequirementBody =>
      'Les articles doivent être scellés dans leur boîte d\'origine. Cela permet aux voyageurs de les transporter en toute confiance et facilite les contrôles douaniers.';

  @override
  String get deliveryHistoryAndReviews => 'HISTORIQUE DES LIVRAISONS ET AVIS';

  @override
  String get sendRequest => 'Envoyer une demande';

  @override
  String get deliveryRequest => 'Demande de livraison';

  @override
  String get step1of1 => 'Étape 1 sur 1';

  @override
  String get selectedTraveler => 'VOYAGEUR SÉLECTIONNÉ';

  @override
  String get whatIsTheItem => 'Qu\'est-ce que l\'article ?';

  @override
  String get itemCategory => 'Catégorie de l\'article';

  @override
  String get electronics => 'Électronique';

  @override
  String get apparel => 'Vêtements';

  @override
  String get documents => 'Documents';

  @override
  String get itemDescription => 'Description de l\'article';

  @override
  String get packageWeight => 'Poids du colis';

  @override
  String get packageDimensions => 'Dimensions du colis';

  @override
  String get itemPhotos => 'Photos de l\'article (boîte scellée)';

  @override
  String get photoAttached => 'photo jointe';

  @override
  String get addPhoto => 'Ajouter une photo';

  @override
  String get calculatedPrice => 'Prix calculé de l\'article';

  @override
  String get sendDeliveryRequest => 'Envoyer la demande de livraison';

  @override
  String get secureEscrowCheckout => 'Paiement sécurisé en séquestre';

  @override
  String get paymentWindowActive => 'FENÊTRE DE PAIEMENT ACTIVE';

  @override
  String get requestExpires => 'La demande expire dans';

  @override
  String get howEscrowWorks => 'Comment fonctionne la protection en séquestre';

  @override
  String get escrowBody =>
      'Votre paiement est conservé en toute sécurité par Nata. Le voyageur n\'est payé qu\'après que votre destinataire a vérifié la livraison avec le code à 4 chiffres ou une photo.';

  @override
  String get selectPaymentMethod => 'SÉLECTIONNER LE MODE DE PAIEMENT';

  @override
  String get applePay => 'Apple Pay';

  @override
  String get applePaySub => 'Par défaut · Rapide et sécurisé';

  @override
  String get creditCard => 'Carte de crédit ou de débit';

  @override
  String get creditCardSub => 'Visa, Mastercard, Amex';

  @override
  String get mobileMoney => 'Mobile Money';

  @override
  String get mobileMoneyPhoneSub => 'M-Pesa, MTN MoMo, Orange, Wave';

  @override
  String get paymentBreakdown => 'DÉTAIL DU PAIEMENT';

  @override
  String get travelerReward => 'Récompense du voyageur';

  @override
  String get platformFee => 'Protection et commission de séquestre Nata';

  @override
  String get totalEscrow => 'Total à placer en séquestre';

  @override
  String get payIntoEscrow => 'Payer en séquestre';

  @override
  String get cancellationTitle => 'Garantie d\'annulation et de remboursement';

  @override
  String get refundBullet1 =>
      'Remboursement intégral à 100 % si le voyageur annule ou si l\'article n\'est pas livré.';

  @override
  String get refundBullet2 =>
      'Annulation gratuite à tout moment avant la remise physique au voyageur.';

  @override
  String get refundBullet3 =>
      'Fenêtre de litige de 3 jours après la livraison avant la finalisation des fonds.';

  @override
  String get escrowEncrypted => 'Séquestre chiffré 256 bits par Nata Pay';

  @override
  String get deliveryRequests => 'Demandes de livraison';

  @override
  String get incoming => 'Entrantes';

  @override
  String get outgoing => 'Sortantes';

  @override
  String get incomingSection => 'DEMANDES ENTRANTES (EN TANT QUE VOYAGEUR)';

  @override
  String get pendingReview => 'en attente d\'examen';

  @override
  String get outgoingSection => 'DEMANDES SORTANTES (EN TANT QU\'EXPÉDITEUR)';

  @override
  String get total => 'total';

  @override
  String get sender => 'Expéditeur';

  @override
  String get successfulDeliveries => 'livraisons réussies';

  @override
  String get yourTrip => 'Votre voyage :';

  @override
  String get travelDate => 'Date de voyage :';

  @override
  String get item => 'Article :';

  @override
  String get weightAndSize => 'Poids et taille :';

  @override
  String get sealedPhotoAttached => 'photo de boîte scellée jointe';

  @override
  String get viewPhoto => 'Voir la photo';

  @override
  String get viewPhotos => 'Voir les photos';

  @override
  String get decline => 'Refuser';

  @override
  String get acceptRequest => 'Accepter la demande';

  @override
  String get pending => 'En attente';

  @override
  String get accepted => 'Accepté';

  @override
  String get declined => 'Refusé';

  @override
  String get payInTime => 'Payer dans';

  @override
  String get payEscrow => 'Payer le séquestre';

  @override
  String get refundCredited => 'Remboursement crédité sur le solde';

  @override
  String get findAnotherTraveler => 'Trouver un autre voyageur';

  @override
  String get arrangeHandoff => 'Organiser la remise via le chat';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get unreadUpdates => '3 mises à jour non lues';

  @override
  String get searchConversations =>
      'Rechercher des conversations ou un suivi...';

  @override
  String get allFilter => 'Tout (4)';

  @override
  String get activeDeliveries => 'Livraisons actives (2)';

  @override
  String get completed => 'Terminées (1)';

  @override
  String get support => 'Assistance';

  @override
  String get accountAndProfile => 'Compte et profil';

  @override
  String memberSince(String date) {
    return 'Membre depuis $date';
  }

  @override
  String get tripsCarried => 'VOYAGES EFFECTUÉS';

  @override
  String get parcelsSent => 'COLIS ENVOYÉS';

  @override
  String get natawallet => 'PORTEFEUILLE NATA';

  @override
  String get escrowProtected => 'Protégé par séquestre';

  @override
  String get availableForPayout => 'Disponible pour le retrait';

  @override
  String get withdraw => 'Retirer';

  @override
  String get heldInEscrow => 'en séquestre';

  @override
  String get viewHistory => 'Voir l\'historique';

  @override
  String get language => 'Langue';

  @override
  String get currency => 'Devise';

  @override
  String get identityVerification => 'Vérification d\'identité';

  @override
  String get tier1Verified => 'Niveau 1 vérifié · Passeport et biométrie';

  @override
  String get sealedBoxPolicySetting => 'Politique de boîte scellée';

  @override
  String get originalBoxCompliance =>
      'Conformité de sécurité de la boîte d\'origine';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get addATripTitle => 'Ajouter un voyage';

  @override
  String get clear => 'Effacer';

  @override
  String get travelerMode => 'MODE VOYAGEUR';

  @override
  String get headingSomewhere => 'Vous partez quelque part bientôt ?';

  @override
  String get luggageEarnings =>
      'Transformez l\'espace libre de vos bagages en revenus en livrant des colis scellés.';

  @override
  String get departureDetails => 'DÉTAILS DE DÉPART';

  @override
  String get from => 'De';

  @override
  String get arrivalDetails => 'DÉTAILS D\'ARRIVÉE';

  @override
  String get to => 'À';

  @override
  String get departureDate => 'DATE DE DÉPART';

  @override
  String get arrivalDate => 'DATE D\'ARRIVÉE';

  @override
  String get flightTicket => 'REÇU DE BILLET D\'AVION';

  @override
  String get flightTicketSub =>
      'Téléchargez une copie de votre réservation de vol pour confirmer votre voyage';

  @override
  String get uploadFlightReceipt => 'Télécharger le reçu de vol (PDF / Image)';

  @override
  String get replaceFlightReceipt => 'Remplacer le reçu de vol (PDF / Image)';

  @override
  String get luggageCapacity =>
      'CAPACITÉ DE BAGAGES QUE VOUS POUVEZ TRANSPORTER';

  @override
  String get maxWeight => 'Poids maximum';

  @override
  String get maxItemSize => 'Taille maximale de l\'article';

  @override
  String get howMatchingWorks => 'Comment fonctionne la mise en relation';

  @override
  String get howMatchingBody =>
      'Une fois enregistré, votre voyage apparaîtra dans les résultats de recherche pour les expéditeurs cherchant cet itinéraire et cette date.';

  @override
  String get saveAndPublish => 'Enregistrer et publier le voyage';

  @override
  String get confirmDelivery => 'Confirmer la livraison';

  @override
  String get enter4DigitCode => 'Saisir le code à 4 chiffres';

  @override
  String get recipientWillGive =>
      'Votre destinataire vous donnera ce code à la réception de l\'article.';

  @override
  String get codeEntered => 'Code saisi — prêt à confirmer';

  @override
  String get uploadHandoffPhoto => 'Télécharger la photo de remise';

  @override
  String get handoffPhotoSub =>
      'Prenez une photo avec le destinataire ou de l\'article en cours de remise.';

  @override
  String get confirmDeliveryButton =>
      'Confirmer la livraison et libérer le paiement';

  @override
  String get disputeWindow =>
      'Le paiement est libéré après la fenêtre de litige de 3 jours';

  @override
  String get leaveAReview => 'Laisser un avis';

  @override
  String get howWasExperience => 'Comment s\'est passée votre expérience ?';

  @override
  String get whatWentWell => 'Qu\'est-ce qui s\'est bien passé ?';

  @override
  String get leaveComment => 'Laisser un commentaire (facultatif)';

  @override
  String get commentHint =>
      'Décrivez votre expérience — cela aide la communauté...';

  @override
  String get submitReview => 'Soumettre l\'avis';

  @override
  String get skipForNow => 'Ignorer pour l\'instant';

  @override
  String get reviewSubmitted => 'Avis envoyé !';

  @override
  String get reviewThanks =>
      'Merci d\'avoir évalué Amara Kalu. Votre avis aide à maintenir la confiance de la communauté.';

  @override
  String get returningHome => 'Retour à l\'accueil...';

  @override
  String get ratingPoor => 'Mauvais — pas ce que j\'attendais';

  @override
  String get ratingFair => 'Passable — quelques problèmes';

  @override
  String get ratingGood => 'Bien — a répondu aux attentes';

  @override
  String get ratingGreat => 'Très bien — a dépassé les attentes';

  @override
  String get ratingExcellent => 'Excellent — je le recommande !';

  @override
  String get identityVerificationTitle => 'Vérification d\'identité';

  @override
  String get required => 'OBLIGATOIRE';

  @override
  String get almostDone => 'PRESQUE TERMINÉ';

  @override
  String get cancel => 'Annuler';

  @override
  String get step1of2 => 'Étape 1 sur 2';

  @override
  String get step2of2 => 'Étape 2 sur 2';

  @override
  String get skipForNowId => 'Ignorer pour l\'instant';

  @override
  String get actionRequired => 'Action requise avant d\'envoyer';

  @override
  String get actionRequiredBody =>
      'Vous pouvez parcourir les voyageurs à tout moment, mais la vérification d\'identité est obligatoire pour envoyer ou accepter des demandes.';

  @override
  String get verifyIdentity => 'Vérifiez votre identité';

  @override
  String get verifyIdentitySub =>
      'Effectuez 2 étapes rapides pour vous vérifier en moins de 2 minutes.';

  @override
  String get uploadOfficialId => 'Télécharger une pièce d\'identité officielle';

  @override
  String get passportOrId =>
      'Passeport, carte d\'identité nationale ou permis de conduire';

  @override
  String get activeStep => 'Actif';

  @override
  String get nextStep => 'Suivant';

  @override
  String get passportOption => 'Passeport';

  @override
  String get driversLicense => 'Permis de conduire';

  @override
  String get nationalId => 'Carte d\'identité';

  @override
  String get takePhotoOrUpload =>
      'Prenez une photo ou téléchargez la page de couverture';

  @override
  String get allCornersVisible =>
      'Assurez-vous que les 4 coins sont visibles sans reflet';

  @override
  String get useCamera => 'Utiliser la caméra';

  @override
  String get chooseFile => 'Choisir un fichier';

  @override
  String get faceScan => 'Scan facial 3D';

  @override
  String get faceScanSub =>
      'Compare votre selfie en direct avec la photo de votre pièce d\'identité';

  @override
  String get scanIdToContinue => 'Scanner la pièce d\'identité pour continuer';

  @override
  String get biometricNote =>
      'Vos données biométriques sont traitées uniquement à des fins de vérification d\'identité.';

  @override
  String get step1Completed => 'Étape 1 terminée';

  @override
  String get passportVerified =>
      'Document de passeport vérifié · Fortune Niama';

  @override
  String get editId => 'Modifier la pièce d\'identité';

  @override
  String get faceScanTitle => 'Scan biométrique facial 3D';

  @override
  String get faceScanBody =>
      'Centrez votre visage dans le cadre pour vérifier la vivacité et confirmer votre identité.';

  @override
  String get holdStill => 'Restez immobile, regardez directement l\'écran';

  @override
  String get nodHead => 'Hochez lentement la tête quand le bord devient vert.';

  @override
  String get goodLight => 'Bonne lumière';

  @override
  String get noGlasses => 'Sans lunettes';

  @override
  String get neutralFace => 'Visage neutre';

  @override
  String get startBiometricScan => 'Démarrer le scan biométrique';

  @override
  String get biometricLocalNote =>
      'Les scans faciaux biométriques sont traités localement pour correspondre à votre passeport.';

  @override
  String get fullyVerified => 'Vous êtes entièrement vérifié !';

  @override
  String get fullyVerifiedSub =>
      'Vos documents d\'identité et scan biométrique ont été authentifiés avec succès.';

  @override
  String get verificationReport => 'RAPPORT DE VÉRIFICATION';

  @override
  String get instantApproval => 'Approbation instantanée ✓';

  @override
  String get passportIdDoc => 'Document d\'identité (Passeport)';

  @override
  String get biometricLiveness => 'Vivacité biométrique 3D';

  @override
  String get trustLimit => 'Limite de confiance et de séquestre';

  @override
  String get unlockedPerks => 'AVANTAGES MEMBRES DÉBLOQUÉS';

  @override
  String get perk1 => 'Publier des voyages illimités';

  @override
  String get perk2 => 'Libération rapide des paiements';

  @override
  String get perk3 => 'Badge de profil vérifié';

  @override
  String get perk4 => 'Priorité dans les résultats';

  @override
  String get continueToHome => 'Continuer vers l\'accueil';

  @override
  String get viewPublicProfile => 'Voir le profil public';

  @override
  String get encrypted256 => 'Chiffrement 256 bits';

  @override
  String get instantAi => 'Vérification IA instantanée';

  @override
  String get gdprCompliant => 'Conforme RGPD et KYC';

  @override
  String get trips => 'Trajets';

  @override
  String get identityActionRequiredSub =>
      'Action requise : vérifiez votre identité';

  @override
  String get identityUnderReview =>
      'La vérification est actuellement en cours d\'examen';

  @override
  String get verificationReviewing => 'En cours d\'examen';

  @override
  String get ratingStat => 'Note';

  @override
  String get upcomingTrips => 'PROCHAINS TRAJETS';

  @override
  String get newTravelerRating => 'Nouveau';

  @override
  String get upcomingTripsStat => 'Prochains trajets';

  @override
  String travelerOnRoute(String from, String to) {
    return 'Voyageur sur la route $from ⇄ $to';
  }

  @override
  String frequentTravelerOnRoute(String from, String to) {
    return 'Voyageur fréquent sur la route $from ⇄ $to';
  }

  @override
  String get noReviewsYet => 'Pas encore d\'avis';

  @override
  String get myTrips => 'Mes trajets';

  @override
  String get tabUpcoming => 'À venir';

  @override
  String get tabPast => 'Passés';

  @override
  String get tripPublished => 'Publié';

  @override
  String get tripInReview => 'En cours d\'examen';

  @override
  String get tripCompleted => 'Terminé';

  @override
  String get tripCancelled => 'Annulé';

  @override
  String get editTrip => 'Modifier le trajet';

  @override
  String get viewRequests => 'Voir les demandes';

  @override
  String get maxWeightLabel => 'Poids max.';

  @override
  String get maxSizeLabel => 'Taille max.';

  @override
  String get noUpcomingTrips => 'Aucun trajet à venir';

  @override
  String get noPastTrips => 'Aucun trajet passé';

  @override
  String get addTripPrompt =>
      'Ajoutez un trajet pour rentabiliser l\'espace de vos bagages.';

  @override
  String get tripInReviewNote =>
      'Nous examinons votre trajet. Il sera publié une fois approuvé.';

  @override
  String get couldNotLoadTrips => 'Impossible de charger vos trajets.';

  @override
  String get retry => 'Réessayer';

  @override
  String get saveChanges => 'Enregistrer';

  @override
  String get tripSubmitted => 'Trajet envoyé pour examen';

  @override
  String get tripUpdated => 'Trajet mis à jour';

  @override
  String get selectCountry => 'Choisir un pays';

  @override
  String get selectCity => 'Choisir une ville';

  @override
  String get selectDate => 'Choisir une date';

  @override
  String get tripPrice => 'PRIX PAR ARTICLE';

  @override
  String get tripPriceHint => 'Vos frais pour transporter un article';

  @override
  String get errPickDeparture => 'Choisissez votre lieu de départ.';

  @override
  String get errPickArrival => 'Choisissez votre destination.';

  @override
  String get errSameCity =>
      'Le départ et l\'arrivée doivent être des villes différentes.';

  @override
  String get errPickDepDate => 'Choisissez une date de départ.';

  @override
  String get errPickArrDate => 'Choisissez une date d\'arrivée.';

  @override
  String get errArrivalBeforeDeparture =>
      'L\'arrivée ne peut pas précéder le départ.';

  @override
  String get errAttachReceipt => 'Joignez votre reçu de vol.';

  @override
  String get errPrice => 'Saisissez un prix valide.';

  @override
  String get errSaveFailed =>
      'Impossible d\'enregistrer votre trajet. Réessayez.';

  @override
  String itemsDeliveredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles livrés',
      one: '1 article livré',
    );
    return '$_temp0';
  }

  @override
  String get bookingReference => 'Référence de réservation';

  @override
  String get bookingReferenceSub =>
      'Saisissez le code de référence de votre réservation de vol (PNR)';

  @override
  String get errBookingReference =>
      'La référence de réservation doit comporter 5 à 8 lettres ou chiffres.';

  @override
  String bookingReferenceShort(String code) {
    return 'Réf. $code';
  }

  @override
  String get verificationPending => 'Vérification en attente';

  @override
  String get verificationUnverified => 'Non vérifié';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get uploadFile => 'Téléverser un fichier';

  @override
  String get errCamera => 'Impossible d\'ouvrir l\'appareil photo.';

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllRead => 'Tout marquer comme lu';

  @override
  String get paymentsFilter => 'Paiements';

  @override
  String get notifToday => 'Aujourd\'hui';

  @override
  String get notifEarlier => 'Plus tôt';

  @override
  String get noNotifications => 'Aucune notification pour le moment';

  @override
  String get noNotificationsSub =>
      'Nous vous préviendrons ici dès qu\'il se passe quelque chose avec vos trajets, demandes et paiements.';

  @override
  String get couldNotLoadNotifications =>
      'Impossible de charger vos notifications.';

  @override
  String get justNow => 'À l\'instant';

  @override
  String get yesterdayLabel => 'Hier';

  @override
  String minutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String hoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String get notifFilterAll => 'Toutes';

  @override
  String get faceIdReason =>
      'Confirmez que c\'est vous pour vous connecter à Nata';

  @override
  String get faceIdSignInFirst =>
      'Pour utiliser Face ID, connectez-vous d\'abord avec votre numéro de téléphone en laissant « Se souvenir de moi » coché.';

  @override
  String get faceIdUnavailable =>
      'Face ID n\'est pas disponible sur cet appareil.';

  @override
  String get faceIdNotSetUp =>
      'Configurez d\'abord Face ID dans les réglages de votre appareil.';

  @override
  String get faceIdFailed =>
      'Face ID ne vous a pas reconnu. Réessayez ou connectez-vous avec votre numéro de téléphone.';

  @override
  String get faceIdLocked =>
      'Face ID est verrouillé pour le moment. Connectez-vous avec votre numéro de téléphone.';

  @override
  String splashDetectedSummary(
    String country,
    String language,
    String currency,
  ) {
    return '$country · $language et $currency';
  }

  @override
  String get messagesCaughtUp => 'Vous êtes à jour';

  @override
  String get searchChats => 'Rechercher par nom, trajet ou article';

  @override
  String get noConversations => 'Aucune conversation pour le moment';

  @override
  String get noConversationsSub =>
      'Lorsque vous envoyez ou recevez une demande de livraison, votre discussion avec le voyageur ou l\'expéditeur apparaît ici.';

  @override
  String get noChatMatches =>
      'Aucune conversation ne correspond à votre recherche';

  @override
  String get couldNotLoadMessages => 'Impossible de charger vos messages.';

  @override
  String get couldNotLoadChat => 'Impossible de charger cette discussion.';

  @override
  String get typeMessage => 'Écrivez un message…';

  @override
  String get msgSending => 'Envoi…';

  @override
  String get msgSent => 'Envoyé ✓';

  @override
  String get msgRead => 'Lu ✓✓';

  @override
  String get msgFailed => 'Non envoyé · touchez pour réessayer';

  @override
  String get chatEmpty => 'Pas encore de messages. Dites bonjour !';

  @override
  String get chatPhotoLabel => 'Photo';

  @override
  String get chatChoosePhoto => 'Choisir dans la photothèque';

  @override
  String get chatPhotoFailed => 'Impossible d\'envoyer la photo.';

  @override
  String get chatCameraFailed =>
      'Impossible d\'ouvrir l\'appareil photo ou les photos.';

  @override
  String get chatPhotoLoadFailed => 'Photo indisponible';

  @override
  String unreadMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages non lus',
      one: '1 message non lu',
    );
    return '$_temp0';
  }

  @override
  String filterAllCount(int count) {
    return 'Toutes ($count)';
  }

  @override
  String filterActiveCount(int count) {
    return 'En cours ($count)';
  }

  @override
  String filterCompletedCount(int count) {
    return 'Terminées ($count)';
  }

  @override
  String chatYouPrefix(String text) {
    return 'Vous : $text';
  }
}
