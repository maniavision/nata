// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Nata';

  @override
  String get splashTitle => 'Seleccionar idioma y moneda';

  @override
  String get splashSubtitle =>
      'Personaliza tu experiencia de entrega entre pares en todo el mundo.';

  @override
  String get splashWelcomePill => 'Welcome · Bienvenue · Bienvenido';

  @override
  String get splashDetectedRegion => 'REGIÓN DETECTADA';

  @override
  String get splashDetectedValue => 'Estados Unidos · Inglés y USD';

  @override
  String get splashQuickApply => 'Aplicar';

  @override
  String get splashChooseLanguage => 'ELEGIR IDIOMA';

  @override
  String get splashPreferredCurrency => 'MONEDA PREFERIDA';

  @override
  String get splashSaveAndContinue => 'Guardar y continuar';

  @override
  String get splashSettingsNote =>
      'Puedes cambiar tu idioma y moneda en Ajustes de perfil.';

  @override
  String splashAvailable(int count) {
    return '$count disponibles';
  }

  @override
  String get langEnglish => 'English';

  @override
  String get langEnglishSub => 'Predeterminado · Internacional';

  @override
  String get langSpanish => 'Español';

  @override
  String get langSpanishSub => 'Español · España y Latinoamérica';

  @override
  String get langFrench => 'Français';

  @override
  String get langFrenchSub => 'Francés · Francia y África';

  @override
  String get currUSD => 'Dólar estadounidense';

  @override
  String get currEUR => 'Euro';

  @override
  String get currGBP => 'Libra esterlina';

  @override
  String get currXOF => 'Franco CFA';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signUp => 'Registrarse';

  @override
  String get email => 'Correo o teléfono';

  @override
  String get password => 'Contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get rememberMe => 'Recordarme';

  @override
  String get faceId => 'Face ID';

  @override
  String get signInButton => 'Iniciar sesión';

  @override
  String get newToNata => '¿Nuevo en Nata?';

  @override
  String get createAccount => 'Crear una cuenta';

  @override
  String get tagline =>
      'Entregas entre pares · Red de viajeros verificados al 100%';

  @override
  String get welcomeBack => 'Bienvenido de nuevo';

  @override
  String get welcomeBackSub =>
      'Inicia sesión para gestionar entregas, rutas y solicitudes.';

  @override
  String get orWithEmail => 'o con correo electrónico';

  @override
  String get apple => 'Apple';

  @override
  String get google => 'Google';

  @override
  String get createYourAccount => 'Crea tu cuenta';

  @override
  String get createYourAccountSub =>
      'Envía artículos con viajeros verificados que van a tu destino.';

  @override
  String get firstName => 'Nombre';

  @override
  String get lastName => 'Apellido';

  @override
  String get emailAddress => 'Correo electrónico';

  @override
  String get phoneNumber => 'Número de teléfono';

  @override
  String get orSignUpManually => 'o regístrate manualmente';

  @override
  String get mandatoryIdTitle => 'Verificación de identidad obligatoria';

  @override
  String get mandatoryIdBody =>
      'Se solicitará una verificación de ID gubernamental y escaneo facial justo después del registro antes de realizar transacciones.';

  @override
  String get createAccountButton => 'Crear cuenta y continuar';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta?';

  @override
  String get signInHere => 'Inicia sesión aquí';

  @override
  String get goodMorning => 'BUENOS DÍAS';

  @override
  String get homeHero => 'Tu paquete ya está en camino.';

  @override
  String get homeSubtitle => 'Envíalo con alguien que va a tu destino';

  @override
  String get findATraveler => 'ENCONTRAR VIAJERO';

  @override
  String get trustedRoutes => 'Rutas confiables, usuarios verificados';

  @override
  String get deliverTo => 'ENTREGAR EN';

  @override
  String get whereIsItGoing => '¿Adónde va?';

  @override
  String get deliveryDate => 'FECHA DE ENTREGA';

  @override
  String get chooseADate => 'Elige una fecha';

  @override
  String get selectedDate => 'FECHA SELECCIONADA';

  @override
  String get searchTravelers => 'Buscar viajeros';

  @override
  String get sendAnItem => 'Enviar un artículo';

  @override
  String get addATrip => 'Agregar viaje';

  @override
  String get communityFavorites => 'FAVORITOS DE LA COMUNIDAD';

  @override
  String get activeTravelers => 'Viajeros activos';

  @override
  String get seeAll => 'Ver todos';

  @override
  String get recentRoutes => 'Rutas recientes';

  @override
  String get viewAll => 'Ver todos';

  @override
  String get sealedBoxPolicy => 'Política de caja sellada';

  @override
  String get sealedBoxPolicyBody =>
      'Los artículos siempre deben estar sellados en su caja comercial original para el cumplimiento aduanero y la seguridad en viajes.';

  @override
  String get available => 'Disponible';

  @override
  String get home => 'Inicio';

  @override
  String get requests => 'Solicitudes';

  @override
  String get messages => 'Mensajes';

  @override
  String get profile => 'Perfil';

  @override
  String get searchForTravelers => 'Buscar viajeros';

  @override
  String get reset => 'Restablecer';

  @override
  String get whereItemStartsFrom => '¿De dónde sale el artículo?';

  @override
  String get departureCountry => 'País de salida';

  @override
  String get departureCity => 'Ciudad de salida';

  @override
  String get whereItemNeedsToGo => '¿A dónde debe llegar el artículo?';

  @override
  String get destinationCountry => 'País de destino';

  @override
  String get destinationCity => 'Ciudad de destino';

  @override
  String get desiredDeliveryDate => 'Fecha de entrega deseada';

  @override
  String get flexibleDays => 'Flexible dentro de ±2 días';

  @override
  String get searchTravelersButton => 'Buscar viajeros';

  @override
  String get originalPackagingTitle => 'Requisito de embalaje original';

  @override
  String get originalPackagingBody =>
      'Los artículos deben estar sellados en su caja original. El precio se calcula automáticamente según el tamaño y peso.';

  @override
  String get recentSearches => 'BÚSQUEDAS RECIENTES';

  @override
  String get travelerResults => 'Resultados de viajeros';

  @override
  String get routeAndDate => 'RUTA Y FECHA DESEADA';

  @override
  String get aroundDate =>
      'Alrededor del 22 de junio, 2025 · 4 viajeros disponibles';

  @override
  String get edit => 'Editar';

  @override
  String get itemsDelivered => 'artículos';

  @override
  String get viewProfile => 'Ver perfil';

  @override
  String get needDifferentDate => '¿Necesitas otra fecha?';

  @override
  String get getNotified =>
      'Recibe una notificación cuando nuevos viajeros añadan viajes en esta ruta.';

  @override
  String get travelerProfile => 'Perfil del viajero';

  @override
  String get frequentTraveler => 'Viajero frecuente en la ruta LOS ⇄ LHR';

  @override
  String get itemsDeliveredStat => 'Artículos entregados';

  @override
  String get senderReviews => 'reseñas de remitentes';

  @override
  String get onTimeRate => 'Puntualidad';

  @override
  String get travelDateAndRoute => 'FECHA Y RUTA DE VIAJE';

  @override
  String get departure => 'Salida';

  @override
  String get destination => 'Destino';

  @override
  String get directFlight => 'Vuelo directo';

  @override
  String get pricingLabel => 'Precio:';

  @override
  String get pricingValue => 'Calculado por tamaño y peso del artículo';

  @override
  String get itemSizeAndWeight => 'LÍMITES DE TAMAÑO Y PESO ACEPTADOS';

  @override
  String get weightLimit => 'Límite de peso';

  @override
  String get sizeLimit => 'Límite de tamaño';

  @override
  String get checkBaggage => 'Espacio en equipaje facturado';

  @override
  String get maxDimensions => 'Máx. 30 × 20 × 15 cm';

  @override
  String get itemRequirement => 'Requisito del artículo';

  @override
  String get itemRequirementBody =>
      'Los artículos deben estar sellados en su caja original. Esto permite a los viajeros transportarlos con confianza y facilita los controles aduaneros.';

  @override
  String get deliveryHistoryAndReviews => 'HISTORIAL DE ENTREGAS Y RESEÑAS';

  @override
  String get sendRequest => 'Enviar solicitud';

  @override
  String get deliveryRequest => 'Solicitud de entrega';

  @override
  String get step1of1 => 'Paso 1 de 1';

  @override
  String get selectedTraveler => 'VIAJERO SELECCIONADO';

  @override
  String get whatIsTheItem => '¿Qué es el artículo?';

  @override
  String get itemCategory => 'Categoría del artículo';

  @override
  String get electronics => 'Electrónica';

  @override
  String get apparel => 'Ropa';

  @override
  String get documents => 'Documentos';

  @override
  String get itemDescription => 'Descripción del artículo';

  @override
  String get packageWeight => 'Peso del paquete';

  @override
  String get packageDimensions => 'Dimensiones del paquete';

  @override
  String get itemPhotos => 'Fotos del artículo (caja sellada)';

  @override
  String get photoAttached => 'foto adjunta';

  @override
  String get addPhoto => 'Añadir foto';

  @override
  String get calculatedPrice => 'Precio calculado del artículo';

  @override
  String get sendDeliveryRequest => 'Enviar solicitud de entrega';

  @override
  String get secureEscrowCheckout => 'Pago seguro con depósito en garantía';

  @override
  String get paymentWindowActive => 'VENTANA DE PAGO ACTIVA';

  @override
  String get requestExpires => 'La solicitud vence en';

  @override
  String get howEscrowWorks => 'Cómo funciona la protección de depósito';

  @override
  String get escrowBody =>
      'Tu pago es retenido de forma segura por Nata. El viajero solo recibe el pago después de que tu destinatario verifique la entrega con el código de 4 dígitos o foto.';

  @override
  String get selectPaymentMethod => 'SELECCIONAR MÉTODO DE PAGO';

  @override
  String get applePay => 'Apple Pay';

  @override
  String get applePaySub => 'Predeterminado · Rápido y seguro';

  @override
  String get creditCard => 'Tarjeta de crédito o débito';

  @override
  String get creditCardSub => 'Visa, Mastercard, Amex';

  @override
  String get mobileMoney => 'Dinero móvil';

  @override
  String get mobileMoneyPhoneSub => 'M-Pesa, MTN MoMo, Orange, Wave';

  @override
  String get paymentBreakdown => 'DESGLOSE DE PAGO';

  @override
  String get travelerReward => 'Recompensa del viajero';

  @override
  String get platformFee => 'Protección y comisión de garantía de Nata';

  @override
  String get totalEscrow => 'Total en depósito de garantía';

  @override
  String get payIntoEscrow => 'Pagar en depósito';

  @override
  String get cancellationTitle => 'Garantía de cancelación y reembolso';

  @override
  String get refundBullet1 =>
      'Reembolso total del 100% si el viajero cancela o el artículo no se entrega.';

  @override
  String get refundBullet2 =>
      'Cancelación gratuita en cualquier momento antes de la entrega física al viajero.';

  @override
  String get refundBullet3 =>
      'Ventana de disputa de 3 días después de la entrega antes de finalizar los fondos.';

  @override
  String get escrowEncrypted => 'Depósito cifrado de 256 bits por Nata Pay';

  @override
  String get deliveryRequests => 'Solicitudes de entrega';

  @override
  String get incoming => 'Entrantes';

  @override
  String get outgoing => 'Salientes';

  @override
  String get incomingSection => 'SOLICITUDES ENTRANTES (COMO VIAJERO)';

  @override
  String get pendingReview => 'pendientes de revisión';

  @override
  String get outgoingSection => 'SOLICITUDES SALIENTES (COMO REMITENTE)';

  @override
  String get total => 'total';

  @override
  String get sender => 'Remitente';

  @override
  String get successfulDeliveries => 'entregas exitosas';

  @override
  String get yourTrip => 'Tu viaje:';

  @override
  String get travelDate => 'Fecha de viaje:';

  @override
  String get item => 'Artículo:';

  @override
  String get weightAndSize => 'Peso y tamaño:';

  @override
  String get sealedPhotoAttached => 'foto de caja sellada adjunta';

  @override
  String get viewPhoto => 'Ver foto';

  @override
  String get viewPhotos => 'Ver fotos';

  @override
  String get decline => 'Rechazar';

  @override
  String get acceptRequest => 'Aceptar solicitud';

  @override
  String get pending => 'Pendiente';

  @override
  String get accepted => 'Aceptado';

  @override
  String get declined => 'Rechazado';

  @override
  String get payInTime => 'Pagar en';

  @override
  String get payEscrow => 'Pagar depósito';

  @override
  String get refundCredited => 'Reembolso acreditado al saldo';

  @override
  String get findAnotherTraveler => 'Buscar otro viajero';

  @override
  String get arrangeHandoff => 'Coordinar entrega por chat';

  @override
  String get messagesTitle => 'Mensajes';

  @override
  String get unreadUpdates => '3 actualizaciones no leídas';

  @override
  String get searchConversations => 'Buscar conversaciones o seguimiento...';

  @override
  String get allFilter => 'Todos (4)';

  @override
  String get activeDeliveries => 'Entregas activas (2)';

  @override
  String get completed => 'Completadas (1)';

  @override
  String get support => 'Soporte';

  @override
  String get accountAndProfile => 'Cuenta y perfil';

  @override
  String memberSince(String date) {
    return 'Miembro desde $date';
  }

  @override
  String get tripsCarried => 'VIAJES REALIZADOS';

  @override
  String get parcelsSent => 'PAQUETES ENVIADOS';

  @override
  String get natawallet => 'BILLETERA NATA';

  @override
  String get escrowProtected => 'Protegido con depósito';

  @override
  String get availableForPayout => 'Disponible para retiro';

  @override
  String get withdraw => 'Retirar';

  @override
  String get heldInEscrow => 'retenido en depósito';

  @override
  String get viewHistory => 'Ver historial';

  @override
  String get language => 'Idioma';

  @override
  String get currency => 'Moneda';

  @override
  String get identityVerification => 'Verificación de identidad';

  @override
  String get tier1Verified => 'Nivel 1 verificado · Pasaporte y biometría';

  @override
  String get sealedBoxPolicySetting => 'Política de caja sellada';

  @override
  String get originalBoxCompliance =>
      'Cumplimiento de seguridad de caja original';

  @override
  String get logOut => 'Cerrar sesión';

  @override
  String get addATripTitle => 'Añadir un viaje';

  @override
  String get clear => 'Borrar';

  @override
  String get travelerMode => 'MODO VIAJERO';

  @override
  String get headingSomewhere => '¿Vas a algún lugar pronto?';

  @override
  String get luggageEarnings =>
      'Convierte el espacio libre de tu equipaje en ingresos entregando paquetes sellados.';

  @override
  String get departureDetails => 'DETALLES DE SALIDA';

  @override
  String get from => 'Desde';

  @override
  String get arrivalDetails => 'DETALLES DE LLEGADA';

  @override
  String get to => 'Hasta';

  @override
  String get departureDate => 'FECHA DE SALIDA';

  @override
  String get arrivalDate => 'FECHA DE LLEGADA';

  @override
  String get flightTicket => 'RECIBO DE BOLETO DE VUELO';

  @override
  String get flightTicketSub =>
      'Sube una copia del recibo de tu reserva de vuelo para confirmar tu viaje';

  @override
  String get uploadFlightReceipt => 'Subir recibo de vuelo (PDF / Imagen)';

  @override
  String get replaceFlightReceipt =>
      'Reemplazar recibo de vuelo (PDF / Imagen)';

  @override
  String get luggageCapacity => 'CAPACIDAD DE EQUIPAJE QUE PUEDES LLEVAR';

  @override
  String get maxWeight => 'Peso máximo';

  @override
  String get maxItemSize => 'Tamaño máximo del artículo';

  @override
  String get howMatchingWorks => 'Cómo funciona la búsqueda';

  @override
  String get howMatchingBody =>
      'Una vez guardado, tu viaje aparecerá en los resultados de búsqueda para remitentes que buscan esta ruta y fecha.';

  @override
  String get saveAndPublish => 'Guardar y publicar viaje';

  @override
  String get confirmDelivery => 'Confirmar entrega';

  @override
  String get enter4DigitCode => 'Ingresa el código de 4 dígitos';

  @override
  String get recipientWillGive =>
      'Tu destinatario te dará este código al recibir el artículo.';

  @override
  String get codeEntered => 'Código ingresado — listo para confirmar';

  @override
  String get uploadHandoffPhoto => 'Subir foto de entrega';

  @override
  String get handoffPhotoSub =>
      'Toma una foto contigo y el destinatario, o del artículo siendo entregado.';

  @override
  String get confirmDeliveryButton => 'Confirmar entrega y liberar pago';

  @override
  String get disputeWindow =>
      'El pago se libera después de la ventana de disputa de 3 días';

  @override
  String get leaveAReview => 'Dejar una reseña';

  @override
  String get howWasExperience => '¿Cómo fue tu experiencia?';

  @override
  String get whatWentWell => '¿Qué salió bien?';

  @override
  String get leaveComment => 'Deja un comentario (opcional)';

  @override
  String get commentHint =>
      'Describe tu experiencia — esto ayuda a la comunidad...';

  @override
  String get submitReview => 'Enviar reseña';

  @override
  String get skipForNow => 'Omitir por ahora';

  @override
  String get reviewSubmitted => '¡Reseña enviada!';

  @override
  String get reviewThanks =>
      'Gracias por reseñar a Amara Kalu. Tu opinión ayuda a mantener la confianza de la comunidad.';

  @override
  String get returningHome => 'Volviendo al inicio...';

  @override
  String get ratingPoor => 'Malo — no era lo que esperaba';

  @override
  String get ratingFair => 'Regular — algunos problemas';

  @override
  String get ratingGood => 'Bueno — cumplió las expectativas';

  @override
  String get ratingGreat => 'Muy bueno — superó las expectativas';

  @override
  String get ratingExcellent => 'Excelente — lo recomendaría';

  @override
  String get identityVerificationTitle => 'Verificación de identidad';

  @override
  String get required => 'OBLIGATORIO';

  @override
  String get almostDone => 'CASI LISTO';

  @override
  String get cancel => 'Cancelar';

  @override
  String get step1of2 => 'Paso 1 de 2';

  @override
  String get step2of2 => 'Paso 2 de 2';

  @override
  String get skipForNowId => 'Omitir por ahora';

  @override
  String get actionRequired => 'Acción requerida antes de enviar';

  @override
  String get actionRequiredBody =>
      'Puedes explorar viajeros en cualquier momento, pero la verificación de identidad es obligatoria para enviar o aceptar solicitudes.';

  @override
  String get verifyIdentity => 'Verifica tu identidad';

  @override
  String get verifyIdentitySub =>
      'Completa 2 pasos rápidos para verificarte en menos de 2 minutos.';

  @override
  String get uploadOfficialId => 'Subir ID oficial';

  @override
  String get passportOrId =>
      'Pasaporte, Cédula nacional o Licencia de conducir';

  @override
  String get activeStep => 'Activo';

  @override
  String get nextStep => 'Siguiente';

  @override
  String get passportOption => 'Pasaporte';

  @override
  String get driversLicense => 'Lic. de conducir';

  @override
  String get nationalId => 'Cédula nacional';

  @override
  String get takePhotoOrUpload => 'Toma una foto o sube la página frontal';

  @override
  String get allCornersVisible =>
      'Asegúrate de que las 4 esquinas sean visibles sin reflejos';

  @override
  String get useCamera => 'Usar cámara';

  @override
  String get chooseFile => 'Elegir archivo';

  @override
  String get faceScan => 'Escaneo facial 3D';

  @override
  String get faceScanSub => 'Compara tu selfie en vivo con la foto de tu ID';

  @override
  String get scanIdToContinue => 'Escanear ID para continuar';

  @override
  String get biometricNote =>
      'Tus datos biométricos se procesan únicamente para la verificación de identidad.';

  @override
  String get step1Completed => 'Paso 1 completado';

  @override
  String get passportVerified =>
      'Documento de pasaporte verificado · Fortune Niama';

  @override
  String get editId => 'Editar ID';

  @override
  String get faceScanTitle => 'Escaneo biométrico facial 3D';

  @override
  String get faceScanBody =>
      'Centra tu rostro dentro del marco para verificar la vitalidad y confirmar la propiedad.';

  @override
  String get holdStill => 'Quédate quieto, mira directamente a la pantalla';

  @override
  String get nodHead =>
      'Asiente lentamente con la cabeza cuando el borde se vuelva verde.';

  @override
  String get goodLight => 'Buena luz';

  @override
  String get noGlasses => 'Sin gafas';

  @override
  String get neutralFace => 'Cara neutral';

  @override
  String get startBiometricScan => 'Iniciar escaneo biométrico';

  @override
  String get biometricLocalNote =>
      'Los escaneos faciales biométricos se procesan localmente para coincidir con tu pasaporte.';

  @override
  String get fullyVerified => '¡Estás completamente verificado!';

  @override
  String get fullyVerifiedSub =>
      'Tus documentos de identidad y escaneo biométrico han sido autenticados con éxito.';

  @override
  String get verificationReport => 'INFORME DE VERIFICACIÓN';

  @override
  String get instantApproval => 'Aprobación instantánea ✓';

  @override
  String get passportIdDoc => 'Documento de identidad (Pasaporte)';

  @override
  String get biometricLiveness => 'Vitalidad biométrica 3D';

  @override
  String get trustLimit => 'Límite de confianza y garantía';

  @override
  String get unlockedPerks => 'BENEFICIOS DE MIEMBRO DESBLOQUEADOS';

  @override
  String get perk1 => 'Publicar viajes ilimitados';

  @override
  String get perk2 => 'Liberación rápida de pagos';

  @override
  String get perk3 => 'Insignia de perfil verificado';

  @override
  String get perk4 => 'Prioridad en búsquedas';

  @override
  String get continueToHome => 'Continuar al inicio';

  @override
  String get viewPublicProfile => 'Ver perfil público';

  @override
  String get encrypted256 => 'Cifrado de 256 bits';

  @override
  String get instantAi => 'Verificación IA instantánea';

  @override
  String get gdprCompliant => 'Cumplimiento GDPR y KYC';

  @override
  String get trips => 'Viajes';

  @override
  String get identityActionRequiredSub =>
      'Acción requerida: verifica tu identidad';

  @override
  String get identityUnderReview =>
      'La verificación está actualmente en revisión';

  @override
  String get verificationReviewing => 'En revisión';

  @override
  String get ratingStat => 'Valoración';

  @override
  String get upcomingTrips => 'PRÓXIMOS VIAJES';

  @override
  String get newTravelerRating => 'Nuevo';

  @override
  String get upcomingTripsStat => 'Próximos viajes';

  @override
  String travelerOnRoute(String from, String to) {
    return 'Viajero en la ruta $from ⇄ $to';
  }

  @override
  String frequentTravelerOnRoute(String from, String to) {
    return 'Viajero frecuente en la ruta $from ⇄ $to';
  }

  @override
  String get noReviewsYet => 'Aún no hay reseñas';

  @override
  String get myTrips => 'Mis viajes';

  @override
  String get tabUpcoming => 'Próximos';

  @override
  String get tabPast => 'Pasados';

  @override
  String get tripPublished => 'Publicado';

  @override
  String get tripInReview => 'En revisión';

  @override
  String get tripCompleted => 'Completado';

  @override
  String get tripCancelled => 'Cancelado';

  @override
  String get editTrip => 'Editar viaje';

  @override
  String get viewRequests => 'Ver solicitudes';

  @override
  String get maxWeightLabel => 'Peso máx.';

  @override
  String get maxSizeLabel => 'Tamaño máx.';

  @override
  String get noUpcomingTrips => 'No hay viajes próximos';

  @override
  String get noPastTrips => 'Aún no hay viajes pasados';

  @override
  String get addTripPrompt =>
      'Añade un viaje para empezar a ganar con el espacio de tu equipaje.';

  @override
  String get tripInReviewNote =>
      'Estamos revisando tu viaje. Se publicará cuando sea aprobado.';

  @override
  String get couldNotLoadTrips => 'No se pudieron cargar tus viajes.';

  @override
  String get retry => 'Reintentar';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get tripSubmitted => 'Viaje enviado a revisión';

  @override
  String get tripUpdated => 'Viaje actualizado';

  @override
  String get selectCountry => 'Selecciona un país';

  @override
  String get selectCity => 'Selecciona una ciudad';

  @override
  String get selectDate => 'Selecciona una fecha';

  @override
  String get tripPrice => 'PRECIO POR ARTÍCULO';

  @override
  String get tripPriceHint => 'Tu tarifa por llevar un artículo';

  @override
  String get errPickDeparture => 'Elige desde dónde sales.';

  @override
  String get errPickArrival => 'Elige tu destino.';

  @override
  String get errSameCity =>
      'La salida y la llegada deben ser ciudades distintas.';

  @override
  String get errPickDepDate => 'Elige una fecha de salida.';

  @override
  String get errPickArrDate => 'Elige una fecha de llegada.';

  @override
  String get errArrivalBeforeDeparture =>
      'La llegada no puede ser anterior a la salida.';

  @override
  String get errAttachReceipt => 'Adjunta tu recibo de vuelo.';

  @override
  String get errPrice => 'Introduce un precio válido.';

  @override
  String get errSaveFailed =>
      'No se pudo guardar tu viaje. Inténtalo de nuevo.';

  @override
  String itemsDeliveredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos entregados',
      one: '1 artículo entregado',
    );
    return '$_temp0';
  }

  @override
  String get bookingReference => 'Referencia de reserva';

  @override
  String get bookingReferenceSub =>
      'Introduce el código de referencia de tu reserva de vuelo (PNR)';

  @override
  String get errBookingReference =>
      'La referencia de reserva debe tener de 5 a 8 letras o números.';

  @override
  String bookingReferenceShort(String code) {
    return 'Ref. $code';
  }

  @override
  String get verificationPending => 'Verificación pendiente';

  @override
  String get verificationUnverified => 'Sin verificar';

  @override
  String get takePhoto => 'Tomar foto';

  @override
  String get uploadFile => 'Subir archivo';

  @override
  String get errCamera => 'No se pudo abrir la cámara.';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get markAllRead => 'Marcar todo como leído';

  @override
  String get paymentsFilter => 'Pagos';

  @override
  String get notifToday => 'Hoy';

  @override
  String get notifEarlier => 'Anteriores';

  @override
  String get noNotifications => 'Aún no hay notificaciones';

  @override
  String get noNotificationsSub =>
      'Te avisaremos aquí cuando pase algo con tus viajes, solicitudes y pagos.';

  @override
  String get couldNotLoadNotifications =>
      'No se pudieron cargar tus notificaciones.';

  @override
  String get justNow => 'Ahora mismo';

  @override
  String get yesterdayLabel => 'Ayer';

  @override
  String minutesAgo(int count) {
    return 'hace $count min';
  }

  @override
  String hoursAgo(int count) {
    return 'hace $count h';
  }

  @override
  String get notifFilterAll => 'Todas';

  @override
  String get faceIdReason => 'Confirma que eres tú para iniciar sesión en Nata';

  @override
  String get faceIdSignInFirst =>
      'Para usar Face ID, inicia sesión primero con tu número de teléfono y deja marcado «Recordarme».';

  @override
  String get faceIdUnavailable =>
      'Face ID no está disponible en este dispositivo.';

  @override
  String get faceIdNotSetUp =>
      'Configura primero Face ID en los ajustes de tu dispositivo.';

  @override
  String get faceIdFailed =>
      'Face ID no te reconoció. Inténtalo de nuevo o inicia sesión con tu número de teléfono.';

  @override
  String get faceIdLocked =>
      'Face ID está bloqueado por ahora. Inicia sesión con tu número de teléfono.';

  @override
  String splashDetectedSummary(
    String country,
    String language,
    String currency,
  ) {
    return '$country · $language y $currency';
  }

  @override
  String get messagesCaughtUp => 'Todo al día';

  @override
  String get searchChats => 'Buscar por nombre, ruta o artículo';

  @override
  String get noConversations => 'Aún no hay conversaciones';

  @override
  String get noConversationsSub =>
      'Cuando envíes o recibas una solicitud de entrega, tu chat con el viajero o el remitente aparecerá aquí.';

  @override
  String get noChatMatches => 'Ninguna conversación coincide con tu búsqueda';

  @override
  String get couldNotLoadMessages => 'No se pudieron cargar tus mensajes.';

  @override
  String get couldNotLoadChat => 'No se pudo cargar este chat.';

  @override
  String get typeMessage => 'Escribe un mensaje…';

  @override
  String get msgSending => 'Enviando…';

  @override
  String get msgSent => 'Enviado ✓';

  @override
  String get msgRead => 'Leído ✓✓';

  @override
  String get msgFailed => 'No enviado · toca para reintentar';

  @override
  String get chatEmpty => 'Aún no hay mensajes. ¡Saluda!';

  @override
  String get chatPhotoLabel => 'Foto';

  @override
  String get chatChoosePhoto => 'Elegir de la galería';

  @override
  String get chatPhotoFailed => 'No se pudo enviar la foto.';

  @override
  String get chatCameraFailed => 'No se pudo abrir la cámara o las fotos.';

  @override
  String get chatPhotoLoadFailed => 'Foto no disponible';

  @override
  String unreadMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes sin leer',
      one: '1 mensaje sin leer',
    );
    return '$_temp0';
  }

  @override
  String filterAllCount(int count) {
    return 'Todas ($count)';
  }

  @override
  String filterActiveCount(int count) {
    return 'Activas ($count)';
  }

  @override
  String filterCompletedCount(int count) {
    return 'Completadas ($count)';
  }

  @override
  String chatYouPrefix(String text) {
    return 'Tú: $text';
  }
}
