import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:car_rent_webui/core/deeplink/initial_config.dart';

/// Config via --dart-define
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'https://www.goldbitweb.com/myrent-wrapper-api'); // 'http://localhost:8333');
const String kApiKey =
    String.fromEnvironment('MYRENT_API_KEY', defaultValue: 'MYRENT-DEMO-KEY');

class MyrentRepository {
  late final MyrentClient client;

  MyrentRepository() : client = MyrentClient(baseUrl: kApiBaseUrl, apiKey: kApiKey);

  Future<List<Location>> fetchLocations() => client.getLocations();

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
    // Niente fromDates: uso il costruttore standard + isoZ dello SDK
    final req = QuotationRequest(
      dropOffLocation: dropoffCode,
      endDate: isoZ(endUtc),
      pickupLocation: pickupCode,
      startDate: isoZ(startUtc),
      age: age,
      channel: channel ?? 'WEB_APP',
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

    return client.createQuotation(req);
  }

  Future<QuotationResponse> createQuotationFromConfig(InitialConfig cfg) {
return createQuotation(
pickupCode: cfg.pickupLocation,
dropoffCode: cfg.dropoffLocation,
startUtc: cfg.start.toUtc(),
endUtc: cfg.end.toUtc(),
age: cfg.age,
coupon: cfg.coupon,
channel: cfg.channel ?? 'WEB_APP',
showPics: true,
showVehicleParameter: true,
macro: null,
);
}
}
