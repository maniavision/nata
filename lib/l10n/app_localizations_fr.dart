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
      'Calculé selon la distance, la taille et le poids de l\'article';

  @override
  String get sameDayDelivery => 'Livraison le même jour';

  @override
  String deliverInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Livraison en $count jours',
      one: 'Livraison en 1 jour',
    );
    return '$_temp0';
  }

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
  String get sendDeliveryRequest => 'Envoyer la demande';

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
  String get mobileMoneyPhoneSub => 'MTN MoMo, Airtel, Orange, M-Pesa';

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
      'L\'annulation est gratuite jusqu\'à ce que le voyageur accepte. Ensuite, des frais d\'annulation de 10 % s\'appliquent jusqu\'à la remise.';

  @override
  String get refundBullet3 =>
      'Fenêtre de litige de 3 jours après la livraison avant la finalisation des fonds.';

  @override
  String get escrowEncrypted => 'Séquestre chiffré 256 bits par Nata Pay';

  @override
  String get deliveryRequests => 'Demandes de livraison';

  @override
  String get requestsActive => 'En cours';

  @override
  String get requestsArchive => 'Archives';

  @override
  String requestsArchiveCount(int count) {
    return 'Archives · $count';
  }

  @override
  String get requestsArchiveNote =>
      'Les demandes livrées, annulées et expirées arrivent ici 24 heures après leur clôture, ou quand vous les faites glisser.';

  @override
  String get requestsArchiveEmpty => 'Rien d\'archivé pour l\'instant.';

  @override
  String get archiveAction => 'Archiver';

  @override
  String get requestArchived => 'Déplacée dans les archives';

  @override
  String get errArchiveRequest =>
      'Impossible d\'archiver cette demande. Réessayez.';

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
  String tripsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyages',
      one: '1 voyage',
      zero: '0 voyage',
    );
    return '$_temp0';
  }

  @override
  String parcelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colis',
      one: '1 colis',
      zero: '0 colis',
    );
    return '$_temp0';
  }

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
  String get driversLicense => 'Permis';

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
      'Votre selfie est comparé à la photo de votre pièce d\'identité par notre service de vérification sécurisé et conservé de façon privée.';

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
  String get tripPublishedToast => 'Trajet publié';

  @override
  String get tripUpdated => 'Trajet mis à jour';

  @override
  String get selectCountry => 'Choisir un pays';

  @override
  String get selectCity => 'Choisir une ville';

  @override
  String get selectDate => 'Choisir une date';

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
  String get notifDelete => 'Supprimer';

  @override
  String get errNotifDelete =>
      'Impossible de supprimer la notification. Réessayez.';

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

  @override
  String get recipientDetails => 'Informations du destinataire';

  @override
  String get recipientName => 'Nom du destinataire';

  @override
  String get recipientNameHint => 'Nom complet comme sur sa pièce d\'identité';

  @override
  String get recipientPhone => 'Téléphone du destinataire';

  @override
  String get recipientPhoneHint => 'ex. +44 7700 900123';

  @override
  String get recipientPhoneNote =>
      'Partagé avec le voyageur uniquement après qu\'il a accepté votre demande';

  @override
  String get recipientSmsConsent =>
      'En ajoutant ce numéro, vous confirmez que le destinataire a accepté de recevoir son code de livraison Nata par SMS.';

  @override
  String get sizeAndWeight => 'Taille et poids';

  @override
  String travelerLimitLabel(String limit) {
    return 'Limite du voyageur : $limit';
  }

  @override
  String get itemNameHint => 'ex. Casque Sony, cosmétiques scellés, etc.';

  @override
  String get itemDescHint =>
      'Donnez des détails sur l\'article et son emballage...';

  @override
  String get weightHint => 'ex. 0,9 kg';

  @override
  String get dimensionsHint => 'ex. 24 × 24 × 8 cm';

  @override
  String get photoMustShowSeal => 'La photo doit montrer le sceau d\'usine';

  @override
  String get travelerPriceLine => 'Prix du voyageur';

  @override
  String get platformProtectionLine =>
      'Protection de la plateforme et séquestre';

  @override
  String get priceNoteNothingCharged =>
      'Rien n\'est débité maintenant. Le voyageur peut accepter ou refuser cette demande et vous ne payez qu\'après son acceptation.';

  @override
  String get choosePhotoSource => 'Ajouter une photo';

  @override
  String get errItemName => 'Indiquez de quel article il s\'agit.';

  @override
  String get emergencyContactLabel => 'Contact d\'urgence';

  @override
  String get ecStepOf => 'Étape 2 sur 2';

  @override
  String get ecTitle => 'Ajoutez un contact d\'urgence';

  @override
  String get ecBody =>
      'Une personne que nous pouvons joindre en cas de problème pendant une livraison.';

  @override
  String get ecFullName => 'Nom complet';

  @override
  String get ecFullNameHint => 'Nom complet du contact';

  @override
  String get ecPhone => 'Numéro de téléphone';

  @override
  String get ecPhoneHint => 'ex. 7700 900123';

  @override
  String get ecRelationship => 'Lien';

  @override
  String get relFriend => 'Ami(e)';

  @override
  String get relRelative => 'Parent';

  @override
  String get relPartner => 'Conjoint(e)';

  @override
  String get relColleague => 'Collègue';

  @override
  String get ecPrivacy =>
      'Votre contact d\'urgence n\'est jamais montré aux expéditeurs ni aux voyageurs et n\'est utilisé par notre équipe d\'assistance que si nous ne parvenons pas à vous joindre.';

  @override
  String get ecFinish => 'Terminer la vérification';

  @override
  String get ecFootnote =>
      'Vos informations sont stockées en toute sécurité et utilisées uniquement à des fins de sécurité.';

  @override
  String get errContactName => 'Saisissez le nom complet du contact.';

  @override
  String get errContactPhone =>
      'Saisissez un numéro valide pour l\'indicatif de pays choisi.';

  @override
  String get errIdNotRecognized =>
      'Ceci ne ressemble pas à une pièce d\'identité. Téléversez une photo nette de la page entière.';

  @override
  String get errIdNoFace =>
      'Nous n\'avons pas trouvé la photo d\'identité. Téléversez une image nette de la page montrant votre visage.';

  @override
  String get errIdUnreadable =>
      'Nous n\'avons pas pu lire le texte de cette pièce d\'identité. Téléversez une photo nette et bien éclairée de la pièce entière.';

  @override
  String get idTypePassport => 'passeport';

  @override
  String get idTypeDriversLicense => 'permis de conduire';

  @override
  String get idTypeNationalId => 'carte d\'identité nationale';

  @override
  String errIdWrongType(String document) {
    return 'Ce document ne semble pas être du type « $document ». Choisissez le bon type ci-dessus ou téléversez le bon document.';
  }

  @override
  String get faceScanIntro =>
      'On vous demandera de cligner des yeux et de tourner la tête, puis nous comparerons votre visage à la photo de votre pièce d\'identité.';

  @override
  String get livenessNoFace => 'Placez votre visage dans l\'ovale';

  @override
  String get livenessMultipleFaces => 'Vous seul devez apparaître à l\'image';

  @override
  String get livenessBlink => 'Clignez lentement des yeux';

  @override
  String get livenessTurnHead => 'Tournez la tête à gauche, puis à droite';

  @override
  String get livenessLookStraight => 'Regardez la caméra et ne bougez plus';

  @override
  String get faceScanVerifying =>
      'Comparaison de votre visage avec votre pièce d\'identité…';

  @override
  String get faceScanVerified => 'Visage reconnu. Vous êtes vérifié !';

  @override
  String faceScanNoMatch(int count) {
    return 'Votre visage ne correspond pas à la photo de votre pièce d\'identité. Essais restants : $count.';
  }

  @override
  String faceScanNoFace(int count) {
    return 'Nous n\'avons pas bien vu votre visage. Réessayez avec un bon éclairage. Essais restants : $count.';
  }

  @override
  String get faceScanManualReview =>
      'Nous n\'avons pas pu confirmer votre visage automatiquement. Notre équipe examinera votre pièce d\'identité.';

  @override
  String get faceScanTimeout =>
      'Temps écoulé. Assurez-vous d\'être bien éclairé et réessayez.';

  @override
  String get faceScanCameraDenied =>
      'Autorisez l\'accès à la caméra dans Réglages pour scanner votre visage.';

  @override
  String get faceScanError => 'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get faceScanTryAgain => 'Réessayer';

  @override
  String get faceScanContinue => 'Continuer';

  @override
  String get faceScanSkip =>
      'Continuer sans vérification faciale (examen manuel)';

  @override
  String get acceptedInProgress => 'Acceptées et en cours';

  @override
  String activeCount(int count) {
    return '$count active(s)';
  }

  @override
  String get yourPayout => 'Votre paiement';

  @override
  String get tripLabel => 'Trajet :';

  @override
  String get nextAction => 'Prochaine étape :';

  @override
  String get attachReceivedPhoto => 'Joindre la photo de réception';

  @override
  String get manageDeliveryAttachProof =>
      'Gérer la livraison et joindre la preuve';

  @override
  String pendingRequestsCount(int count) {
    return 'DEMANDES EN ATTENTE ($count)';
  }

  @override
  String get awaitingYourResponse => 'En attente de votre réponse';

  @override
  String get deliveryTaskDetails => 'Détails de la livraison';

  @override
  String orderNumber(String id) {
    return 'Commande n° $id';
  }

  @override
  String get inProgress => 'En cours';

  @override
  String get senderVerifiedIdentity => 'Expéditeur · Identité vérifiée';

  @override
  String get inEscrow => '(En séquestre)';

  @override
  String get deliveryRoute => 'Itinéraire';

  @override
  String get itemToCarry => 'Article à transporter';

  @override
  String get itemReceivedFromSender => 'Article reçu de l\'expéditeur';

  @override
  String get attached => 'Jointe';

  @override
  String get itemReceivedNote =>
      'Vérifiez que le produit est entièrement scellé dans sa boîte d\'origine avant de le prendre en charge.';

  @override
  String get retake => 'Reprendre';

  @override
  String get itemDeliveredToRecipient => 'Article remis au destinataire';

  @override
  String get pendingDelivery => 'Livraison en attente';

  @override
  String handoverNote(String city) {
    return 'Joignez une photo de la remise au destinataire à $city pour débloquer immédiatement le paiement en séquestre.';
  }

  @override
  String get takeOrUploadHandoverPhoto =>
      'Prendre ou téléverser la photo de remise';

  @override
  String get handoverPhotoHint =>
      'Photo avec le destinataire ou sur le lieu de livraison';

  @override
  String get handoverPhotoAttached => 'Photo de remise jointe';

  @override
  String get recipientNameLabel => 'Nom du destinataire :';

  @override
  String get recipientPhoneLabel => 'Téléphone du destinataire :';

  @override
  String get meetingSpotLabel => 'Lieu de rendez-vous :';

  @override
  String confirmDeliveryClaim(String amount) {
    return 'Confirmer et recevoir $amount';
  }

  @override
  String get escrowReleaseNote =>
      'Les fonds en séquestre seront versés immédiatement sur votre portefeuille.';

  @override
  String get attachHandoverFirst => 'Joignez d\'abord la photo de remise.';

  @override
  String get recipientLocalPhoneHint => 'ex. 7700 900123';

  @override
  String get paymentSettings => 'Paramètres de paiement';

  @override
  String get paymentSettingsSub => 'Moyens de paiement et compte de versement';

  @override
  String get paymentMethods => 'Moyens de paiement';

  @override
  String get add => 'Ajouter';

  @override
  String get remove => 'Retirer';

  @override
  String get defaultLabel => 'Par défaut';

  @override
  String get payoutAccount => 'Compte de versement';

  @override
  String get payoutAccountNote =>
      'Les gains sont versés sur ce compte dès que le code de livraison du destinataire est confirmé.';

  @override
  String get addPayoutAccount => 'Ajouter un compte de versement';

  @override
  String get preferences => 'Préférences';

  @override
  String get defaultCurrency => 'Devise par défaut';

  @override
  String get defaultCurrencySub => 'Pour les versements et les reçus';

  @override
  String get payoutSchedule => 'Calendrier des versements';

  @override
  String get payoutScheduleSub => 'Après confirmation de la livraison';

  @override
  String get automatic => 'Automatique';

  @override
  String get transactions => 'Transactions';

  @override
  String get addPaymentMethod => 'Ajouter un moyen de paiement';

  @override
  String get paymentSecurityNote =>
      'Vos données de paiement sont chiffrées et conservées en toute sécurité. Les paiements restent en séquestre jusqu\'à la confirmation de la livraison.';

  @override
  String get paymentKindCard => 'Carte';

  @override
  String get paymentKindCardSub => 'Débit ou crédit';

  @override
  String get paymentKindMobile => 'Mobile Money';

  @override
  String get paymentKindAppleSub => 'Paiement rapide';

  @override
  String get cardDetails => 'Détails de la carte';

  @override
  String get nameOnCard => 'Nom sur la carte';

  @override
  String get nameOnCardHint => 'Nom complet tel qu\'indiqué sur la carte';

  @override
  String get cardNumber => 'Numéro de carte';

  @override
  String get expiryDate => 'Date d\'expiration';

  @override
  String get mobileMoneyDetails => 'Détails Mobile Money';

  @override
  String get provider => 'Opérateur';

  @override
  String get mobileNumber => 'Numéro de mobile';

  @override
  String get registeredName => 'Nom enregistré';

  @override
  String get registeredNameHint => 'Nom enregistré auprès de l\'opérateur';

  @override
  String get applePayNote =>
      'Apple Pay sera lié au portefeuille de votre identifiant Apple. Vous le confirmerez avec Face ID sur votre appareil.';

  @override
  String get setAsDefault => 'Définir par défaut';

  @override
  String get setAsDefaultSub =>
      'Utiliser ce moyen pour les prochaines demandes';

  @override
  String get savePaymentMethod => 'Enregistrer le moyen de paiement';

  @override
  String get errCardName => 'Saisissez le nom tel qu\'il figure sur la carte.';

  @override
  String get errCardNumber => 'Saisissez un numéro de carte valide.';

  @override
  String get errCardExpiry =>
      'Saisissez une date d\'expiration valide (MM/AA).';

  @override
  String get errCardCvv => 'Saisissez le code de sécurité à 3 ou 4 chiffres.';

  @override
  String get errMobileNumber =>
      'Saisissez le numéro avec l\'indicatif du pays, ex. +254 712 345 678.';

  @override
  String get errRegisteredName =>
      'Saisissez le nom enregistré auprès de l\'opérateur.';

  @override
  String cardExpires(String date) {
    return 'Expire $date';
  }

  @override
  String holdersIphone(String name) {
    return 'iPhone de $name';
  }

  @override
  String get errPaymentSettingsLoad =>
      'Impossible de charger vos paramètres de paiement. Veuillez réessayer.';

  @override
  String get errPaymentSettingsSave =>
      'Impossible d\'enregistrer la modification. Veuillez réessayer.';

  @override
  String get noPaymentMethods =>
      'Aucun moyen de paiement pour l\'instant. Ajoutez-en un pour payer vos demandes de livraison.';

  @override
  String get noPayoutAccount => 'Aucun compte de versement pour l\'instant.';

  @override
  String get weekly => 'Hebdomadaire';

  @override
  String get manual => 'Manuel';

  @override
  String get faceScanLivenessNote =>
      'L\'IA biométrique vérifie en temps réel votre présence pour confirmer que vous êtes le titulaire du document.';

  @override
  String get deliveryPayoutRelease => 'Livraison et versement';

  @override
  String get confirmDeliveryStep => 'Étape 3 sur 4 : Confirmer la livraison';

  @override
  String get itemArrivedAtDestination => 'Article arrivé à destination';

  @override
  String get confirmHandoffNote =>
      'Demandez au destinataire son code de livraison à 4 chiffres et saisissez-le ci-dessous. Le bon code confirme la livraison et déclenche votre paiement.';

  @override
  String get pinOptionTitle => 'Code de livraison à 4 chiffres';

  @override
  String get instantRelease => 'Versement immédiat';

  @override
  String get pinOptionNote =>
      'L\'expéditeur a communiqué un code secret à 4 chiffres au destinataire. Saisissez-le ci-dessous :';

  @override
  String get pinConfirmed => 'Code PIN du destinataire confirmé';

  @override
  String get pinMismatch =>
      'Ce code PIN ne correspond pas à celui du destinataire.';

  @override
  String get photoOptionTitle => 'Option 2 : photo de la remise';

  @override
  String get alternative => 'Alternative';

  @override
  String get noHandoffPhoto => 'Pas encore de photo de remise';

  @override
  String get handoffPhotoHint =>
      'Une photo de l\'article scellé au moment de la remise';

  @override
  String get sealIntactPhoto => 'Scellé intact';

  @override
  String get change => 'Modifier';

  @override
  String get payoutDestination => 'Compte de versement du voyageur';

  @override
  String payoutAmount(String amount) {
    return 'Versement de +$amount';
  }

  @override
  String get noPayoutAccountForRelease =>
      'Aucun compte de versement. Ajoutez-en un dans Paramètres de paiement ; le versement y sera envoyé.';

  @override
  String get mobileMoneyPayoutSpeed => 'Mobile Money · Versement immédiat';

  @override
  String get bankPayoutSpeed => 'Virement bancaire · 1 jour ouvré';

  @override
  String get disputeProtectionWindow =>
      'Délai de protection contre les litiges';

  @override
  String get threeDaysActive => '3 jours actifs';

  @override
  String get disputeProtectionNote =>
      'Votre paiement est envoyé dès que le code est confirmé. L\'expéditeur peut encore signaler un problème pendant 3 jours.';

  @override
  String get reportIssue => 'Signaler un problème ou ouvrir un litige';

  @override
  String confirmReleasePayout(String amount) {
    return 'Confirmer et verser ($amount)';
  }

  @override
  String get requestUpdated => 'Demande mise à jour';

  @override
  String get errRequestNotFound => 'Cette demande n\'existe plus.';

  @override
  String get errRequestNotEditable =>
      'Le voyageur a déjà répondu à cette demande : elle ne peut plus être modifiée.';

  @override
  String get editRequest => 'Modifier la demande';

  @override
  String saveChangesWithPrice(String price) {
    return 'Enregistrer · $price';
  }

  @override
  String get statusExpired => 'Expirée';

  @override
  String get statusPaid => 'Payée';

  @override
  String get statusInTransit => 'En transit';

  @override
  String get statusDelivered => 'Livrée';

  @override
  String get statusCancelled => 'Annulée';

  @override
  String get noSentRequests => 'Vous n\'avez encore envoyé aucune demande.';

  @override
  String get errLoadRequests => 'Impossible de charger vos demandes.';

  @override
  String get tapToEdit => 'Touchez pour modifier';

  @override
  String get errIdNameMismatch =>
      'Le nom sur cette pièce d\'identité ne correspond pas à celui de votre profil. Téléversez une pièce affichant vos prénom et nom, ou mettez à jour le nom de votre profil.';

  @override
  String get errContactSave =>
      'Impossible d\'enregistrer le contact. Veuillez réessayer.';

  @override
  String get updateAvailableTitle => 'Mise à jour disponible';

  @override
  String updateAvailableBody(String latest, String current) {
    return 'Nata $latest est disponible. Vous utilisez la version $current.';
  }

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String get updateRequiredBody =>
      'Cette version de Nata n\'est plus prise en charge. Veuillez la mettre à jour pour continuer à utiliser l\'application.';

  @override
  String get updateWhatsNew => 'Nouveautés';

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateOpenFailed =>
      'Impossible d\'ouvrir la boutique. Recherchez Nata dans votre boutique d\'applications.';

  @override
  String get errAccountNotFound =>
      'Aucun compte n\'existe pour ce numéro. Veuillez d\'abord vous inscrire.';

  @override
  String get itemsTitle => 'Articles';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String itemNumber(int number) {
    return 'Article $number';
  }

  @override
  String get removeItem => 'Retirer';

  @override
  String get addAnotherItem => 'Ajouter un autre article';

  @override
  String errItemNameN(int number) {
    return 'Indiquez de quel article il s\'agit pour l\'article $number.';
  }

  @override
  String itemsMaxNote(int max) {
    return 'Vous pouvez envoyer jusqu\'à $max articles par demande.';
  }

  @override
  String get errRecipientName => 'Saisissez le nom complet du destinataire.';

  @override
  String get errRecipientPhone =>
      'Saisissez un numéro de téléphone valide pour le destinataire.';

  @override
  String get errWeight => 'Saisissez le poids du colis, ex. 0,9 kg.';

  @override
  String get errPhotoRequired =>
      'Ajoutez au moins une photo de l\'article scellé.';

  @override
  String get errPhotoTooBig => 'Cette photo est trop volumineuse (max 10 Mo).';

  @override
  String get errPhotoLimit => 'Vous pouvez ajouter jusqu\'à 3 photos.';

  @override
  String get errTripUnavailable => 'Ce trajet n\'est plus disponible.';

  @override
  String get errOwnTrip =>
      'Vous ne pouvez pas envoyer un colis avec votre propre trajet.';

  @override
  String get errDuplicate =>
      'Vous avez déjà une demande en cours sur ce trajet.';

  @override
  String errDestinationLimit(String city) {
    return 'Vous avez déjà 5 demandes en cours vers $city. Vous pourrez en envoyer une autre dès que l\'une d\'elles sera livrée, refusée ou expirée.';
  }

  @override
  String get cancelRequest => 'Annuler la demande';

  @override
  String get cancelRequestTitle => 'Annuler cette demande ?';

  @override
  String get cancelRequestFreeBody =>
      'Le voyageur n\'a pas encore accepté, l\'annulation est donc gratuite.';

  @override
  String cancelRequestFeeBody(String fee) {
    return 'Le voyageur a déjà accepté cette demande. Annuler maintenant entraîne des frais d\'annulation de 10 %, soit $fee.';
  }

  @override
  String get keepRequest => 'Garder la demande';

  @override
  String cancelWithFee(String fee) {
    return 'Annuler et payer $fee';
  }

  @override
  String get requestCancelled => 'Demande annulée';

  @override
  String cancellationFeeCharged(String fee) {
    return 'Frais d\'annulation : $fee';
  }

  @override
  String get cancelledFreeOfCharge => 'Annulée sans frais';

  @override
  String get errFeeChanged =>
      'Le voyageur vient de répondre à cette demande, les frais d\'annulation ont donc changé. Vérifiez et réessayez.';

  @override
  String get errNotCancellable => 'Cette demande ne peut plus être annulée.';

  @override
  String get errCancelFailed =>
      'Impossible d\'annuler votre demande. Veuillez réessayer.';

  @override
  String sentRequestsCount(int count) {
    return 'DEMANDES ENVOYÉES ($count)';
  }

  @override
  String get waitingForTraveler => 'En attente du voyageur';

  @override
  String get routeLabel => 'Trajet :';

  @override
  String travelerDeliveries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Voyageur · $count livraisons',
      one: 'Voyageur · 1 livraison',
      zero: 'Voyageur · Nouveau',
    );
    return '$_temp0';
  }

  @override
  String get errSessionExpired => 'Votre session a expiré. Reconnectez-vous.';

  @override
  String get errInvalidRequest =>
      'Certaines informations ont été refusées. Vérifiez le formulaire.';

  @override
  String get errRequestFailed =>
      'Impossible d\'envoyer votre demande. Réessayez.';

  @override
  String get requestSent => 'Demande envoyée. Le voyageur va l\'examiner.';

  @override
  String travelerMaxKg(String kg) {
    return 'Max $kg kg';
  }

  @override
  String errWeightTooHeavy(String max) {
    return 'Ce voyageur accepte jusqu\'à $max kg.';
  }

  @override
  String photosAttachedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos jointes',
      one: '1 photo jointe',
      zero: 'Aucune photo',
    );
    return '$_temp0';
  }

  @override
  String sendRequestWithPrice(String price) {
    return 'Envoyer la demande · $price';
  }

  @override
  String get packageSize => 'Taille du colis';

  @override
  String get sizeEnvelope => 'Enveloppe / Document';

  @override
  String get sizeShoebox => 'Boîte à chaussures';

  @override
  String get sizeBackpack => 'Sac à dos';

  @override
  String get errSizeRequired => 'Choisissez la taille du colis.';

  @override
  String get errSizeTooBig =>
      'Ce colis est plus grand que ce que le voyageur accepte.';

  @override
  String get errPriceChanged =>
      'Le prix a changé depuis que vous avez ouvert cette demande. Revenez en arrière et rouvrez-la pour voir le nouveau prix.';

  @override
  String get priceEnterWeight =>
      'Saisissez le poids du colis pour voir le prix final.';

  @override
  String get priceRateUnavailable =>
      'Taux de change indisponible, les prix sont donc affichés en dollars américains.';

  @override
  String get priceCredit => 'Taux de change par Exchange Rate API';

  @override
  String get priceCalculating => 'Calcul du prix…';

  @override
  String get errQuoteUnavailable =>
      'Impossible de calculer le prix. Vérifiez votre connexion et réessayez.';

  @override
  String priceBasedOn(String km) {
    return 'Selon la distance ($km km), le poids et la date de livraison';
  }

  @override
  String priceRateLine(String rate, String currency, String date) {
    return '1 USD = $rate $currency · mis à jour $date';
  }

  @override
  String get departingFrom => 'Départ de';

  @override
  String get hello => 'Bonjour,';

  @override
  String get whereAreYouSending => 'Où envoyez-vous ?';

  @override
  String get whereSendingFrom => 'D\'où envoyez-vous ?';

  @override
  String get destinationExample => 'ex. Londres, Royaume-Uni';

  @override
  String get anytimeThisMonth => 'N\'importe quand ce mois-ci';

  @override
  String get flexibleShort => '(±3 j)';

  @override
  String get availableTravelers => 'Voyageurs disponibles';

  @override
  String get errLoadTravelers => 'Impossible de charger les voyageurs.';

  @override
  String get noTravelersOnRoute =>
      'Aucun voyageur sur ce trajet pour l\'instant.';

  @override
  String get desiredDeliveryDateTitle => 'Date de livraison souhaitée';

  @override
  String upToKg(String weight) {
    return 'Jusqu\'à $weight kg';
  }

  @override
  String get dateAnytime => 'N\'importe quand';

  @override
  String get dateThisWeek => 'Cette semaine';

  @override
  String get dateNextWeek => 'Semaine prochaine';

  @override
  String get dateFlexible => 'Flexible (±3 j)';

  @override
  String travelerFlightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vols de voyageurs',
      one: '1 vol de voyageur',
    );
    return '$_temp0';
  }

  @override
  String flightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vols',
      one: '1 vol',
    );
    return '$_temp0';
  }

  @override
  String get plusMinus3Days => '±3 jours';

  @override
  String get anyDate => 'N\'importe quelle date';

  @override
  String get selectADate => 'Sélectionnez une date';

  @override
  String confirmDateOn(String date) {
    return 'Confirmer la date ($date)';
  }

  @override
  String get confirmDateAnytime => 'Confirmer la date (n\'importe quand)';

  @override
  String get searchCountryHint => 'Rechercher un pays...';

  @override
  String searchCityIn(String country) {
    return 'Rechercher une ville en/au $country...';
  }

  @override
  String get selectCityTitle => 'Choisir une ville';

  @override
  String get noCountriesFound => 'Aucun pays trouvé';

  @override
  String noCitiesFoundIn(String country) {
    return 'Aucune ville trouvée pour $country';
  }

  @override
  String get selectCountryCode => 'Choisir l\'indicatif du pays';

  @override
  String get errLoadTravelersRetry =>
      'Impossible de charger les voyageurs. Veuillez réessayer.';

  @override
  String get anywhere => 'N\'importe où';

  @override
  String byDate(String date) {
    return 'avant le $date';
  }

  @override
  String get noTravelersOnRouteTitle =>
      'Aucun voyageur sur ce trajet pour l\'instant';

  @override
  String get tryAnotherDateOrRoute =>
      'Essayez une autre date ou un autre trajet, ou activez les alertes ci-dessous.';

  @override
  String get travelersFound => 'Voyageurs trouvés';

  @override
  String get notifyNewTravelers =>
      'Soyez averti dès que de nouveaux voyageurs ajoutent des trajets sur cette route.';

  @override
  String get capacityNotSpecified => 'Capacité non précisée';

  @override
  String acceptsUpToKg(String weight) {
    return 'Accepte jusqu\'à $weight kg';
  }

  @override
  String get arrivingIn => 'Arrivée à';

  @override
  String get departureDateTitle => 'Date de départ';

  @override
  String get arrivalDateTitle => 'Date d\'arrivée';

  @override
  String get errOpenFile => 'Impossible d\'ouvrir ce fichier.';

  @override
  String get errFileTooLarge => 'Ce fichier est trop volumineux (10 Mo max).';

  @override
  String get departureDetailsTitle => 'Détails du départ';

  @override
  String get arrivalDetailsTitle => 'Détails de l\'arrivée';

  @override
  String get departureCountryLabel => 'PAYS DE DÉPART';

  @override
  String get departureCityLabel => 'VILLE DE DÉPART';

  @override
  String get arrivalCountryLabel => 'PAYS D\'ARRIVÉE';

  @override
  String get arrivalCityLabel => 'VILLE D\'ARRIVÉE';

  @override
  String get receiptOnFile => 'Reçu enregistré';

  @override
  String get bookingRefHint => 'ex. X7KQ9R';

  @override
  String deliveriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livraisons',
      one: '1 livraison',
    );
    return '$_temp0';
  }

  @override
  String availableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count disponibles',
      one: '1 disponible',
    );
    return '$_temp0';
  }

  @override
  String deliveredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livrés',
      one: '1 livré',
    );
    return '$_temp0';
  }

  @override
  String flightsShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vols',
      one: '1 vol',
    );
    return '$_temp0';
  }

  @override
  String amountPerDelivery(String amount) {
    return '$amount / livraison';
  }

  @override
  String get countries180 => '180+ pays';

  @override
  String get errEnterPhone => 'Veuillez saisir votre numéro de téléphone.';

  @override
  String get errTooManyRequests =>
      'Trop de demandes. Veuillez patienter un instant.';

  @override
  String get errTooManyRequestsRetry =>
      'Trop de demandes. Patientez un instant puis réessayez.';

  @override
  String get errInvalidPhone =>
      'Numéro de téléphone invalide. Vérifiez-le et réessayez.';

  @override
  String get errSomethingWrong =>
      'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get errFillAllFields => 'Veuillez remplir tous les champs.';

  @override
  String get countryOfResidenceLabel => 'PAYS DE RÉSIDENCE';

  @override
  String get errVerificationFailed =>
      'La vérification a échoué. Veuillez réessayer.';

  @override
  String get errCodeExpired => 'Code expiré. Veuillez en demander un nouveau.';

  @override
  String get errOtpDisabled =>
      'La vérification par téléphone n\'est pas activée. Veuillez contacter le support.';

  @override
  String get errIncorrectCode => 'Code incorrect. Veuillez réessayer.';

  @override
  String get errTooManyAttempts =>
      'Trop de tentatives. Patientez avant de réessayer.';

  @override
  String get errNetwork => 'Erreur réseau. Vérifiez votre connexion.';

  @override
  String get errIncorrectOrExpiredCode =>
      'Code incorrect ou expiré. Veuillez réessayer.';

  @override
  String get enterVerificationCode => 'Saisissez le code de vérification';

  @override
  String get otpSentToPrefix => 'Nous avons envoyé un code à 6 chiffres au ';

  @override
  String get verifyCode => 'Vérifier le code';

  @override
  String get resendCodeInPrefix => 'Renvoyer le code dans ';

  @override
  String get resendCode => 'Renvoyer le code';

  @override
  String get otpNotReceived =>
      'Vous n\'avez pas reçu le code ? Vérifiez que votre numéro est correct et que vous avez du réseau.';

  @override
  String get verifyPhone => 'Vérifier le téléphone';

  @override
  String get errCaptureIdFirst =>
      'Veuillez d\'abord photographier ou importer votre pièce d\'identité.';

  @override
  String get errUploadFailed => 'L\'envoi a échoué. Veuillez réessayer.';

  @override
  String get uploadingEllipsis => 'Envoi en cours...';

  @override
  String get submitForVerification => 'Envoyer pour vérification';

  @override
  String get documentSelected => 'Document sélectionné';

  @override
  String errCameraDetail(String error) {
    return 'Erreur de caméra : $error';
  }

  @override
  String errFilePicker(String error) {
    return 'Erreur de sélection de fichier : $error';
  }

  @override
  String get verifiedLabel => 'Vérifié';

  @override
  String matchPercent(String percent) {
    return 'Correspondance $percent';
  }

  @override
  String get requestExpiresInPrefix => 'La demande expire dans ';

  @override
  String get escrowNotePart1 =>
      'Votre paiement est conservé en sécurité par Nata. Le voyageur n\'est payé ';

  @override
  String get escrowNotePart2 =>
      'qu\'après que votre destinataire a confirmé la livraison';

  @override
  String get escrowNotePart3 =>
      ' avec votre code secret à 4 chiffres ou une preuve photo.';

  @override
  String get itemPlain => 'Article';

  @override
  String get weightPlain => 'Poids';

  @override
  String get refundFullBold => 'Remboursement intégral à 100 %';

  @override
  String get refundFullRest =>
      'si le voyageur annule ou si l\'article n\'est pas livré.';

  @override
  String get cancelFeeBold => 'Frais d\'annulation de 10 %';

  @override
  String get cancelFeeRest =>
      'si vous annulez après l\'acceptation du voyageur, jusqu\'à la remise.';

  @override
  String get disputeWindowBold => '3 jours pour signaler un problème';

  @override
  String get disputeWindowRest =>
      'après la livraison ; le support traite chaque signalement.';

  @override
  String get reviewTagIntact => 'L\'article était intact';

  @override
  String get reviewTagOnTime => 'À l\'heure';

  @override
  String get reviewTagCommunicator => 'Très bonne communication';

  @override
  String get reviewTagRules => 'A respecté toutes les règles';

  @override
  String get reviewTagHandoff => 'Remise sans accroc';

  @override
  String get reviewTagAgain => 'Je referais appel à lui';

  @override
  String deliveredYourItem(String item, String date) {
    return 'A livré votre $item · $date';
  }

  @override
  String get expiryHint => 'MM/AA';

  @override
  String get profilePictureUpdated => 'Photo de profil mise à jour';

  @override
  String errUploadImage(String error) {
    return 'Échec de l\'envoi de l\'image : $error';
  }

  @override
  String get senderEscrowFunded => 'Expéditeur · Séquestre financé';

  @override
  String senderDeliveries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expéditeur · $count livraisons',
      one: 'Expéditeur · 1 livraison',
    );
    return '$_temp0';
  }

  @override
  String sealedPhotosAttached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos de l\'emballage scellé jointes',
      one: '1 photo de l\'emballage scellé jointe',
    );
    return '$_temp0';
  }

  @override
  String capturedAt(String place, String time) {
    return 'Prise à $place · $time';
  }

  @override
  String txDeliveryOf(String item) {
    return 'Livraison $item';
  }

  @override
  String txReleasedFromEscrow(String date) {
    return 'Libéré du séquestre · $date';
  }

  @override
  String get txEscrowHold => 'Fonds en séquestre';

  @override
  String txDeliveryRequest(String date) {
    return 'Demande de livraison · $date';
  }

  @override
  String priceEstimateNote(String currency) {
    return 'Ceci est une estimation en $currency au taux du jour. Le prix est fixé lorsque le voyageur accepte.';
  }

  @override
  String get estimateLabel => 'Estimation';

  @override
  String get errRateUnavailable =>
      'Le taux de change n\'est pas disponible pour le moment, le prix ne peut donc pas être fixé. Veuillez réessayer plus tard.';

  @override
  String get errRequestNotPending => 'Cette demande a déjà reçu une réponse.';

  @override
  String get chatLockedUntilPayment =>
      'Le chat se débloque une fois la livraison payée. Votre paiement reste en séquestre jusqu\'à la confirmation de la livraison.';

  @override
  String get chatMeetInPublicTitle => 'Retrouvez-vous dans un lieu public';

  @override
  String get chatMeetInPublicBody =>
      'Pour la récupération et la remise, retrouvez-vous toujours dans un lieu public et fréquenté, comme un aéroport, une gare ou un café. N\'allez jamais à une adresse privée.';

  @override
  String get chatClosedAfterDelivery =>
      'Livraison terminée. Cette discussion est fermée, mais vous pouvez toujours la lire.';

  @override
  String get hide => 'Masquer';

  @override
  String get messageLocked => 'Message';

  @override
  String get messageUnlocksAfterPayment =>
      'La messagerie se débloque après le paiement.';

  @override
  String get escrowFunded => 'Séquestre financé';

  @override
  String maxDims(String dims) {
    return 'Max $dims';
  }

  @override
  String get errRequestNotPayable => 'Cette demande ne peut plus être payée.';

  @override
  String get step1ValidateTicket => 'ÉTAPE 1 · VÉRIFIER LE BILLET D\'AVION';

  @override
  String get step2PaymentMethod => 'ÉTAPE 2 · CHOISIR LE MOYEN DE PAIEMENT';

  @override
  String get idMeetingTipTitle =>
      'Vérifiez sa pièce d\'identité à la rencontre.';

  @override
  String idMeetingTipBody(String name) {
    return 'Quand vous remettez l\'article, demandez à $name de montrer sa pièce d\'identité et vérifiez que le nom correspond au billet.';
  }

  @override
  String get ticketNotValidated => 'Non vérifié';

  @override
  String get ticketValidated => 'Vérifié';

  @override
  String ticketIntro(String name) {
    return '$name a importé son billet d\'avion pour ce trajet. Vérifiez qu\'il correspond au trajet et à la date avant de payer.';
  }

  @override
  String get viewFullTicket => 'Voir le billet complet';

  @override
  String get ticketPdf => 'Billet d\'avion (PDF)';

  @override
  String get ticketRoute => 'Trajet';

  @override
  String get ticketDeparture => 'Départ';

  @override
  String get ticketBookingRef => 'Référence de réservation';

  @override
  String get ticketTraveler => 'Voyageur';

  @override
  String get iCheckedTicket => 'J\'ai vérifié ce billet';

  @override
  String get errTicketLoad => 'Impossible de charger le billet.';

  @override
  String get noTicketUploaded =>
      'Le voyageur n\'a pas encore importé de billet pour ce trajet, le paiement reste donc bloqué.';

  @override
  String get validateToUnlock =>
      'Vérifiez le billet pour débloquer le paiement';

  @override
  String payAmountIntoEscrow(String amount) {
    return 'Payer $amount en séquestre';
  }

  @override
  String get requestExpiredPayment =>
      'Cette demande a expiré et ne peut plus être payée.';

  @override
  String hoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get idSharedWithSendersNote =>
      'Lorsque vous acceptez une demande, l\'expéditeur verra la photo de votre pièce d\'identité et votre nom vérifié, pour vérifier que vous correspondez à votre billet. Le reste de votre pièce d\'identité reste privé.';

  @override
  String get errTicketNameMismatch =>
      'Le nom sur ce billet ne correspond pas au nom de votre profil. Importez un billet à votre nom ou modifiez le nom de votre profil.';

  @override
  String errTicketDateMismatch(String date) {
    return 'Ce billet n\'est pas pour le $date. Vérifiez les dates du trajet ou importez le billet de ce vol.';
  }

  @override
  String get errTicketUnreadable =>
      'Impossible de lire ce billet. Importez une photo nette ou le PDF de votre carte d\'embarquement ou billet électronique.';

  @override
  String get checkingTicket => 'Vérification de votre billet…';

  @override
  String get noIncomingRequests =>
      'Aucune demande pour l\'instant. Elles apparaîtront ici lorsque des expéditeurs vous demanderont de transporter quelque chose.';

  @override
  String get senderAwaitingPayment => 'Expéditeur · Paiement en attente';

  @override
  String get senderItemWithYou => 'Expéditeur · Article avec vous';

  @override
  String get senderDelivered => 'Expéditeur · Livré';

  @override
  String get nextWaitPayment => 'Attendre le paiement de l\'expéditeur';

  @override
  String get nextPickUp => 'Récupérer l\'article';

  @override
  String get nextDeliver => 'Livrer et saisir le code';

  @override
  String get nextDone => 'Paiement versé';

  @override
  String get viewRequest => 'Voir la demande';

  @override
  String get requestAcceptedSnack =>
      'Demande acceptée. L\'expéditeur a 24 heures pour payer.';

  @override
  String get requestDeclinedSnack => 'Demande refusée.';

  @override
  String get declineTitle => 'Refuser cette demande ?';

  @override
  String get declineBody =>
      'L\'expéditeur sera informé que vous ne pouvez pas le transporter.';

  @override
  String get declineReasonHint => 'Raison (facultatif)';

  @override
  String get keepIt => 'Garder';

  @override
  String get errAcceptFailed =>
      'Impossible d\'accepter la demande. Veuillez réessayer.';

  @override
  String get errDeclineFailed =>
      'Impossible de refuser la demande. Veuillez réessayer.';

  @override
  String get requestDetailsTitle => 'Détails de la demande';

  @override
  String answerWithin(String time) {
    return 'Répondez sous $time';
  }

  @override
  String payDueWithin(String time) {
    return 'L\'expéditeur doit payer sous $time';
  }

  @override
  String get itemPhotosTitle => 'PHOTOS DE L\'ARTICLE SCELLÉ';

  @override
  String get recipientHiddenNote =>
      'Le nom et le téléphone du destinataire sont partagés une fois que vous acceptez.';

  @override
  String get senderVerifiedBadge => 'Vérifié';

  @override
  String get rateYourTraveler => 'Évaluez votre voyageur';

  @override
  String get deliveryCompleteLabel => 'LIVRAISON TERMINÉE';

  @override
  String get itemArrivedSafely => 'Votre article est bien arrivé';

  @override
  String get reviewHelpsOthers =>
      'Votre avis aide d\'autres expéditeurs à trouver des voyageurs de confiance.';

  @override
  String get overallRating => 'NOTE GLOBALE';

  @override
  String get tapStarToRate => 'Touchez une étoile pour noter';

  @override
  String get whatStoodOut => 'QU\'EST-CE QUI VOUS A MARQUÉ ?';

  @override
  String get tagCommunication => 'Très bonne communication';

  @override
  String get tagCareful => 'Soigneux avec l\'article';

  @override
  String get tagFlexiblePickup => 'Remise flexible';

  @override
  String get writtenReview => 'AVIS ÉCRIT';

  @override
  String get reviewHint =>
      'Racontez comment se sont passées la remise et la livraison. Restez respectueux et factuel.';

  @override
  String get reviewsFinal =>
      'Les avis ne peuvent plus être modifiés une fois publiés.';

  @override
  String reviewSharedNote(String name) {
    return 'Votre note est partagée avec $name après l\'envoi et ajoutée à son historique public de livraisons.';
  }

  @override
  String reviewThanksName(String name) {
    return 'Merci d\'avoir évalué $name. Votre avis aide la communauté à rester fiable et sûre.';
  }

  @override
  String get errReviewFailed =>
      'Impossible d\'envoyer votre avis. Veuillez réessayer.';

  @override
  String get errAlreadyReviewed => 'Vous avez déjà évalué cette livraison.';

  @override
  String get errNotDelivered =>
      'Cet article n\'est pas encore marqué comme livré.';

  @override
  String get confirmReceipt => 'Confirmer la réception';

  @override
  String get youReviewed => 'Vous avez évalué cette livraison';

  @override
  String get errConfirmReceiptFailed =>
      'Impossible de confirmer la réception. Veuillez réessayer.';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avis',
      one: '1 avis',
    );
    return '$_temp0';
  }

  @override
  String get ticketImageHidden =>
      'Le billet n\'est pas affiché car sa référence de réservation n\'a pas pu être masquée. Nata a vérifié le nom du voyageur et la date du voyage lors de son envoi.';

  @override
  String get bookingRefHidden =>
      'Masquée pour protéger la réservation du voyageur';

  @override
  String get completeYourPayment => 'Finalisez votre paiement';

  @override
  String get completeYourPaymentSub =>
      'Terminez le paiement sur la page Flutterwave. Cette page se met à jour toute seule dès que le paiement est passé.';

  @override
  String get openPaymentPage => 'Ouvrir la page de paiement';

  @override
  String get iPaidCheckNow => 'J\'ai payé, vérifier';

  @override
  String get chooseAnotherWayToPay => 'Choisir un autre moyen de paiement';

  @override
  String get paymentReceived =>
      'Paiement reçu. L\'argent est conservé en séquestre jusqu\'à la livraison.';

  @override
  String get paymentNotReceivedYet =>
      'Nous n\'avons pas encore reçu le paiement. Si vous venez de payer, cela peut prendre une minute.';

  @override
  String get errPaymentFailed =>
      'Le paiement n\'a pas abouti. Réessayez ou choisissez un autre moyen de paiement.';

  @override
  String get errPaymentStart =>
      'Impossible d\'ouvrir la page de paiement. Veuillez réessayer.';

  @override
  String get errPaymentsUnavailable =>
      'Les paiements ne sont pas disponibles pour le moment. Veuillez réessayer plus tard.';

  @override
  String get mobileMoneyCountry => 'Pays du mobile money';

  @override
  String get chooseCountry => 'Choisissez un pays';

  @override
  String mobileMoneyChargedAs(String local, String price) {
    return 'Débité dans la devise de votre portefeuille au taux du jour : $local. Le prix de la livraison reste $price.';
  }

  @override
  String get errMobileMoneyUnavailable =>
      'Le mobile money n\'est pas disponible pour ce pays. Choisissez un autre pays ou payez par carte.';

  @override
  String get errMobileMoneyOptions =>
      'Impossible de charger les pays du mobile money.';

  @override
  String get mobileMoneyNetwork => 'Réseau';

  @override
  String get mobileMoneyNumber => 'Numéro mobile money';

  @override
  String get mobileMoneyNumberNote =>
      'Vous validerez le paiement sur ce téléphone, sans page de paiement.';

  @override
  String get enterMobileNumberToPay => 'Saisissez votre numéro mobile money';

  @override
  String get approveOnPhone => 'Validez le paiement sur votre téléphone';

  @override
  String approveOnPhoneSub(String amount, String phone) {
    return 'Nous avons envoyé une demande de $amount au $phone. Saisissez votre code PIN dans la notification pour la valider. Cette page se met à jour toute seule.';
  }

  @override
  String get iApprovedCheckNow => 'J\'ai validé, vérifier';

  @override
  String get errPhoneRejected =>
      'Ce numéro ne peut pas être débité. Vérifiez le numéro et le réseau, ou choisissez un autre moyen de paiement.';

  @override
  String get errMobileAmountOutOfBounds =>
      'Ce montant dépasse ce que votre réseau de mobile money autorise, ou n\'atteint pas son minimum. Choisissez un autre moyen de paiement.';

  @override
  String get errMobileNetworkUnavailable =>
      'Votre réseau de mobile money ne répond pas pour le moment. Réessayez dans quelques minutes.';

  @override
  String get signInPromptTitle => 'Connectez-vous pour continuer';

  @override
  String get signInPromptBody =>
      'Créez un compte gratuit pour envoyer des objets avec des voyageurs, publier vos voyages et suivre vos livraisons.';

  @override
  String signInPromptTraveler(String name) {
    return 'Créez un compte gratuit pour voir le profil de $name et envoyer une demande de livraison.';
  }

  @override
  String get signInPromptAddTrip =>
      'Créez un compte gratuit pour publier votre voyage et gagner de l’argent en transportant des objets.';

  @override
  String get signInBenefitVerified => 'Uniquement des voyageurs vérifiés';

  @override
  String get signInBenefitEscrow => 'Paiement sécurisé jusqu’à la livraison';

  @override
  String get signInBenefitPhone =>
      'Inscription avec votre numéro en une minute';

  @override
  String get notNow => 'Plus tard';

  @override
  String get cameraOffTitle => 'L\'accès à l\'appareil photo est désactivé';

  @override
  String get cameraOffBody =>
      'Nata a besoin de votre appareil photo pour prendre cette photo. Activez l\'appareil photo pour Nata dans les Réglages de votre téléphone, puis revenez réessayer.';

  @override
  String get cameraOffPath => 'Réglages > Nata Delivery > Appareil photo';

  @override
  String get openSettings => 'Ouvrir les Réglages';

  @override
  String get verifyPromptTitle => 'Vérifiez d\'abord votre identité';

  @override
  String get verifyPendingTitle =>
      'Votre vérification d\'identité est en cours';

  @override
  String get verifyPendingBody =>
      'Vous pourrez publier des trajets et envoyer des demandes une fois votre pièce d\'identité approuvée. Nous vous préviendrons.';

  @override
  String get verifyMyIdentity => 'Vérifier mon identité';

  @override
  String get ok => 'OK';

  @override
  String get verifyToAddTrip =>
      'Seuls les voyageurs vérifiés peuvent publier des trajets. Cela prend quelques minutes : une photo de votre pièce d\'identité et un selfie.';

  @override
  String get verifyToSendRequest =>
      'Seuls les membres vérifiés peuvent envoyer des demandes de livraison. Cela prend quelques minutes : une photo de votre pièce d\'identité et un selfie.';

  @override
  String get errNotVerified =>
      'Vérifiez d\'abord votre identité : seuls les membres vérifiés peuvent faire cela.';

  @override
  String get errTripFull =>
      'Ce trajet a déjà 3 livraisons en cours. Une place se libère dès qu\'une est livrée.';

  @override
  String get errSenderOnTrip =>
      'Vous avez déjà une livraison en cours de cet expéditeur sur ce trajet.';

  @override
  String get continueBrowsing => 'Continuer la visite';

  @override
  String get sortByDate => 'Trier par date';

  @override
  String get sortEarliest => 'Plus tôt';

  @override
  String get sortLatest => 'Plus tard';

  @override
  String get sendWithTrustedTravelers =>
      'Envoyez avec des voyageurs de confiance';

  @override
  String get guestHeroBadge => 'Voyageurs vérifiés · Paiement sécurisé';

  @override
  String get guestHeroTitle =>
      'Envoyez vos colis à l\'étranger avec un voyageur qui s\'y rend déjà';

  @override
  String get guestHeroBody =>
      'Trouvez un voyageur de confiance qui va vers votre destination. Votre paiement est conservé en sécurité jusqu\'à ce que votre destinataire confirme la livraison.';

  @override
  String get createFreeAccount => 'Créer un compte gratuit';

  @override
  String get travelersGoingSoon => 'Voyageurs au départ prochainement';

  @override
  String get preview => 'Aperçu';

  @override
  String get howItWorks => 'Comment ça marche';

  @override
  String get howStep1Title => 'Cherchez';

  @override
  String get howStep1Body => 'un voyageur qui va vers votre destination.';

  @override
  String get howStep2Title => 'Payez en séquestre';

  @override
  String get howStep2Body => 'après avoir vérifié son billet.';

  @override
  String get howStep3Title => 'Le voyageur est payé';

  @override
  String get howStep3Body =>
      'une fois que votre destinataire confirme la livraison.';

  @override
  String get pickedUpItem => 'J\'ai récupéré l\'article';

  @override
  String pickedUpOn(String date) {
    return 'Récupéré le $date';
  }

  @override
  String get pickedUp => 'Récupéré';

  @override
  String get notYet => 'Pas encore';

  @override
  String get pickUpFirst =>
      'Indiquez d\'abord que vous avez récupéré l\'article.';

  @override
  String get errPickUpFailed =>
      'Impossible d\'indiquer la récupération. Veuillez réessayer.';

  @override
  String handoverCodeNote(String city) {
    return 'Retrouvez le destinataire à $city, remettez-lui l’article et demandez-lui le code de livraison.';
  }

  @override
  String wrongCodeAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count essais restants',
      one: '1 essai restant',
    );
    return 'Ce code n\'est pas le bon. $_temp0.';
  }

  @override
  String get codeLocked =>
      'Trop de codes erronés. Contactez le support pour débloquer cette livraison.';

  @override
  String get codeNotReady =>
      'L\'expéditeur n\'avait pas encore de code. Demandez-lui de partager celui qui apparaît maintenant dans son application.';

  @override
  String deliveredPayoutQueued(String amount) {
    return 'Livré ! Votre paiement de $amount est en route.';
  }

  @override
  String get deliveryCode => 'Code de livraison';

  @override
  String deliveryCodeNote(String name) {
    return 'Donnez ce code à $name. Le voyageur en a besoin pour confirmer la livraison.';
  }

  @override
  String textCodeTo(String name) {
    return 'L’envoyer par SMS à $name';
  }

  @override
  String get codeTextedResend => 'Envoyé par SMS · Renvoyer';

  @override
  String codeTexted(String name) {
    return 'Code envoyé à $name par SMS.';
  }

  @override
  String get errSmsUnavailable =>
      'L\'envoi de SMS n\'est pas disponible pour le moment. Communiquez le code au destinataire vous-même.';

  @override
  String get errSmsTooSoon =>
      'Le code vient d’être envoyé. Patientez quelques minutes avant de le renvoyer.';

  @override
  String get payoutCountry => 'Pays';

  @override
  String get bankAccount => 'Compte bancaire';

  @override
  String get bankLabel => 'Banque';

  @override
  String get providerLabel => 'Opérateur';

  @override
  String get chooseBank => 'Choisissez votre banque';

  @override
  String get chooseProvider => 'Choisissez votre opérateur';

  @override
  String get accountNumber => 'Numéro de compte';

  @override
  String get accountHolderName => 'Nom du titulaire';

  @override
  String get savePayoutAccount => 'Enregistrer le compte';

  @override
  String get payoutAccountNoteSecure =>
      'Votre numéro de compte complet est conservé en sécurité sur notre serveur et sert uniquement à vous payer. L’application n’affiche que ses 4 derniers chiffres.';

  @override
  String noPayoutOptions(String country) {
    return 'Nata ne peut pas encore payer vers $country.';
  }

  @override
  String get errLoadPayoutOptions =>
      'Impossible de charger les banques de ce pays.';

  @override
  String get errPayoutAccountInvalid =>
      'Vérifiez le numéro de compte et le nom du titulaire.';

  @override
  String get errPayoutNotSupported =>
      'Cette banque ne peut pas encore recevoir de paiements. Choisissez-en une autre.';

  @override
  String get payoutCountryNote =>
      'Votre pays de résidence. Les paiements sont envoyés sur un compte dans ce pays.';

  @override
  String get errPayoutCountryMismatch =>
      'Le compte de paiement doit être dans votre pays de résidence.';

  @override
  String get errSavePayoutAccount =>
      'Impossible d\'enregistrer le compte. Veuillez réessayer.';

  @override
  String get payoutAccountSaved => 'Compte de versement enregistré.';

  @override
  String withdrawSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paiements sont en route.',
      one: 'Votre paiement est en route.',
    );
    return '$_temp0';
  }

  @override
  String get withdrawNothing =>
      'Rien à envoyer pour le moment. Si vous attendez un paiement, vérifiez que vous avez un compte de versement dans Paramètres de paiement.';

  @override
  String get backToProfile => 'Retour au profil';

  @override
  String get idStatusVerifiedTitle => 'Votre identité est vérifiée';

  @override
  String get idStatusVerifiedBody =>
      'Les expéditeurs et les voyageurs voient que vous êtes vérifié. Les détails de votre pièce d’identité ne sont jamais montrés aux autres utilisateurs.';

  @override
  String get idStatusReviewTitle => 'Nous vérifions votre pièce d’identité';

  @override
  String get idStatusReviewBody =>
      'Cela prend généralement moins de 24 heures. Vous pouvez parcourir l’app en attendant, mais pas encore envoyer ni accepter de demandes.';

  @override
  String get idStatusDocument => 'Pièce d’identité';

  @override
  String get idStatusFaceMatch => 'Reconnaissance faciale';

  @override
  String get idStatusVerifiedOn => 'Vérifiée le';

  @override
  String get idStatusSubmittedOn => 'Envoyée le';

  @override
  String get idStatusPassed => 'Réussie';

  @override
  String get idStatusInReview => 'En cours';

  @override
  String get idStatusReceived => 'Reçue';

  @override
  String get idStatusPrivacy =>
      'Seuls votre photo et votre prénom apparaissent sur votre profil.';

  @override
  String get idDocPassport => 'Passeport';

  @override
  String get idDocDriversLicense => 'Permis de conduire';

  @override
  String get idDocNationalId => 'Carte d’identité';

  @override
  String get walletHistory => 'Historique du portefeuille';

  @override
  String get walletAvailable => 'Disponible';

  @override
  String get walletInEscrow => 'En séquestre';

  @override
  String get walletFilterAll => 'Tout';

  @override
  String get walletFilterPayouts => 'Versements';

  @override
  String get walletFilterPayments => 'Paiements';

  @override
  String walletPayoutTitle(String item) {
    return 'Versement · $item';
  }

  @override
  String walletPaymentTitle(String item) {
    return 'Paiement · $item';
  }

  @override
  String get walletPayoutFallback => 'Versement';

  @override
  String get walletPaymentFallback => 'Paiement';

  @override
  String walletPaymentTo(String name) {
    return 'Demande de livraison à $name';
  }

  @override
  String get walletStatusPending => 'En attente';

  @override
  String get walletStatusSending => 'En cours d’envoi';

  @override
  String get walletStatusPaid => 'Versé';

  @override
  String get walletStatusFailed => 'Échec · nouvel essai';

  @override
  String get walletStatusInEscrow => 'En séquestre';

  @override
  String get walletStatusReleased => 'Libéré';

  @override
  String get walletStatusRefunded => 'Remboursé';

  @override
  String get walletEmpty =>
      'Aucune transaction pour l’instant. Vos paiements et versements apparaîtront ici.';

  @override
  String get errWalletHistory => 'Impossible de charger votre historique.';

  @override
  String get sbpTitle => 'Pourquoi les objets voyagent scellés';

  @override
  String get sbpBody =>
      'Chaque objet doit être dans sa boîte d’origine, scellée en usine. Cela protège les voyageurs à la douane et les expéditeurs en cas de litige.';

  @override
  String get sbpRule1 => 'Emballage d’origine, jamais ouvert';

  @override
  String get sbpRule2 => 'Montré en photo avant la demande';

  @override
  String get sbpRule3 =>
      'Le voyageur vérifie le scellé à la remise et peut refuser une boîte ouverte';

  @override
  String get sbpRule4 =>
      'Objets interdits : argent liquide, médicaments sans ordonnance, batteries de plus de 100 Wh, liquides de plus de 100 ml, tout ce qui est illégal à destination';

  @override
  String get sbpCustoms =>
      'Si la douane ouvre la boîte, le voyageur n’est pas responsable de l’objet.';

  @override
  String get ecScreenBody =>
      'Une personne à joindre en cas de problème pendant une livraison. Jamais montrée aux autres utilisateurs.';

  @override
  String get ecSaveContact => 'Enregistrer le contact';

  @override
  String get ecSavedToast => 'Contact d’urgence enregistré.';

  @override
  String get ecProfileAdd => 'Ajoutez une personne à joindre';

  @override
  String get errLoadContact => 'Impossible de charger votre contact d’urgence.';

  @override
  String get notifRequestNewTitle => 'Nouvelle demande de livraison';

  @override
  String notifRequestNewBody(String name, String route) {
    return '$name souhaite que vous transportiez un objet sur $route.';
  }

  @override
  String get notifAcceptedTitle => 'Demande acceptée';

  @override
  String notifAcceptedBody(String name) {
    return '$name a accepté votre demande. Payez dans les 24 heures pour la confirmer.';
  }

  @override
  String get notifDeclinedTitle => 'Demande refusée';

  @override
  String notifDeclinedBody(String name, String route) {
    return '$name ne peut pas prendre votre objet. Trouvez un autre voyageur sur $route.';
  }

  @override
  String get notifExpiredTitle => 'Demande expirée';

  @override
  String notifExpiredUnansweredBody(String name) {
    return '$name n’a pas répondu à temps. Trouvez un autre voyageur.';
  }

  @override
  String get notifExpiredUnpaidBody =>
      'Les 24 heures pour payer sont passées, la demande a été fermée.';

  @override
  String notifExpiredUnpaidTravelerBody(String name) {
    return '$name n’a pas payé à temps, la demande a été fermée.';
  }

  @override
  String get notifCancelledTitle => 'Demande annulée';

  @override
  String notifCancelledByTravelerBody(String name) {
    return '$name a annulé votre demande.';
  }

  @override
  String notifCancelledBySenderBody(String name, String route) {
    return '$name a annulé sa demande sur $route.';
  }

  @override
  String get notifPaidTitle => 'Paiement sécurisé';

  @override
  String notifPaidBody(String name) {
    return '$name a payé. L’argent est conservé en sécurité jusqu’à la livraison, et le chat est ouvert.';
  }

  @override
  String get notifPickedUpTitle => 'Objet récupéré';

  @override
  String notifPickedUpBody(String name) {
    return '$name a votre objet et est en route.';
  }

  @override
  String get notifDeliveredTitle => 'Objet livré';

  @override
  String notifDeliveredBody(String name) {
    return '$name a livré votre objet. Confirmez sa réception.';
  }

  @override
  String get notifPayoutTitle => 'Versement envoyé';

  @override
  String notifPayoutBody(String amount) {
    return 'Votre versement de $amount est en route.';
  }

  @override
  String get notifVerifiedTitle => 'Identité vérifiée';

  @override
  String get notifVerifiedBody =>
      'Vous êtes vérifié. Vous pouvez maintenant envoyer et accepter des demandes de livraison.';

  @override
  String get notifRejectedTitle => 'Vérification échouée';

  @override
  String get notifRejectedBody =>
      'Nous n’avons pas pu vérifier votre pièce d’identité. Réessayez avec une photo nette.';

  @override
  String crHeadline(String traveler, String recipient) {
    return '$traveler indique avoir livré votre objet à $recipient';
  }

  @override
  String crBody(String traveler) {
    return 'Vérifiez qu’il est bien arrivé. En confirmant, vous pourrez noter $traveler.';
  }

  @override
  String get crItem => 'Objet';

  @override
  String get crRoute => 'Trajet';

  @override
  String get crRecipient => 'Destinataire';

  @override
  String get crYes => 'Oui, il est arrivé';

  @override
  String get reportProblem => 'Signaler un problème';

  @override
  String get crReportNote => 'Vous pouvez signaler un problème pendant 3 jours';

  @override
  String get rpBody =>
      'Dites-nous ce qui s’est passé. Notre équipe d’assistance vous contactera.';

  @override
  String get rpReason => 'Que s’est-il passé ?';

  @override
  String get rpNotReceived => 'L’objet n’est pas arrivé';

  @override
  String get rpDamaged => 'Il est arrivé endommagé';

  @override
  String get rpWrongItem => 'Ce n’est pas l’objet que j’ai envoyé';

  @override
  String get rpOpened => 'La boîte a été ouverte';

  @override
  String get rpOther => 'Autre chose';

  @override
  String get rpDetails => 'Détails';

  @override
  String get rpDetailsHint => 'Ajoutez ce qui peut nous aider à comprendre';

  @override
  String get rpSend => 'Envoyer le signalement';

  @override
  String get rpSent =>
      'Merci. Nous avons reçu votre signalement et vous contacterons.';

  @override
  String get errAlreadyReported =>
      'Vous avez déjà signalé un problème pour cette livraison.';

  @override
  String get errReportWindowClosed =>
      'Le délai de 3 jours pour signaler un problème est passé.';

  @override
  String get notifProblemTitle => 'Problème signalé';

  @override
  String get notifProblemBody =>
      'Un problème a été signalé sur l’une de vos livraisons. Notre équipe d’assistance vous contactera.';

  @override
  String get notifTripMatchTitle => 'Un voyageur fait votre trajet';

  @override
  String notifTripMatchBody(String name, String route) {
    return '$name part $route. Confiez-lui votre article.';
  }

  @override
  String get routeAlerts => 'Alertes trajets';

  @override
  String get routeAlertsSub =>
      'Soyez averti quand un voyageur fait vos trajets';

  @override
  String get routeAlertsIntro =>
      'Enregistrez les trajets sur lesquels vous envoyez souvent. Quand un voyageur vérifié publie un voyage sur l\'un d\'eux, nous vous prévenons.';

  @override
  String get routeAlertsSaved => 'TRAJETS ENREGISTRÉS';

  @override
  String routeAlertsCount(int count) {
    return '$count sur 5';
  }

  @override
  String get routeAlertsAdd => 'Ajouter un trajet';

  @override
  String get routeAlertsMax => 'Jusqu\'à 5 trajets';

  @override
  String get routeAlertsEmptyTitle => 'Aucun trajet pour l\'instant';

  @override
  String get routeAlertsEmptyBody =>
      'Ajoutez vos trajets d\'envoi et nous vous dirons quand un voyageur les fait.';

  @override
  String get routeAlertsFrom => 'De';

  @override
  String get routeAlertsTo => 'À';

  @override
  String get routeAlertsChooseCity => 'Choisir une ville';

  @override
  String get routeAlertsSave => 'Enregistrer le trajet';

  @override
  String get routeAlertsRemove => 'Supprimer le trajet';

  @override
  String get routeAlertsSavedToast =>
      'Trajet enregistré. Nous vous préviendrons quand un voyageur le fait.';

  @override
  String get routeAlertsErrSame => 'Choisissez deux villes différentes.';

  @override
  String get routeAlertsErrLimit =>
      'Vous pouvez enregistrer jusqu\'à 5 trajets. Supprimez-en un pour en ajouter un autre.';

  @override
  String get routeAlertsErrExists => 'Vous avez déjà ce trajet.';

  @override
  String get routeAlertsErrFailed =>
      'Impossible d\'enregistrer le trajet. Réessayez.';

  @override
  String get routeAlertsLoadFailed => 'Impossible de charger vos trajets.';

  @override
  String get routeAlertsNotifyAbout => 'M\'avertir pour';

  @override
  String routeAlertsTravelers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs',
      one: '1 voyageur',
    );
    return '$_temp0';
  }

  @override
  String get routeAlertsAll => 'Tous';

  @override
  String routeAlertsStopAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs',
      one: '1 voyageur',
    );
    return 'Nous arrêtons après $_temp0. Vous pouvez relancer quand vous voulez.';
  }

  @override
  String get routeAlertsEveryTravelerNote =>
      'Nous vous avertirons pour chaque voyageur sur ce trajet.';

  @override
  String get routeAlertsEveryTraveler => 'Chaque voyageur';

  @override
  String routeAlertsProgress(int sent, int max) {
    return '$sent voyageurs trouvés sur $max';
  }

  @override
  String routeAlertsDone(int sent, int max) {
    return 'Terminé · $sent voyageurs trouvés sur $max';
  }

  @override
  String get routeAlertsRestart => 'Relancer';

  @override
  String get routeAlertsRestarted =>
      'Relancé. Nous vous avertirons pour les prochains voyageurs.';

  @override
  String get routeAlertsErrRestart =>
      'Impossible de relancer ce trajet. Réessayez.';

  @override
  String get homeGetStarted => 'Pour commencer';

  @override
  String get homeVerifyTitle => 'Vérifiez votre identité';

  @override
  String get homeVerifyBody =>
      '2 minutes suffisent. Nécessaire pour envoyer ou transporter des articles.';

  @override
  String get homeVerifyAction => 'Vérifier';

  @override
  String get homeRoutesTitle => 'Alertes pour vos trajets';

  @override
  String get homeRoutesBody =>
      'Nous vous prévenons quand un voyageur fait vos trajets d\'envoi.';

  @override
  String get homeRoutesAction => 'Ajouter un trajet';

  @override
  String get homeFaceIdTitle => 'Connexion avec Face ID';

  @override
  String get homeFaceIdBody =>
      'La prochaine fois, votre visage vous connecte. Pas besoin de code.';

  @override
  String get homeFaceIdAction => 'Activer Face ID';

  @override
  String get faceIdEnableReason =>
      'Confirmez que c\'est vous pour activer Face ID';

  @override
  String get faceIdTurnedOn =>
      'Face ID est activé. La prochaine fois, votre visage vous connecte.';

  @override
  String get faceIdEnableFailed => 'Face ID ne vous a pas reconnu. Réessayez.';

  @override
  String get nameEditTooltip => 'Modifier le nom';

  @override
  String get nameEditTitle => 'Modifier votre nom';

  @override
  String get nameEditHelper =>
      'Indiquez votre nom exactement comme sur votre pièce d\'identité. Il ne pourra plus être modifié une fois votre identité vérifiée.';

  @override
  String get nameSave => 'Enregistrer';

  @override
  String get nameErrEmpty => 'Saisissez votre prénom et votre nom.';

  @override
  String get nameErrLocked =>
      'Votre nom ne peut plus être modifié, la vérification de votre identité a commencé.';

  @override
  String get nameErrFailed => 'Impossible d\'enregistrer votre nom. Réessayez.';

  @override
  String get nameLockedTitle =>
      'Votre nom correspond à votre pièce d\'identité';

  @override
  String get nameLockedBody =>
      'Votre nom a été vérifié avec votre pièce d\'identité, il ne peut donc pas être modifié dans l\'application. S\'il est incorrect ou a changé légalement, notre équipe d\'assistance peut le mettre à jour.';

  @override
  String get nameContactSupport => 'Contacter l\'assistance';

  @override
  String get nameSupportSubject => 'Demande de changement de nom';

  @override
  String get nameUpdated => 'Nom mis à jour.';

  @override
  String notifMessageTitle(String name) {
    return 'Nouveau message de $name';
  }

  @override
  String notifMessageBody(String message) {
    return '$message';
  }

  @override
  String get notifMessagePhotoBody => 'Vous a envoyé une photo';

  @override
  String get chatTyping => 'écrit…';

  @override
  String get pickupPhotoHint =>
      'Prenez une photo de la boîte scellée au moment de la récupérer.';

  @override
  String get errPhotoUpload => 'Impossible d’envoyer la photo. Réessayez.';

  @override
  String get notifRefundTitle => 'Remboursement envoyé';

  @override
  String notifRefundBody(String amount) {
    return 'Votre remboursement de $amount est en route.';
  }

  @override
  String get viewCode => 'Voir le code';

  @override
  String get chatCodeNote =>
      'Votre destinataire donne ce code au voyageur lors de la remise. Ne le partagez pas avant.';

  @override
  String get close => 'Fermer';

  @override
  String get supportTitle => 'Support';

  @override
  String get supportSubtitle =>
      'Équipe Nata · Signalements, blocages et paiements échoués';

  @override
  String get supportProblemsCard => 'Problèmes signalés';

  @override
  String get supportOpenSuffix => 'ouverts';

  @override
  String get supportProblemsLine => 'En attente d\'une décision';

  @override
  String get supportLockedCard => 'Livraisons bloquées';

  @override
  String get supportLockedSuffix => 'bloquées';

  @override
  String get supportLockedLine => 'Bloquées après 5 codes de livraison erronés';

  @override
  String get supportFailedCard => 'Paiements échoués';

  @override
  String get supportFailedSuffix => 'échoués';

  @override
  String get supportFailedLine =>
      'Versements et remboursements échoués à relancer';

  @override
  String get supportRecentActivity => 'Activité récente';

  @override
  String get supportNoActivity => 'Aucune action du support pour l\'instant.';

  @override
  String get supportActResolved => 'Problème résolu';

  @override
  String get supportActRefunded => 'Expéditeur remboursé';

  @override
  String get supportActPayoutRetried => 'Versement relancé';

  @override
  String get supportActRefundRetried => 'Remboursement relancé';

  @override
  String get supportActUnlocked => 'Livraison débloquée';

  @override
  String get supportProblemsTitle => 'Problèmes signalés';

  @override
  String get supportOpen => 'Ouverts';

  @override
  String get supportResolved => 'Résolus';

  @override
  String get supportReportedBySender => 'Signalé par l\'expéditeur';

  @override
  String get supportReportedByTraveler => 'Signalé par le voyageur';

  @override
  String get supportInEscrow => 'En séquestre';

  @override
  String get supportViewDetails => 'Voir les détails';

  @override
  String get supportNoProblems => 'Aucun problème ici.';

  @override
  String get supportProblemDetail => 'Détail du problème';

  @override
  String get supportReporterDetails => 'Détails du signalement';

  @override
  String get supportNoDetails => 'Aucun détail donné.';

  @override
  String get supportPeople => 'Personnes';

  @override
  String get supportSender => 'Expéditeur';

  @override
  String get supportTraveler => 'Voyageur';

  @override
  String get supportTimeline => 'Chronologie de la livraison';

  @override
  String get supportPaid => 'Payé';

  @override
  String get supportPickedUp => 'Récupéré';

  @override
  String get supportDelivered => 'Livré';

  @override
  String get supportReported => 'Signalé';

  @override
  String get supportPaymentStatus => 'État du paiement';

  @override
  String get supportHeld => 'Retenu';

  @override
  String supportHeldLine(String amount) {
    return '$amount retenus en séquestre';
  }

  @override
  String get supportHeldSub => 'Pas versé avant la résolution';

  @override
  String get supportReleased => 'Versé';

  @override
  String supportReleasedLine(String amount) {
    return '$amount versés au voyageur';
  }

  @override
  String get supportRefunded => 'Remboursé';

  @override
  String supportRefundedLine(String amount) {
    return '$amount rendus à l\'expéditeur';
  }

  @override
  String get supportResolutionNote => 'Note de résolution';

  @override
  String get supportResolutionHint =>
      'Décrivez ce qui a été décidé et pourquoi…';

  @override
  String get supportMarkResolved => 'Marquer comme résolu';

  @override
  String get supportRefundSender => 'Rembourser l\'expéditeur';

  @override
  String supportRefundConfirmTitle(String amount, String name) {
    return 'Rembourser $amount à $name ?';
  }

  @override
  String get supportRefundConfirmBody =>
      'Le séquestre revient à l\'expéditeur et le voyageur n\'est pas payé. C\'est irréversible.';

  @override
  String get supportConfirmRefund => 'Confirmer le remboursement';

  @override
  String get supportResolvedSnack => 'Problème résolu.';

  @override
  String get supportRefundSnack =>
      'Remboursement en file. Il part dans les 15 minutes.';

  @override
  String get supportPaymentsTitle => 'Paiements et blocages';

  @override
  String get supportFailedTab => 'Paiements échoués';

  @override
  String get supportLockedTab => 'Livraisons bloquées';

  @override
  String get supportPayout => 'Versement';

  @override
  String get supportRefund => 'Remboursement';

  @override
  String get supportRefundRequeued =>
      'Remboursement remis en file. Il part dans les 15 minutes.';

  @override
  String get supportLocked => 'Bloquée';

  @override
  String get supportWrongAttempts => 'Codes erronés';

  @override
  String get supportUnlock => 'Débloquer la livraison';

  @override
  String get supportUnlockTitle => 'Débloquer cette livraison ?';

  @override
  String supportUnlockBody(String name) {
    return '$name aura 5 essais de plus pour le code de livraison. Vérifiez que le voyageur a l\'article avant de débloquer.';
  }

  @override
  String get supportConfirmUnlock => 'Confirmer le déblocage';

  @override
  String get supportUnlockedSnack => 'Livraison débloquée.';

  @override
  String get supportNothingFailed => 'Aucun paiement échoué.';

  @override
  String get supportNothingLocked => 'Aucune livraison bloquée.';

  @override
  String get supportRowSub =>
      'Équipe Nata · Signalements, blocages et paiements';

  @override
  String get supportAdmin => 'Admin';

  @override
  String get supportLoadFailed =>
      'Chargement impossible. Tirez vers le bas pour réessayer.';

  @override
  String get supportActionFailed => 'Ça n\'a pas marché. Réessayez.';

  @override
  String get deleteAccountRow => 'Supprimer le compte';

  @override
  String get deleteAccountRowSub =>
      'Supprimer définitivement votre compte Nata';

  @override
  String get daTitle => 'Supprimer votre compte ?';

  @override
  String get daBody => 'Cette action est irréversible.';

  @override
  String get daWhatWeDelete => 'Ce que nous supprimons';

  @override
  String get daDeleteProfile => 'Votre profil, nom et photo';

  @override
  String get daDeleteId => 'Vos pièces d’identité et votre selfie';

  @override
  String get daDeletePayment =>
      'Moyens de paiement et comptes de versement enregistrés';

  @override
  String get daDeleteMessages => 'Vos messages, trajets et demandes en cours';

  @override
  String get daDeleteNotifications => 'Notifications et appareils';

  @override
  String get daWhatWeKeep => 'Ce que nous conservons';

  @override
  String get daKeepPayments =>
      'Historique des paiements et versements, anonymisé';

  @override
  String get daKeepPaymentsSub => 'Nécessaire à la comptabilité';

  @override
  String get daKeepDeliveries => 'Livraisons terminées et avis';

  @override
  String get daKeepDeliveriesSub => 'Affichés comme « Utilisateur supprimé »';

  @override
  String get daUnderstand => 'Je comprends que c’est définitif';

  @override
  String get daConfirmButton => 'Supprimer mon compte';

  @override
  String get daFailed =>
      'Impossible de supprimer votre compte. Veuillez réessayer.';

  @override
  String get daLoadFailed => 'Impossible de vérifier votre compte.';

  @override
  String get daBlockedTitle =>
      'Vous ne pouvez pas encore supprimer votre compte';

  @override
  String get daBlockedBody =>
      'Terminez ou réglez d’abord ces points, puis réessayez.';

  @override
  String get daBlockedEscrow => 'Argent bloqué sous séquestre';

  @override
  String get daBlockedPayments => 'Versements ou remboursements en cours';

  @override
  String get daBlockedDeliveries => 'Livraisons en cours';

  @override
  String get daBlockedDisputes => 'Signalements de problème ouverts';

  @override
  String get daBlockedStaff =>
      'Les comptes du personnel sont supprimés par le support Nata';

  @override
  String get daNeedHelp => 'Besoin d’aide ? Contactez le support Nata.';

  @override
  String get tipSkip => 'Passer';

  @override
  String get tipNext => 'Suivant';

  @override
  String get tipGotIt => 'Compris';

  @override
  String get tipAddTripTitle => 'Vous avez un voyage prévu ?';

  @override
  String get tipAddTripBody =>
      'Ajoutez-le ici et soyez payé pour transporter des colis pour des personnes sur votre trajet.';

  @override
  String get tipSearchTitle => 'Besoin d’envoyer quelque chose ?';

  @override
  String get tipSearchBody =>
      'Choisissez le départ et la destination pour trouver des voyageurs sur ce trajet.';

  @override
  String get tipBellTitle => 'Vos notifications';

  @override
  String get tipBellBody =>
      'Les nouvelles demandes, les paiements et les livraisons s’affichent ici.';

  @override
  String get tipNavTitle => 'Tout au même endroit';

  @override
  String get tipNavBody =>
      'Suivez vos colis dans Demandes, vos voyages dans Trajets et discutez avec voyageurs et expéditeurs dans Messages.';

  @override
  String get tipRequestsTabsTitle => 'Sortantes et entrantes';

  @override
  String get tipRequestsTabsBody =>
      'Sortantes contient les colis que vous envoyez. Entrantes contient les demandes des expéditeurs sur vos voyages.';

  @override
  String get tipArchiveTitle => 'En cours et Archives';

  @override
  String get tipArchiveBody =>
      'Les demandes livrées, annulées et expirées passent dans les archives après 24 heures. Faites-en glisser une vers la gauche pour l’archiver tout de suite.';

  @override
  String get tipTripsAddTitle => 'Publier un voyage';

  @override
  String get tipTripsAddBody =>
      'Touchez + pour ajouter un voyage que vous faites déjà. Les expéditeurs sur votre trajet pourront vous demander de porter leurs colis.';

  @override
  String get tipTripsTabsTitle => 'À venir et passés';

  @override
  String get tipTripsTabsBody =>
      'Vos voyages à venir, et ceux que vous avez déjà faits.';

  @override
  String get tipChatSearchTitle => 'Trouver une discussion';

  @override
  String get tipChatSearchBody => 'Cherchez par nom, trajet ou article.';

  @override
  String get tipChatFiltersTitle => 'Quand les discussions s’ouvrent';

  @override
  String get tipChatFiltersBody =>
      'Une discussion s’ouvre quand l’expéditeur paie et se ferme après la livraison. Les discussions fermées restent ici sous Terminées, pour les relire.';

  @override
  String get tipWalletTitle => 'Votre portefeuille Nata';

  @override
  String get tipWalletBody =>
      'L’argent en séquestre et l’argent prêt à être retiré. Ce que vous gagnez en portant des colis s’affiche ici.';

  @override
  String get tipPayoutTitle => 'Être payé';

  @override
  String get tipPayoutBody =>
      'Ajoutez un compte bancaire ou mobile money dans Paramètres de paiement pour recevoir vos paiements.';

  @override
  String get tipRouteAlertsTitle => 'Alertes trajets';

  @override
  String get tipRouteAlertsBody =>
      'Enregistrez les trajets sur lesquels vous envoyez et soyez averti quand un voyageur les fait.';

  @override
  String get paidSecurelyThroughStripe =>
      'Paiement sécurisé par Stripe. Vos données de carte ne passent jamais par Nata.';

  @override
  String get confirmingPayment => 'Confirmation du paiement';

  @override
  String get confirmingPaymentSub =>
      'Paiement effectué. Nous le confirmons avec Stripe, cela prend quelques secondes.';

  @override
  String supportReasonSaid(String reason) {
    return 'Motif : « $reason »';
  }

  @override
  String get supportPayoutRequeued =>
      'Versement remis en file. Il part dans les 15 minutes.';

  @override
  String get stripePendingTitle => 'Stripe vérifie vos informations';

  @override
  String get stripePendingBody =>
      'Cela prend en général quelques minutes. Vos versements partent vers votre banque dès que Stripe l\'a validée.';

  @override
  String get stripeCheckAgain => 'Vérifier à nouveau';

  @override
  String get errStripeOpen =>
      'Impossible d\'ouvrir Stripe. Veuillez réessayer.';

  @override
  String get stripeEmailLabel => 'E-mail pour Stripe';

  @override
  String get stripeEmailNote =>
      'Stripe vous envoie ici les informations sur vos versements. Il n\'est montré à personne.';

  @override
  String get stripeEmailNeeded =>
      'Stripe a besoin de votre e-mail pour activer les versements. Saisissez-le ci-dessus.';

  @override
  String get stripeYourDetails => 'Vos informations';

  @override
  String get stripeDateOfBirth => 'Date de naissance';

  @override
  String get stripeHomeAddress => 'Adresse';

  @override
  String get stripeStreet => 'Rue et numéro';

  @override
  String get stripeCity => 'Ville';

  @override
  String get stripeState => 'État';

  @override
  String get stripeProvince => 'Province';

  @override
  String get stripeZip => 'Code ZIP';

  @override
  String get stripePostcode => 'Code postal';

  @override
  String get stripeIdentity => 'Identité';

  @override
  String get stripeSsnLast4 => '4 derniers chiffres de votre SSN';

  @override
  String get stripeSsnHelp =>
      'Stripe s\'en sert pour confirmer votre identité. Nata ne le conserve pas.';

  @override
  String get stripeBankAccount => 'Compte bancaire';

  @override
  String get stripeRoutingNumber => 'Numéro de routage (routing number)';

  @override
  String get stripeTransitNumber => 'Numéro de transit';

  @override
  String get stripeInstitutionNumber => 'Numéro d\'institution';

  @override
  String get stripeSortCode => 'Sort code';

  @override
  String get stripeIban => 'IBAN';

  @override
  String get stripeHolderNote => 'Le compte doit être à votre nom.';

  @override
  String get stripeAgreePrefix => 'J\'accepte le ';

  @override
  String get stripeAgreementName => 'Contrat de compte connecté Stripe';

  @override
  String get stripeSaveBank => 'Enregistrer le compte bancaire';

  @override
  String get stripeFormNote =>
      'Vos informations vont à Stripe, le partenaire de paiement de Nata. Nata ne garde que les 4 derniers chiffres de votre compte.';

  @override
  String get stripeFormIncomplete =>
      'Remplissez tous les champs et acceptez le contrat.';

  @override
  String get stripeMoreTitle => 'Stripe a besoin d\'un peu plus';

  @override
  String get stripeMoreBody =>
      'Pour terminer, Stripe a besoin d\'un élément que le formulaire de Nata ne demande pas, comme une photo de votre pièce d\'identité.';

  @override
  String get stripeFinish => 'Terminer avec Stripe';
}
