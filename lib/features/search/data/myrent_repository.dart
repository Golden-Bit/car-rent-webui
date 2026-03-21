import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:car_rent_webui/core/deeplink/initial_config.dart';

/// Config via --dart-define
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://www.goldbitweb.com/myrent-wrapper-api',
  //defaultValue: 'http://localhost:8333',
);

const String kApiKey = String.fromEnvironment(
  'MYRENT_API_KEY',
  defaultValue: 'MYRENT-DEMO-KEY',
);

class MyrentRepository {
  late final MyrentClient client;

  /// ✅ Impostiamo qui la sorgente desiderata per tutto il repository
  static const DataSource kSource = DataSource.MYRENT;

  MyrentRepository()
      : client = MyrentClient(
          baseUrl: kApiBaseUrl,
          apiKey: kApiKey,
        );

  /// ✅ Locations da fonte MYRENT (non DEFAULT/mock)
  Future<List<Location>> fetchLocations() => client.getLocations(source: kSource);

  /// ✅ Quotation da fonte MYRENT (non DEFAULT/mock)
  Future<QuotationResponse> createQuotation({
    required String pickupCode,
    required String dropoffCode,
    required DateTime startUtc,
    required DateTime endUtc,
    int? age,
    String? coupon,
    String? channel,
    bool showPics = true,
    bool showVehicleParameter = true,
    String? macro,
  }) async {
    /// Niente fromDates: uso costruttore standard + isoZ dello SDK
    final req = QuotationRequest(
      dropOffLocation: dropoffCode,
      endDate: isoZ(endUtc),
      pickupLocation: pickupCode,
      startDate: isoZ(startUtc),
      age: age,
      channel: channel ?? 'RENTAL_PREMIUM_POA',
      showPics: showPics,
      showOptionalImage: false,
      showVehicleParameter: showVehicleParameter,
      showVehicleExtraImage: false,
      agreementCoupon: coupon,
      discountValueWithoutVat: null,
      macroDescription: macro,
      showBookingDiscount: false,
      isYoungDriverAge: null,
      isSeniorDriverAge: null,
    );

    /// ✅ IMPORTANTISSIMO: source=MYRENT
    return client.createQuotation(req, source: kSource);
  }

  /// Helper per deep-link: crea quotation da InitialConfig
  Future<QuotationResponse> createQuotationFromConfig(InitialConfig cfg) {
    return createQuotation(
      pickupCode: cfg.pickupLocation,
      dropoffCode: cfg.dropoffLocation,
      startUtc: cfg.start.toUtc(),
      endUtc: cfg.end.toUtc(),
      age: cfg.age,
      coupon: cfg.coupon,
      channel: cfg.channel ?? 'RENTAL_PREMIUM_POA',
      showPics: true,
      showVehicleParameter: true,
      macro: null,
    );
  }

  Future<ReservationComposeResponse> createReservationCompose({
    required JsonMap booking,
    required JsonMap customer,
    JsonMap? customerUpdate,
    JsonMap? driver1,
    JsonMap? driver2,
    JsonMap? driver3,
  }) {
    final req = ReservationComposeRequest(
      booking: booking,
      customer: customer,
      customerUpdate: customerUpdate,
      driver1: driver1,
      driver2: driver2,
      driver3: driver3,
    );

    return client.createReservationCompose(req, source: kSource);
  }

  Future<ReservationFullDetailsResponse> getReservationByInternalId(
    String reservationId,
  ) {
    return client.getReservationDetailsByInternalId(
      reservationId,
      source: kSource,
    );
  }

  Future<ReservationFullDetailsResponse> getReservationByCode({
    required String reservationCode,
    required String customerEmail,
    required String reservationDate,
  }) {
    return client.getReservationDetailsByCode(
      reservationCode: reservationCode,
      customerEmail: customerEmail,
      reservationDate: reservationDate,
      source: kSource,
    );
  }
  
  /// (Opzionale) chiudi il client se decidi di gestire il lifecycle manualmente
  void close() => client.close();
}
