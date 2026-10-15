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
  String get pricingValue =>
      'Calculado por distancia, tamaño y peso del artículo';

  @override
  String get sameDayDelivery => 'Entrega el mismo día';

  @override
  String deliverInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entrega en $count días',
      one: 'Entrega en 1 día',
    );
    return '$_temp0';
  }

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
  String get sendDeliveryRequest => 'Enviar solicitud';

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
      'Cancelar es gratis hasta que el viajero acepte. Después, se aplica una tarifa de cancelación del 10 % hasta la entrega.';

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
      'Tu selfie se compara con la foto de tu documento mediante nuestro servicio de verificación seguro y se guarda de forma privada.';

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

  @override
  String get recipientDetails => 'Datos del destinatario';

  @override
  String get recipientName => 'Nombre del destinatario';

  @override
  String get recipientNameHint => 'Nombre completo como en su documento';

  @override
  String get recipientPhone => 'Teléfono del destinatario';

  @override
  String get recipientPhoneHint => 'p. ej. +44 7700 900123';

  @override
  String get recipientPhoneNote =>
      'Se comparte con el viajero solo después de que acepte tu solicitud';

  @override
  String get sizeAndWeight => 'Tamaño y peso';

  @override
  String travelerLimitLabel(String limit) {
    return 'Límite del viajero: $limit';
  }

  @override
  String get itemNameHint =>
      'p. ej. auriculares Sony, cosméticos sellados, etc.';

  @override
  String get itemDescHint => 'Da detalles sobre el artículo y el embalaje...';

  @override
  String get weightHint => 'p. ej. 0,9 kg';

  @override
  String get dimensionsHint => 'p. ej. 24 × 24 × 8 cm';

  @override
  String get photoMustShowSeal => 'La foto debe mostrar el sello de fábrica';

  @override
  String get travelerPriceLine => 'Precio del viajero';

  @override
  String get platformProtectionLine =>
      'Protección de la plataforma y depósito en garantía';

  @override
  String get priceNoteNothingCharged =>
      'No se cobra nada ahora. El viajero puede aceptar o rechazar esta solicitud y solo pagas después de que acepte.';

  @override
  String get choosePhotoSource => 'Añadir una foto';

  @override
  String get errItemName => 'Indica qué es el artículo.';

  @override
  String get emergencyContactLabel => 'Contacto de emergencia';

  @override
  String get ecStepOf => 'Paso 2 de 2';

  @override
  String get ecTitle => 'Añade un contacto de emergencia';

  @override
  String get ecBody =>
      'Alguien a quien podamos contactar si algo sale mal durante una entrega.';

  @override
  String get ecFullName => 'Nombre completo';

  @override
  String get ecFullNameHint => 'Nombre completo del contacto';

  @override
  String get ecPhone => 'Número de teléfono';

  @override
  String get ecPhoneHint => 'p. ej. 7700 900123';

  @override
  String get ecRelationship => 'Relación';

  @override
  String get relFriend => 'Amigo/a';

  @override
  String get relRelative => 'Familiar';

  @override
  String get relPartner => 'Pareja';

  @override
  String get relColleague => 'Colega';

  @override
  String get ecPrivacy =>
      'Tu contacto de emergencia nunca se muestra a remitentes ni viajeros y solo lo usa nuestro equipo de soporte si no podemos contactarte.';

  @override
  String get ecFinish => 'Finalizar verificación';

  @override
  String get ecFootnote =>
      'Tus datos se guardan de forma segura y solo se usan por motivos de seguridad.';

  @override
  String get errContactName => 'Introduce el nombre completo del contacto.';

  @override
  String get errContactPhone =>
      'Introduce un número válido para el prefijo de país seleccionado.';

  @override
  String get errIdNotRecognized =>
      'Esto no parece un documento de identidad. Sube una foto clara de la página completa del documento.';

  @override
  String get errIdNoFace =>
      'No encontramos la foto del documento. Sube una imagen clara de la página donde aparece tu rostro.';

  @override
  String get errIdUnreadable =>
      'No pudimos leer el texto de este documento. Sube una foto nítida y bien iluminada del documento completo.';

  @override
  String get idTypePassport => 'pasaporte';

  @override
  String get idTypeDriversLicense => 'licencia de conducir';

  @override
  String get idTypeNationalId => 'documento nacional de identidad';

  @override
  String errIdWrongType(String document) {
    return 'Este documento no parece ser del tipo «$document». Elige el tipo correcto arriba o sube el documento adecuado.';
  }

  @override
  String get faceScanIntro =>
      'Te pediremos que parpadees y gires la cabeza; luego compararemos tu rostro con la foto de tu documento.';

  @override
  String get livenessNoFace => 'Coloca tu rostro dentro del óvalo';

  @override
  String get livenessMultipleFaces => 'Solo tú debes aparecer en la imagen';

  @override
  String get livenessBlink => 'Parpadea despacio';

  @override
  String get livenessTurnHead =>
      'Gira la cabeza a la izquierda y luego a la derecha';

  @override
  String get livenessLookStraight =>
      'Mira directamente a la cámara y no te muevas';

  @override
  String get faceScanVerifying => 'Comparando tu rostro con tu documento…';

  @override
  String get faceScanVerified => 'Rostro verificado. ¡Ya estás verificado!';

  @override
  String faceScanNoMatch(int count) {
    return 'Tu rostro no coincide con la foto de tu documento. Intentos restantes: $count.';
  }

  @override
  String faceScanNoFace(int count) {
    return 'No pudimos ver bien tu rostro. Inténtalo de nuevo con buena luz. Intentos restantes: $count.';
  }

  @override
  String get faceScanManualReview =>
      'No pudimos confirmar tu rostro automáticamente. Nuestro equipo revisará tu documento.';

  @override
  String get faceScanTimeout =>
      'Se acabó el tiempo. Asegúrate de tener buena luz e inténtalo de nuevo.';

  @override
  String get faceScanCameraDenied =>
      'Permite el acceso a la cámara en Ajustes para escanear tu rostro.';

  @override
  String get faceScanError => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get faceScanTryAgain => 'Intentar de nuevo';

  @override
  String get faceScanContinue => 'Continuar';

  @override
  String get faceScanSkip =>
      'Continuar sin verificación facial (revisión manual)';

  @override
  String get acceptedInProgress => 'Aceptadas y en curso';

  @override
  String activeCount(int count) {
    return '$count activa(s)';
  }

  @override
  String get yourPayout => 'Tu pago';

  @override
  String get tripLabel => 'Viaje:';

  @override
  String get nextAction => 'Siguiente paso:';

  @override
  String get attachReceivedPhoto => 'Adjuntar foto de recepción';

  @override
  String get manageDeliveryAttachProof => 'Gestionar entrega y adjuntar prueba';

  @override
  String pendingRequestsCount(int count) {
    return 'SOLICITUDES PENDIENTES ($count)';
  }

  @override
  String get awaitingYourResponse => 'Esperan tu respuesta';

  @override
  String get deliveryTaskDetails => 'Detalles de la entrega';

  @override
  String orderNumber(String id) {
    return 'Pedido #$id';
  }

  @override
  String get inProgress => 'En curso';

  @override
  String get senderVerifiedIdentity => 'Remitente · Identidad verificada';

  @override
  String get inEscrow => '(En depósito)';

  @override
  String get deliveryRoute => 'Ruta de entrega';

  @override
  String get itemToCarry => 'Artículo a llevar';

  @override
  String get itemReceivedFromSender => 'Artículo recibido del remitente';

  @override
  String get attached => 'Adjunta';

  @override
  String get itemReceivedNote =>
      'Comprueba que el producto está completamente sellado en su caja de fábrica antes de hacerte cargo.';

  @override
  String get retake => 'Repetir';

  @override
  String get itemDeliveredToRecipient => 'Artículo entregado al destinatario';

  @override
  String get pendingDelivery => 'Entrega pendiente';

  @override
  String handoverNote(String city) {
    return 'Adjunta una foto de la entrega al destinatario en $city para liberar al instante el pago en depósito.';
  }

  @override
  String get takeOrUploadHandoverPhoto => 'Tomar o subir foto de la entrega';

  @override
  String get handoverPhotoHint =>
      'Foto con el destinatario o en el lugar de entrega';

  @override
  String get handoverPhotoAttached => 'Foto de la entrega adjunta';

  @override
  String get recipientNameLabel => 'Nombre del destinatario:';

  @override
  String get recipientPhoneLabel => 'Teléfono del destinatario:';

  @override
  String get meetingSpotLabel => 'Punto de encuentro:';

  @override
  String confirmDeliveryClaim(String amount) {
    return 'Confirmar entrega y cobrar $amount';
  }

  @override
  String get escrowReleaseNote =>
      'Los fondos en depósito se liberarán de inmediato en tu billetera.';

  @override
  String get attachHandoverFirst => 'Primero adjunta la foto de la entrega.';

  @override
  String get recipientLocalPhoneHint => 'p. ej. 7700 900123';

  @override
  String get paymentSettings => 'Ajustes de pago';

  @override
  String get paymentSettingsSub => 'Métodos de pago y cuenta de cobro';

  @override
  String get paymentMethods => 'Métodos de pago';

  @override
  String get add => 'Añadir';

  @override
  String get remove => 'Eliminar';

  @override
  String get defaultLabel => 'Predeterminado';

  @override
  String get payoutAccount => 'Cuenta de cobro';

  @override
  String get payoutAccountNote =>
      'Las ganancias de las entregas completadas se transfieren a esta cuenta tras el plazo de reclamación de 3 días.';

  @override
  String get addPayoutAccount => 'Añadir cuenta de cobro';

  @override
  String get preferences => 'Preferencias';

  @override
  String get defaultCurrency => 'Moneda predeterminada';

  @override
  String get defaultCurrencySub => 'Para cobros y recibos';

  @override
  String get payoutSchedule => 'Calendario de cobros';

  @override
  String get payoutScheduleSub => 'Tras confirmarse la entrega';

  @override
  String get automatic => 'Automático';

  @override
  String get transactions => 'Transacciones';

  @override
  String get addPaymentMethod => 'Añadir método de pago';

  @override
  String get paymentSecurityNote =>
      'Tus datos de pago se cifran y se guardan de forma segura. Los pagos se retienen en depósito hasta que se confirma la entrega.';

  @override
  String get paymentKindCard => 'Tarjeta';

  @override
  String get paymentKindCardSub => 'Débito o crédito';

  @override
  String get paymentKindMobile => 'Dinero móvil';

  @override
  String get paymentKindAppleSub => 'Pago rápido';

  @override
  String get cardDetails => 'Datos de la tarjeta';

  @override
  String get nameOnCard => 'Nombre en la tarjeta';

  @override
  String get nameOnCardHint => 'Nombre completo como en la tarjeta';

  @override
  String get cardNumber => 'Número de tarjeta';

  @override
  String get expiryDate => 'Caducidad';

  @override
  String get mobileMoneyDetails => 'Datos de dinero móvil';

  @override
  String get provider => 'Proveedor';

  @override
  String get mobileNumber => 'Número móvil';

  @override
  String get registeredName => 'Nombre registrado';

  @override
  String get registeredNameHint => 'Nombre registrado con el proveedor';

  @override
  String get applePayNote =>
      'Apple Pay se vinculará a la cartera de tu Apple ID. Lo confirmarás con Face ID en tu dispositivo.';

  @override
  String get setAsDefault => 'Usar como predeterminado';

  @override
  String get setAsDefaultSub => 'Usar este método en futuras solicitudes';

  @override
  String get savePaymentMethod => 'Guardar método de pago';

  @override
  String get errCardName =>
      'Introduce el nombre tal como aparece en la tarjeta.';

  @override
  String get errCardNumber => 'Introduce un número de tarjeta válido.';

  @override
  String get errCardExpiry =>
      'Introduce una fecha de caducidad válida (MM/AA).';

  @override
  String get errCardCvv => 'Introduce el código de seguridad de 3 o 4 dígitos.';

  @override
  String get errMobileNumber =>
      'Introduce el número móvil con el prefijo del país, p. ej. +254 712 345 678.';

  @override
  String get errRegisteredName =>
      'Introduce el nombre registrado con el proveedor.';

  @override
  String cardExpires(String date) {
    return 'Caduca $date';
  }

  @override
  String holdersIphone(String name) {
    return 'iPhone de $name';
  }

  @override
  String get errPaymentSettingsLoad =>
      'No se pudieron cargar tus ajustes de pago. Inténtalo de nuevo.';

  @override
  String get errPaymentSettingsSave =>
      'No se pudo guardar el cambio. Inténtalo de nuevo.';

  @override
  String get noPaymentMethods =>
      'Aún no hay ningún método de pago. Añade uno para pagar las solicitudes de entrega.';

  @override
  String get noPayoutAccount => 'Aún no hay cuenta de cobro.';

  @override
  String get weekly => 'Semanal';

  @override
  String get manual => 'Manual';

  @override
  String get faceScanLivenessNote =>
      'La IA biométrica comprueba en tiempo real que estás presente para confirmar que eres el titular del documento.';

  @override
  String get deliveryPayoutRelease => 'Entrega y liberación del pago';

  @override
  String get confirmDeliveryStep => 'Paso 3 de 4: Confirmar la entrega';

  @override
  String get itemArrivedAtDestination => 'El artículo llegó a destino';

  @override
  String get confirmHandoffNote =>
      'Confirma la entrega al destinatario con el PIN de 4 dígitos o subiendo una foto del artículo sellado entregado.';

  @override
  String get pinOptionTitle => 'Opción 1: PIN de entrega de 4 dígitos';

  @override
  String get instantRelease => 'Liberación inmediata';

  @override
  String get pinOptionNote =>
      'El remitente dio al destinatario un código secreto de 4 dígitos. Introdúcelo:';

  @override
  String get pinConfirmed => 'PIN del destinatario confirmado';

  @override
  String get pinMismatch =>
      'Este PIN no coincide con el código del destinatario.';

  @override
  String get photoOptionTitle => 'Opción 2: Foto de la entrega';

  @override
  String get alternative => 'Alternativa';

  @override
  String get noHandoffPhoto => 'Aún no hay foto de la entrega';

  @override
  String get handoffPhotoHint => 'Una foto del artículo sellado al entregarlo';

  @override
  String get sealIntactPhoto => 'Precinto intacto';

  @override
  String get change => 'Cambiar';

  @override
  String get payoutDestination => 'Destino del pago al viajero';

  @override
  String payoutAmount(String amount) {
    return 'Pago de +$amount';
  }

  @override
  String get noPayoutAccountForRelease =>
      'Aún no hay cuenta de cobro. Añade una en Ajustes de pago; el pago se enviará allí.';

  @override
  String get mobileMoneyPayoutSpeed => 'Dinero móvil · Liberación inmediata';

  @override
  String get bankPayoutSpeed => 'Transferencia bancaria · 1 día hábil';

  @override
  String get disputeProtectionWindow => 'Plazo de protección ante disputas';

  @override
  String get threeDaysActive => '3 días activo';

  @override
  String get disputeProtectionNote =>
      'Los fondos se transfieren automáticamente al método elegido cuando termina el plazo de 3 días sin reclamaciones.';

  @override
  String get reportIssue => 'Informar de un problema o abrir una disputa';

  @override
  String confirmReleasePayout(String amount) {
    return 'Confirmar y liberar el pago ($amount)';
  }

  @override
  String get requestUpdated => 'Solicitud actualizada';

  @override
  String get errRequestNotFound => 'Esta solicitud ya no existe.';

  @override
  String get errRequestNotEditable =>
      'El viajero ya respondió a esta solicitud, así que ya no se puede cambiar.';

  @override
  String get editRequest => 'Editar solicitud';

  @override
  String saveChangesWithPrice(String price) {
    return 'Guardar cambios · $price';
  }

  @override
  String get statusExpired => 'Caducada';

  @override
  String get statusPaid => 'Pagada';

  @override
  String get statusInTransit => 'En tránsito';

  @override
  String get statusDelivered => 'Entregada';

  @override
  String get statusCancelled => 'Cancelada';

  @override
  String get noSentRequests => 'Aún no has enviado ninguna solicitud.';

  @override
  String get errLoadRequests => 'No se pudieron cargar tus solicitudes.';

  @override
  String get tapToEdit => 'Toca para editar';

  @override
  String get errIdNameMismatch =>
      'El nombre de este documento no coincide con el de tu perfil. Sube un documento que muestre tu nombre y apellido, o actualiza el nombre de tu perfil.';

  @override
  String get errContactSave =>
      'No se pudo guardar el contacto. Inténtalo de nuevo.';

  @override
  String get updateAvailableTitle => 'Actualización disponible';

  @override
  String updateAvailableBody(String latest, String current) {
    return 'Nata $latest ya está disponible. Estás usando la versión $current.';
  }

  @override
  String get updateRequiredTitle => 'Actualización necesaria';

  @override
  String get updateRequiredBody =>
      'Esta versión de Nata ya no es compatible. Actualiza para seguir usando la app.';

  @override
  String get updateWhatsNew => 'Novedades';

  @override
  String get updateNow => 'Actualizar';

  @override
  String get updateLater => 'Más tarde';

  @override
  String get updateOpenFailed =>
      'No se pudo abrir la tienda. Busca Nata en tu tienda de aplicaciones.';

  @override
  String get errAccountNotFound =>
      'No hay ninguna cuenta con este número. Primero regístrate.';

  @override
  String get itemsTitle => 'Artículos';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos',
      one: '1 artículo',
    );
    return '$_temp0';
  }

  @override
  String itemNumber(int number) {
    return 'Artículo $number';
  }

  @override
  String get removeItem => 'Quitar';

  @override
  String get addAnotherItem => 'Añadir otro artículo';

  @override
  String errItemNameN(int number) {
    return 'Indica qué es el artículo $number.';
  }

  @override
  String itemsMaxNote(int max) {
    return 'Puedes enviar hasta $max artículos en una solicitud.';
  }

  @override
  String get errRecipientName =>
      'Introduce el nombre completo del destinatario.';

  @override
  String get errRecipientPhone =>
      'Introduce un número de teléfono válido para el destinatario.';

  @override
  String get errWeight => 'Introduce el peso del paquete, p. ej. 0,9 kg.';

  @override
  String get errPhotoRequired =>
      'Añade al menos una foto del artículo sellado.';

  @override
  String get errPhotoTooBig => 'Esa foto es demasiado grande (máx. 10 MB).';

  @override
  String get errPhotoLimit => 'Puedes añadir hasta 3 fotos.';

  @override
  String get errTripUnavailable => 'Este viaje ya no está disponible.';

  @override
  String get errOwnTrip => 'No puedes enviar un paquete con tu propio viaje.';

  @override
  String get errDuplicate => 'Ya tienes una solicitud abierta en este viaje.';

  @override
  String errDestinationLimit(String city) {
    return 'Ya tienes 5 solicitudes abiertas con destino a $city. Podrás enviar otra cuando una de ellas se entregue, se rechace o caduque.';
  }

  @override
  String get cancelRequest => 'Cancelar solicitud';

  @override
  String get cancelRequestTitle => '¿Cancelar esta solicitud?';

  @override
  String get cancelRequestFreeBody =>
      'El viajero aún no ha aceptado, así que cancelar es gratis.';

  @override
  String cancelRequestFeeBody(String fee) {
    return 'El viajero ya aceptó esta solicitud. Cancelar ahora tiene una tarifa de cancelación del 10 %: $fee.';
  }

  @override
  String get keepRequest => 'Mantener solicitud';

  @override
  String cancelWithFee(String fee) {
    return 'Cancelar y pagar $fee';
  }

  @override
  String get requestCancelled => 'Solicitud cancelada';

  @override
  String cancellationFeeCharged(String fee) {
    return 'Tarifa de cancelación: $fee';
  }

  @override
  String get cancelledFreeOfCharge => 'Cancelada sin coste';

  @override
  String get errFeeChanged =>
      'El viajero acaba de responder a esta solicitud, así que la tarifa de cancelación ha cambiado. Revísala e inténtalo de nuevo.';

  @override
  String get errNotCancellable => 'Esta solicitud ya no se puede cancelar.';

  @override
  String get errCancelFailed =>
      'No se pudo cancelar tu solicitud. Inténtalo de nuevo.';

  @override
  String sentRequestsCount(int count) {
    return 'SOLICITUDES ENVIADAS ($count)';
  }

  @override
  String get waitingForTraveler => 'Esperando al viajero';

  @override
  String get routeLabel => 'Ruta:';

  @override
  String travelerDeliveries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Viajero · $count entregas',
      one: 'Viajero · 1 entrega',
      zero: 'Viajero · Nuevo',
    );
    return '$_temp0';
  }

  @override
  String get errSessionExpired => 'Tu sesión caducó. Inicia sesión de nuevo.';

  @override
  String get errInvalidRequest =>
      'Se rechazaron algunos datos. Revisa el formulario.';

  @override
  String get errRequestFailed =>
      'No se pudo enviar tu solicitud. Inténtalo de nuevo.';

  @override
  String get requestSent => 'Solicitud enviada. El viajero la revisará.';

  @override
  String travelerMaxKg(String kg) {
    return 'Máx. $kg kg';
  }

  @override
  String errWeightTooHeavy(String max) {
    return 'Este viajero acepta hasta $max kg.';
  }

  @override
  String photosAttachedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos adjuntas',
      one: '1 foto adjunta',
      zero: 'Sin fotos',
    );
    return '$_temp0';
  }

  @override
  String sendRequestWithPrice(String price) {
    return 'Enviar solicitud · $price';
  }

  @override
  String get packageSize => 'Tamaño del paquete';

  @override
  String get sizeEnvelope => 'Sobre / Documento';

  @override
  String get sizeShoebox => 'Caja de zapatos';

  @override
  String get sizeBackpack => 'Mochila';

  @override
  String get errSizeRequired => 'Elige el tamaño del paquete.';

  @override
  String get errSizeTooBig =>
      'Este paquete es más grande de lo que acepta el viajero.';

  @override
  String get errPriceChanged =>
      'El precio cambió desde que abriste esta solicitud. Vuelve y ábrela de nuevo para ver el nuevo precio.';

  @override
  String get priceEnterWeight =>
      'Introduce el peso del paquete para ver el precio final.';

  @override
  String get priceRateUnavailable =>
      'Tipo de cambio no disponible, así que los precios se muestran en dólares estadounidenses.';

  @override
  String get priceCredit => 'Tipos de cambio de Exchange Rate API';

  @override
  String get priceCalculating => 'Calculando el precio…';

  @override
  String get errQuoteUnavailable =>
      'No se pudo calcular el precio. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String priceBasedOn(String km) {
    return 'Según la distancia ($km km), el peso y la fecha de entrega';
  }

  @override
  String priceRateLine(String rate, String currency, String date) {
    return '1 USD = $rate $currency · actualizado $date';
  }

  @override
  String get departingFrom => 'Salida desde';

  @override
  String get hello => 'Hola,';

  @override
  String get whereAreYouSending => '¿A dónde envías?';

  @override
  String get whereSendingFrom => '¿Desde dónde envías?';

  @override
  String get destinationExample => 'p. ej. Londres, Reino Unido';

  @override
  String get anytimeThisMonth => 'Cualquier día de este mes';

  @override
  String get flexibleShort => '(±3 d)';

  @override
  String get availableTravelers => 'Viajeros disponibles';

  @override
  String get errLoadTravelers => 'No se pudieron cargar los viajeros.';

  @override
  String get noTravelersOnRoute => 'Aún no hay viajeros en esta ruta.';

  @override
  String get desiredDeliveryDateTitle => 'Fecha de entrega deseada';

  @override
  String upToKg(String weight) {
    return 'Hasta $weight kg';
  }

  @override
  String get dateAnytime => 'Cualquier día';

  @override
  String get dateThisWeek => 'Esta semana';

  @override
  String get dateNextWeek => 'Próxima semana';

  @override
  String get dateFlexible => 'Flexible (±3 d)';

  @override
  String travelerFlightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vuelos de viajeros',
      one: '1 vuelo de viajero',
    );
    return '$_temp0';
  }

  @override
  String flightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vuelos',
      one: '1 vuelo',
    );
    return '$_temp0';
  }

  @override
  String get plusMinus3Days => '±3 días';

  @override
  String get anyDate => 'Cualquier fecha';

  @override
  String get selectADate => 'Selecciona una fecha';

  @override
  String confirmDateOn(String date) {
    return 'Confirmar fecha ($date)';
  }

  @override
  String get confirmDateAnytime => 'Confirmar fecha (cualquier día)';

  @override
  String get searchCountryHint => 'Buscar país...';

  @override
  String searchCityIn(String country) {
    return 'Buscar ciudad en $country...';
  }

  @override
  String get selectCityTitle => 'Seleccionar ciudad';

  @override
  String get noCountriesFound => 'No se encontraron países';

  @override
  String noCitiesFoundIn(String country) {
    return 'No se encontraron ciudades en $country';
  }

  @override
  String get selectCountryCode => 'Seleccionar código de país';

  @override
  String get errLoadTravelersRetry =>
      'No se pudieron cargar los viajeros. Inténtalo de nuevo.';

  @override
  String get anywhere => 'Cualquier lugar';

  @override
  String byDate(String date) {
    return 'antes del $date';
  }

  @override
  String get noTravelersOnRouteTitle => 'Aún no hay viajeros en esta ruta';

  @override
  String get tryAnotherDateOrRoute =>
      'Prueba otra fecha u otra ruta, o activa las alertas abajo.';

  @override
  String get travelersFound => 'Viajeros encontrados';

  @override
  String get notifyNewTravelers =>
      'Recibe un aviso en cuanto nuevos viajeros añadan viajes en esta ruta.';

  @override
  String get capacityNotSpecified => 'Capacidad no especificada';

  @override
  String acceptsUpToKg(String weight) {
    return 'Acepta hasta $weight kg';
  }

  @override
  String get arrivingIn => 'Llegada a';

  @override
  String get departureDateTitle => 'Fecha de salida';

  @override
  String get arrivalDateTitle => 'Fecha de llegada';

  @override
  String get errOpenFile => 'No se pudo abrir ese archivo.';

  @override
  String get errFileTooLarge => 'Ese archivo es demasiado grande (máx. 10 MB).';

  @override
  String get departureDetailsTitle => 'Detalles de salida';

  @override
  String get arrivalDetailsTitle => 'Detalles de llegada';

  @override
  String get departureCountryLabel => 'PAÍS DE SALIDA';

  @override
  String get departureCityLabel => 'CIUDAD DE SALIDA';

  @override
  String get arrivalCountryLabel => 'PAÍS DE LLEGADA';

  @override
  String get arrivalCityLabel => 'CIUDAD DE LLEGADA';

  @override
  String get receiptOnFile => 'Recibo guardado';

  @override
  String get bookingRefHint => 'p. ej. X7KQ9R';

  @override
  String deliveriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entregas',
      one: '1 entrega',
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
      other: '$count entregados',
      one: '1 entregado',
    );
    return '$_temp0';
  }

  @override
  String flightsShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vuel.',
      one: '1 vuel.',
    );
    return '$_temp0';
  }

  @override
  String amountPerDelivery(String amount) {
    return '$amount / entrega';
  }

  @override
  String get countries180 => '180+ países';

  @override
  String get errEnterPhone => 'Introduce tu número de teléfono.';

  @override
  String get errTooManyRequests => 'Demasiadas solicitudes. Espera un momento.';

  @override
  String get errTooManyRequestsRetry =>
      'Demasiadas solicitudes. Espera un momento e inténtalo de nuevo.';

  @override
  String get errInvalidPhone =>
      'Número de teléfono no válido. Revísalo e inténtalo de nuevo.';

  @override
  String get errSomethingWrong => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get errFillAllFields => 'Completa todos los campos.';

  @override
  String get countryOfResidenceLabel => 'PAÍS DE RESIDENCIA';

  @override
  String get errVerificationFailed =>
      'La verificación falló. Inténtalo de nuevo.';

  @override
  String get errCodeExpired => 'El código caducó. Solicita uno nuevo.';

  @override
  String get errOtpDisabled =>
      'La verificación por teléfono no está activada. Contacta con soporte.';

  @override
  String get errIncorrectCode => 'Código incorrecto. Inténtalo de nuevo.';

  @override
  String get errTooManyAttempts =>
      'Demasiados intentos. Espera antes de reintentar.';

  @override
  String get errNetwork => 'Error de red. Revisa tu conexión.';

  @override
  String get errIncorrectOrExpiredCode =>
      'Código incorrecto o caducado. Inténtalo de nuevo.';

  @override
  String get enterVerificationCode => 'Introduce el código de verificación';

  @override
  String get otpSentToPrefix => 'Enviamos un código de 6 dígitos al ';

  @override
  String get verifyCode => 'Verificar código';

  @override
  String get resendCodeInPrefix => 'Reenviar código en ';

  @override
  String get resendCode => 'Reenviar código';

  @override
  String get otpNotReceived =>
      '¿No recibiste el código? Comprueba que tu número sea correcto y que tengas cobertura.';

  @override
  String get verifyPhone => 'Verificar teléfono';

  @override
  String get errCaptureIdFirst =>
      'Primero toma una foto o sube tu documento de identidad.';

  @override
  String get errUploadFailed => 'La subida falló. Inténtalo de nuevo.';

  @override
  String get uploadingEllipsis => 'Subiendo...';

  @override
  String get submitForVerification => 'Enviar para verificación';

  @override
  String get documentSelected => 'Documento seleccionado';

  @override
  String errCameraDetail(String error) {
    return 'Error de cámara: $error';
  }

  @override
  String errFilePicker(String error) {
    return 'Error al elegir el archivo: $error';
  }

  @override
  String get verifiedLabel => 'Verificado';

  @override
  String matchPercent(String percent) {
    return 'Coincidencia $percent';
  }

  @override
  String get requestExpiresInPrefix => 'La solicitud caduca en ';

  @override
  String get escrowNotePart1 =>
      'Nata guarda tu pago de forma segura. Al viajero solo se le paga ';

  @override
  String get escrowNotePart2 =>
      'después de que tu destinatario verifique la entrega';

  @override
  String get escrowNotePart3 =>
      ' con tu código secreto de 4 dígitos o una prueba fotográfica.';

  @override
  String get itemPlain => 'Artículo';

  @override
  String get weightPlain => 'Peso';

  @override
  String get refundFullBold => 'Reembolso completo del 100 %';

  @override
  String get refundFullRest =>
      'si el viajero cancela o el artículo no se entrega.';

  @override
  String get cancelFeeBold => 'Tarifa de cancelación del 10 %';

  @override
  String get cancelFeeRest =>
      'si cancelas después de que el viajero acepte, hasta la entrega.';

  @override
  String get disputeWindowBold => 'Plazo de reclamación de 3 días';

  @override
  String get disputeWindowRest =>
      'después de la entrega antes de que se liberen los fondos.';

  @override
  String get reviewTagIntact => 'El artículo llegó intacto';

  @override
  String get reviewTagOnTime => 'Puntual';

  @override
  String get reviewTagCommunicator => 'Gran comunicación';

  @override
  String get reviewTagRules => 'Siguió todas las normas';

  @override
  String get reviewTagHandoff => 'Entrega sin problemas';

  @override
  String get reviewTagAgain => 'Volvería a usarlo';

  @override
  String deliveredYourItem(String item, String date) {
    return 'Entregó tu $item · $date';
  }

  @override
  String get expiryHint => 'MM/AA';

  @override
  String get profilePictureUpdated => 'Foto de perfil actualizada';

  @override
  String errUploadImage(String error) {
    return 'No se pudo subir la imagen: $error';
  }

  @override
  String get senderEscrowFunded => 'Remitente · Depósito en garantía';

  @override
  String senderDeliveries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remitente · $count entregas',
      one: 'Remitente · 1 entrega',
    );
    return '$_temp0';
  }

  @override
  String sealedPhotosAttached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos del embalaje sellado adjuntas',
      one: '1 foto del embalaje sellado adjunta',
    );
    return '$_temp0';
  }

  @override
  String capturedAt(String place, String time) {
    return 'Tomada en $place · $time';
  }

  @override
  String txDeliveryOf(String item) {
    return 'Entrega de $item';
  }

  @override
  String txReleasedFromEscrow(String date) {
    return 'Liberado del depósito · $date';
  }

  @override
  String get txEscrowHold => 'Retención en depósito';

  @override
  String txDeliveryRequest(String date) {
    return 'Solicitud de entrega · $date';
  }

  @override
  String priceEstimateNote(String currency) {
    return 'Esto es una estimación en $currency al tipo de cambio de hoy. El precio se fija cuando el viajero acepta.';
  }

  @override
  String get estimateLabel => 'Estimación';

  @override
  String get errRateUnavailable =>
      'El tipo de cambio no está disponible ahora mismo, así que el precio no se puede fijar. Inténtalo más tarde.';

  @override
  String get errRequestNotPending => 'Esta solicitud ya ha sido respondida.';

  @override
  String get chatLockedUntilPayment =>
      'El chat se desbloquea cuando se paga la entrega. Tu pago queda en depósito hasta que se confirme la entrega.';

  @override
  String get messageLocked => 'Mensaje';

  @override
  String get messageUnlocksAfterPayment =>
      'Los mensajes se desbloquean después del pago.';

  @override
  String get escrowFunded => 'Depósito realizado';

  @override
  String maxDims(String dims) {
    return 'Máx. $dims';
  }

  @override
  String get errRequestNotPayable => 'Esta solicitud ya no se puede pagar.';

  @override
  String get step1ValidateTicket => 'PASO 1 · VERIFICAR EL BILLETE DE AVIÓN';

  @override
  String get step2PaymentMethod => 'PASO 2 · ELEGIR EL MÉTODO DE PAGO';

  @override
  String get ticketNotValidated => 'No verificado';

  @override
  String get ticketValidated => 'Verificado';

  @override
  String ticketIntro(String name) {
    return '$name subió su billete de avión para este viaje. Comprueba que coincide con la ruta y la fecha antes de pagar.';
  }

  @override
  String get viewFullTicket => 'Ver el billete completo';

  @override
  String get ticketPdf => 'Billete de avión (PDF)';

  @override
  String get ticketRoute => 'Ruta';

  @override
  String get ticketDeparture => 'Salida';

  @override
  String get ticketBookingRef => 'Referencia de reserva';

  @override
  String get ticketTraveler => 'Viajero';

  @override
  String get iCheckedTicket => 'He verificado este billete';

  @override
  String get errTicketLoad => 'No se pudo cargar el billete.';

  @override
  String get noTicketUploaded =>
      'El viajero aún no ha subido un billete para este viaje, así que el pago sigue bloqueado.';

  @override
  String get validateToUnlock => 'Verifica el billete para desbloquear el pago';

  @override
  String payAmountIntoEscrow(String amount) {
    return 'Pagar $amount en depósito';
  }

  @override
  String get paymentsComingSoon =>
      'Los pagos aún no están disponibles. Pronto podrás pagar aquí.';

  @override
  String get requestExpiredPayment =>
      'Esta solicitud ha caducado y ya no se puede pagar.';

  @override
  String hoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get step2VerifyId => 'PASO 2 · VERIFICAR LA IDENTIDAD DEL VIAJERO';

  @override
  String get step3PaymentMethod => 'PASO 3 · ELEGIR EL MÉTODO DE PAGO';

  @override
  String idIntro(String name) {
    return 'El documento de identidad de $name fue verificado. Comprueba que la foto parece real y que el nombre coincide con el billete antes de pagar.';
  }

  @override
  String get identityVerifiedBadge => 'Identidad verificada';

  @override
  String get nameOnId => 'Nombre en el documento';

  @override
  String get idDocument => 'Documento';

  @override
  String get idVerifiedOn => 'Verificada el';

  @override
  String get idPhotoOnlyNote =>
      'Solo se muestra la foto. El resto del documento sigue siendo privado.';

  @override
  String get iCheckedId => 'He verificado este documento';

  @override
  String get errIdPhotoLoad => 'No se pudo cargar la foto del documento.';

  @override
  String get travelerNotVerified =>
      'La identidad de este viajero no está verificada, así que el pago sigue bloqueado.';

  @override
  String get validateTicketAndId =>
      'Verifica el billete y el documento para desbloquear el pago';

  @override
  String get idSharedWithSendersNote =>
      'Cuando aceptes una solicitud, ese remitente verá la foto de tu documento y tu nombre verificado, para comprobar que coincides con tu billete. El resto de tu documento sigue siendo privado.';

  @override
  String get errTicketNameMismatch =>
      'El nombre de este billete no coincide con el de tu perfil. Sube un billete a tu nombre o actualiza el nombre de tu perfil.';

  @override
  String errTicketDateMismatch(String date) {
    return 'Este billete no es para el $date. Revisa las fechas del viaje o sube el billete de este vuelo.';
  }

  @override
  String get errTicketUnreadable =>
      'No pudimos leer este billete. Sube una foto nítida o el PDF de tu tarjeta de embarque o billete electrónico.';

  @override
  String get checkingTicket => 'Comprobando tu billete…';
}
