// ignore_for_file: non_constant_identifier_names

library myrent_sdk;

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Eccezione API
class ApiException implements Exception {
  final int statusCode;
  final String body;
  final Uri uri;

  ApiException(this.statusCode, this.body, this.uri);

  @override
  String toString() =>
      'ApiException(statusCode=$statusCode, uri=$uri, body=$body)';
}

/// Client principale
class MyrentClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _client;
  final Map<String, String> _defaultHeaders;

  MyrentClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  })  : _client = httpClient ?? http.Client(),
        _defaultHeaders = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': apiKey,
        };

  /// GET /health
  Future<Health> getHealth() async {
    final uri = Uri.parse('$baseUrl/health');
    final res = await _client.get(uri, headers: _defaultHeaders);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Health.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiException(res.statusCode, res.body, uri);
  }

  /// GET /api/v1/touroperator/locations
  Future<List<Location>> getLocations() async {
    final uri = Uri.parse('$baseUrl/api/v1/touroperator/locations');
    final res = await _client.get(uri, headers: _defaultHeaders);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((e) => Location.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(res.statusCode, res.body, uri);
  }

  /// POST /api/v1/touroperator/quotations
  Future<QuotationResponse> createQuotation(QuotationRequest req) async {
    final uri = Uri.parse('$baseUrl/api/v1/touroperator/quotations');
    final res = await _client.post(
      uri,
      headers: _defaultHeaders,
      body: jsonEncode(req.toJson()),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return QuotationResponse.fromJson(data);
    }
    throw ApiException(res.statusCode, res.body, uri);
  }

  /// GET /api/v1/touroperator/damages/{plate_or_vin}
  Future<DamagesResponse> getDamages(String plateOrVin,
      {String? acceptLanguage}) async {
    final uri =
        Uri.parse('$baseUrl/api/v1/touroperator/damages/$plateOrVin');

    final headers = Map<String, String>.from(_defaultHeaders);
    if (acceptLanguage != null && acceptLanguage.isNotEmpty) {
      headers['Accept-Language'] = acceptLanguage;
    }

    final res = await _client.get(uri, headers: headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return DamagesResponse.fromJson(data);
    }
    throw ApiException(res.statusCode, res.body, uri);
  }

  void close() => _client.close();
}

/// Helper: formatta DateTime in ISO8601 con suffisso Z
String isoZ(DateTime dt) {
  return dt.toUtc().toIso8601String().split('.').first + 'Z';
}

/* ===========================
 *          MODELS
 * ===========================
 */

class Health {
  final String status;
  final String? version;

  Health({required this.status, this.version});

  factory Health.fromJson(Map<String, dynamic> json) => Health(
        status: json['status'] as String,
        version: json['version'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        if (version != null) 'version': version,
      };
}

/* ------ Locations ------ */

class WeekOfDay {
  final int dayOfTheWeek;
  final String dayOfTheWeekName;
  final String startTime;
  final String endTime;

  WeekOfDay({
    required this.dayOfTheWeek,
    required this.dayOfTheWeekName,
    required this.startTime,
    required this.endTime,
  });

  factory WeekOfDay.fromJson(Map<String, dynamic> json) => WeekOfDay(
        dayOfTheWeek: json['dayOfTheWeek'] as int,
        dayOfTheWeekName: json['dayOfTheWeekName'] as String,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
      );

  Map<String, dynamic> toJson() => {
        'dayOfTheWeek': dayOfTheWeek,
        'dayOfTheWeekName': dayOfTheWeekName,
        'startTime': startTime,
        'endTime': endTime,
      };
}

class Closing {
  final int dayOfTheWeek;
  final String dayOfTheWeekName;
  final String startTime;
  final String endTime;

  Closing({
    required this.dayOfTheWeek,
    required this.dayOfTheWeekName,
    required this.startTime,
    required this.endTime,
  });

  factory Closing.fromJson(Map<String, dynamic> json) => Closing(
        dayOfTheWeek: json['dayOfTheWeek'] as int,
        dayOfTheWeekName: json['dayOfTheWeekName'] as String,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
      );

  Map<String, dynamic> toJson() => {
        'dayOfTheWeek': dayOfTheWeek,
        'dayOfTheWeekName': dayOfTheWeekName,
        'startTime': startTime,
        'endTime': endTime,
      };
}

class Location {
  final String locationCode;
  final String locationName;
  final String? locationAddress;
  final String? locationNumber;
  final String? locationCity;
  final int locationType;
  final String? telephoneNumber;
  final String? cellNumber;
  final String? email;
  final double? latitude;
  final double? longitude;
  final bool isAirport;
  final bool isRailway;
  final bool? isAlwaysOpentrue;
  final bool isCarSharingEnabled;
  final bool allowPickUpDropOffOutOfHours;
  final bool hasKeyBox;
  final String? morningStartTime;
  final String? morningStopTime;
  final String? afternoonStartTime;
  final String? afternoonStopTime;
  final String? locationInfoEN;
  final String? locationInfoLocal;
  final List<WeekOfDay> openings;
  final List<Closing>? closing;
  final List<Map<String, dynamic>>? festivity;
  final int? minimumLeadTimeInHour;
  final String? country;
  final String? zipCode;

  Location({
    required this.locationCode,
    required this.locationName,
    this.locationAddress,
    this.locationNumber,
    this.locationCity,
    this.locationType = 3,
    this.telephoneNumber,
    this.cellNumber,
    this.email,
    this.latitude,
    this.longitude,
    this.isAirport = false,
    this.isRailway = false,
    this.isAlwaysOpentrue,
    this.isCarSharingEnabled = false,
    this.allowPickUpDropOffOutOfHours = false,
    this.hasKeyBox = false,
    this.morningStartTime,
    this.morningStopTime,
    this.afternoonStartTime,
    this.afternoonStopTime,
    this.locationInfoEN,
    this.locationInfoLocal,
    this.openings = const [],
    this.closing,
    this.festivity,
    this.minimumLeadTimeInHour,
    this.country,
    this.zipCode,
  });

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        locationCode: json['locationCode'] as String,
        locationName: json['locationName'] as String,
        locationAddress: json['locationAddress'] as String?,
        locationNumber: json['locationNumber'] as String?,
        locationCity: json['locationCity'] as String?,
        locationType: (json['locationType'] ?? 3) as int,
        telephoneNumber: json['telephoneNumber'] as String?,
        cellNumber: json['cellNumber'] as String?,
        email: json['email'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        isAirport: (json['isAirport'] ?? false) as bool,
        isRailway: (json['isRailway'] ?? false) as bool,
        isAlwaysOpentrue: json['isAlwaysOpentrue'] as bool?,
        isCarSharingEnabled: (json['isCarSharingEnabled'] ?? false) as bool,
        allowPickUpDropOffOutOfHours:
            (json['allowPickUpDropOffOutOfHours'] ?? false) as bool,
        hasKeyBox: (json['hasKeyBox'] ?? false) as bool,
        morningStartTime: json['morningStartTime'] as String?,
        morningStopTime: json['morningStopTime'] as String?,
        afternoonStartTime: json['afternoonStartTime'] as String?,
        afternoonStopTime: json['afternoonStopTime'] as String?,
        locationInfoEN: json['locationInfoEN'] as String?,
        locationInfoLocal: json['locationInfoLocal'] as String?,
        openings: (json['openings'] as List<dynamic>? ?? [])
            .map((e) => WeekOfDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        closing: (json['closing'] as List<dynamic>?)
            ?.map((e) => Closing.fromJson(e as Map<String, dynamic>))
            .toList(),
        festivity: (json['festivity'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        minimumLeadTimeInHour: json['minimumLeadTimeInHour'] as int?,
        country: json['country'] as String?,
        zipCode: json['zipCode'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'locationCode': locationCode,
        'locationName': locationName,
        if (locationAddress != null) 'locationAddress': locationAddress,
        if (locationNumber != null) 'locationNumber': locationNumber,
        if (locationCity != null) 'locationCity': locationCity,
        'locationType': locationType,
        if (telephoneNumber != null) 'telephoneNumber': telephoneNumber,
        if (cellNumber != null) 'cellNumber': cellNumber,
        if (email != null) 'email': email,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'isAirport': isAirport,
        'isRailway': isRailway,
        if (isAlwaysOpentrue != null) 'isAlwaysOpentrue': isAlwaysOpentrue,
        'isCarSharingEnabled': isCarSharingEnabled,
        'allowPickUpDropOffOutOfHours': allowPickUpDropOffOutOfHours,
        'hasKeyBox': hasKeyBox,
        if (morningStartTime != null) 'morningStartTime': morningStartTime,
        if (morningStopTime != null) 'morningStopTime': morningStopTime,
        if (afternoonStartTime != null)
          'afternoonStartTime': afternoonStartTime,
        if (afternoonStopTime != null) 'afternoonStopTime': afternoonStopTime,
        if (locationInfoEN != null) 'locationInfoEN': locationInfoEN,
        if (locationInfoLocal != null) 'locationInfoLocal': locationInfoLocal,
        'openings': openings.map((e) => e.toJson()).toList(),
        if (closing != null) 'closing': closing!.map((e) => e.toJson()).toList(),
        if (festivity != null) 'festivity': festivity,
        if (minimumLeadTimeInHour != null)
          'minimumLeadTimeInHour': minimumLeadTimeInHour,
        if (country != null) 'country': country,
        if (zipCode != null) 'zipCode': zipCode,
      };
}

/* ------ Quotations ------ */

class VehMakeModel {
  final String Name;

  VehMakeModel({required this.Name});

  factory VehMakeModel.fromJson(Map<String, dynamic> json) =>
      VehMakeModel(Name: json['Name'] as String);

  Map<String, dynamic> toJson() => {'Name': Name};
}

class BookingVehicle {
  // Codici
  final String Code;
  final String? CodeContext;
  final String? nationalCode; // <-- NEW (alias "nationalCode")

  // Nome/branding
  final List<VehMakeModel> vehMakeModels; // JSON: "VehMakeModel"
  final String? model;
  final String? brand;
  final String? version;

  // Macro / tipo
  final String? VendorCarMacroGroup;
  final String? VendorCarType;

  // Specifiche veicolo (NEW)
  final int? seats;
  final int? doors;
  /// 'M' = Manuale, 'A' = Automatico (valore grezzo backend)
  final String? transmission;
  /// 'PETROL' | 'DIESEL' | 'ELECTRIC' | ...
  final String? fuel;
  final bool? aircon;
  final String? imageUrl;   // preferisci questa chiave; fallback su "image_url"
  final double? dailyRate;  // preferisci questa chiave; fallback su "daily_rate"

  // Altro
  final int? km;
  final String? color;
  final String? plate_no;
  final String? chasis_no;
  final List<String> locations; // <-- NEW
  final List<String> plates;    // <-- NEW

  BookingVehicle({
    required this.Code,
    this.CodeContext,
    this.nationalCode,
    this.vehMakeModels = const [],
    this.model,
    this.brand,
    this.version,
    this.VendorCarMacroGroup,
    this.VendorCarType,
    this.seats,
    this.doors,
    this.transmission,
    this.fuel,
    this.aircon,
    this.imageUrl,
    this.dailyRate,
    this.km,
    this.color,
    this.plate_no,
    this.chasis_no,
    this.locations = const [],
    this.plates = const [],
  });

  factory BookingVehicle.fromJson(Map<String, dynamic> json) => BookingVehicle(
        Code: json['Code'] as String,
        CodeContext: json['CodeContext'] as String?,
        nationalCode: json['nationalCode'] as String?,
        vehMakeModels: (json['VehMakeModel'] as List<dynamic>? ?? [])
            .map((e) => VehMakeModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        model: json['model'] as String?,
        brand: json['brand'] as String?,
        version: json['version'] as String?,
        VendorCarMacroGroup: json['VendorCarMacroGroup'] as String?,
        VendorCarType: json['VendorCarType'] as String?,

        // NEW fields
        seats: (json['seats'] as num?)?.toInt(),
        doors: (json['doors'] as num?)?.toInt(),
        transmission: json['transmission'] as String?,
        fuel: json['fuel'] as String?,
        aircon: json['aircon'] as bool?,
        imageUrl: (json['imageUrl'] ?? json['image_url']) as String?, // fallback
        dailyRate: (json['dailyRate'] ?? json['daily_rate']) == null
            ? null
            : (json['dailyRate'] ?? json['daily_rate'] as num).toDouble(),

        km: (json['km'] as num?)?.toInt(),
        color: json['color'] as String?,
        plate_no: json['plate_no'] as String?,
        chasis_no: json['chasis_no'] as String?,

        locations: (json['locations'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        plates: (json['plates'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'Code': Code,
        if (CodeContext != null) 'CodeContext': CodeContext,
        if (nationalCode != null) 'nationalCode': nationalCode,
        'VehMakeModel': vehMakeModels.map((e) => e.toJson()).toList(),
        if (model != null) 'model': model,
        if (brand != null) 'brand': brand,
        if (version != null) 'version': version,
        if (VendorCarMacroGroup != null)
          'VendorCarMacroGroup': VendorCarMacroGroup,
        if (VendorCarType != null) 'VendorCarType': VendorCarType,

        // NEW fields
        if (seats != null) 'seats': seats,
        if (doors != null) 'doors': doors,
        if (transmission != null) 'transmission': transmission,
        if (fuel != null) 'fuel': fuel,
        if (aircon != null) 'aircon': aircon,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (dailyRate != null) 'dailyRate': dailyRate,

        if (km != null) 'km': km,
        if (color != null) 'color': color,
        if (plate_no != null) 'plate_no': plate_no,
        if (chasis_no != null) 'chasis_no': chasis_no,
        if (locations.isNotEmpty) 'locations': locations,
        if (plates.isNotEmpty) 'plates': plates,
      };

  // (facoltative) utility utili alla UI
  bool get isAutomatic => (transmission ?? '').toUpperCase() == 'A';
  bool get hasAircon => aircon == true;
}


class VehicleParameter {
  // JSON keys hanno i due punti (!)
  final String name;
  final String description;
  final int position;
  final String fileUrl;

  VehicleParameter({
    required this.name,
    required this.description,
    required this.position,
    required this.fileUrl,
  });

  factory VehicleParameter.fromJson(Map<String, dynamic> json) =>
      VehicleParameter(
        name: json['name :'] as String,
        description: json['description :'] as String,
        position: (json['position :'] as num).toInt(),
        fileUrl: (json['fileUrl :'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'name :': name,
        'description :': description,
        'position :': position,
        'fileUrl :': fileUrl,
      };
}

class GroupPic {
  final int id;
  final String? url;

  GroupPic({required this.id, this.url});

  factory GroupPic.fromJson(Map<String, dynamic> json) => GroupPic(
        id: (json['id'] as num).toInt(),
        url: json['url'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, if (url != null) 'url': url};
}

class VehicleStatus {
  final String Status;
  final Map<String, dynamic>? Reference;
  final BookingVehicle Vehicle;
  final List<VehicleParameter>? vehicleParameter;
  final List<String>? vehicleExtraImage;
  final GroupPic? groupPic;

  VehicleStatus({
    required this.Status,
    required this.Reference,
    required this.Vehicle,
    this.vehicleParameter,
    this.vehicleExtraImage,
    this.groupPic,
  });

  factory VehicleStatus.fromJson(Map<String, dynamic> json) => VehicleStatus(
        Status: json['Status'] as String,
        Reference: (json['Reference'] as Map?)?.cast<String, dynamic>(),
        Vehicle: BookingVehicle.fromJson(
            json['Vehicle'] as Map<String, dynamic>),
        vehicleParameter: (json['vehicleParameter'] as List<dynamic>?)
            ?.map((e) => VehicleParameter.fromJson(e as Map<String, dynamic>))
            .toList(),
        vehicleExtraImage: (json['vehicleExtraImage'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        groupPic: json['groupPic'] == null
            ? null
            : GroupPic.fromJson(json['groupPic'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'Status': Status,
        if (Reference != null) 'Reference': Reference,
        'Vehicle': Vehicle.toJson(),
        if (vehicleParameter != null)
          'vehicleParameter': vehicleParameter!.map((e) => e.toJson()).toList(),
        if (vehicleExtraImage != null) 'vehicleExtraImage': vehicleExtraImage,
        if (groupPic != null) 'groupPic': groupPic!.toJson(),
      };
}

class Charge {
  final double Amount;
  final String CurrencyCode;
  final String Description;
  final bool IncludedInEstTotalInd;
  final bool IncludedInRate;
  final bool TaxInclusive;

  Charge({
    required this.Amount,
    required this.CurrencyCode,
    required this.Description,
    this.IncludedInEstTotalInd = true,
    this.IncludedInRate = false,
    this.TaxInclusive = false,
  });

  factory Charge.fromJson(Map<String, dynamic> json) => Charge(
        Amount: (json['Amount'] as num).toDouble(),
        CurrencyCode: json['CurrencyCode'] as String,
        Description: json['Description'] as String,
        IncludedInEstTotalInd:
            (json['IncludedInEstTotalInd'] ?? true) as bool,
        IncludedInRate: (json['IncludedInRate'] ?? false) as bool,
        TaxInclusive: (json['TaxInclusive'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'Amount': Amount,
        'CurrencyCode': CurrencyCode,
        'Description': Description,
        'IncludedInEstTotalInd': IncludedInEstTotalInd,
        'IncludedInRate': IncludedInRate,
        'TaxInclusive': TaxInclusive,
      };
}

class Equipment {
  final String Description;
  final String EquipType;
  final int Quantity;
  final bool isMultipliable;
  final String? optionalImage;

  Equipment({
    required this.Description,
    required this.EquipType,
    this.Quantity = 1,
    this.isMultipliable = true,
    this.optionalImage,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) => Equipment(
        Description: json['Description'] as String,
        EquipType: json['EquipType'] as String,
        Quantity: (json['Quantity'] as num?)?.toInt() ?? 1,
        isMultipliable: (json['isMultipliable'] ?? true) as bool,
        optionalImage: json['optionalImage'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'Description': Description,
        'EquipType': EquipType,
        'Quantity': Quantity,
        'isMultipliable': isMultipliable,
        if (optionalImage != null) 'optionalImage': optionalImage,
      };
}

class OptionalItem {
  final Charge ChargeObj;
  final Equipment EquipmentObj;

  OptionalItem({required this.ChargeObj, required this.EquipmentObj});

  factory OptionalItem.fromJson(Map<String, dynamic> json) => OptionalItem(
        ChargeObj: Charge.fromJson(json['Charge'] as Map<String, dynamic>),
        EquipmentObj:
            Equipment.fromJson(json['Equipment'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'Charge': ChargeObj.toJson(),
        'Equipment': EquipmentObj.toJson(),
      };
}

class TotalCharge {
  final double EstimatedTotalAmount;
  final double RateTotalAmount;

  TotalCharge({
    required this.EstimatedTotalAmount,
    required this.RateTotalAmount,
  });

  factory TotalCharge.fromJson(Map<String, dynamic> json) => TotalCharge(
        EstimatedTotalAmount:
            (json['EstimatedTotalAmount'] as num).toDouble(),
        RateTotalAmount: (json['RateTotalAmount'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'EstimatedTotalAmount': EstimatedTotalAmount,
        'RateTotalAmount': RateTotalAmount,
      };
}

class QuotationData {
  final int total;
  final String PickUpLocation;
  final String ReturnLocation;
  final String PickUpDateTime;
  final String ReturnDateTime;
  final List<VehicleStatus> Vehicles;
  final List<OptionalItem> optionals;
  // JSON usa "TotalCharge"
  final TotalCharge TotalChargeJson;

  QuotationData({
    required this.total,
    required this.PickUpLocation,
    required this.ReturnLocation,
    required this.PickUpDateTime,
    required this.ReturnDateTime,
    required this.Vehicles,
    required this.optionals,
    required this.TotalChargeJson,
  });

  factory QuotationData.fromJson(Map<String, dynamic> json) => QuotationData(
        total: (json['total'] as num).toInt(),
        PickUpLocation: json['PickUpLocation'] as String,
        ReturnLocation: json['ReturnLocation'] as String,
        PickUpDateTime: json['PickUpDateTime'] as String,
        ReturnDateTime: json['ReturnDateTime'] as String,
        Vehicles: (json['Vehicles'] as List<dynamic>)
            .map((e) => VehicleStatus.fromJson(e as Map<String, dynamic>))
            .toList(),
        optionals: (json['optionals'] as List<dynamic>? ?? [])
            .map((e) => OptionalItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        TotalChargeJson: TotalCharge.fromJson(
            json['TotalCharge'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'total': total,
        'PickUpLocation': PickUpLocation,
        'ReturnLocation': ReturnLocation,
        'PickUpDateTime': PickUpDateTime,
        'ReturnDateTime': ReturnDateTime,
        'Vehicles': Vehicles.map((e) => e.toJson()).toList(),
        'optionals': optionals.map((e) => e.toJson()).toList(),
        'TotalCharge': TotalChargeJson.toJson(),
      };
}

class QuotationResponse {
  final QuotationData data;

  QuotationResponse({required this.data});

  factory QuotationResponse.fromJson(Map<String, dynamic> json) =>
      QuotationResponse(
        data: QuotationData.fromJson(json['data'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {'data': data.toJson()};
}

class QuotationRequest {
  final String dropOffLocation;
  final String endDate; // ISO-8601 con Z
  final String pickupLocation;
  final String startDate; // ISO-8601 con Z
  final dynamic age; // int o string
  final String? channel;
  final bool showPics;
  final bool showOptionalImage;
  final bool showVehicleParameter;
  final bool showVehicleExtraImage;
  final String? agreementCoupon;
  final dynamic discountValueWithoutVat; // string o double
  final String? macroDescription;
  final bool showBookingDiscount;
  final bool? isYoungDriverAge;
  final bool? isSeniorDriverAge;

  QuotationRequest({
    required this.dropOffLocation,
    required this.endDate,
    required this.pickupLocation,
    required this.startDate,
    this.age,
    this.channel,
    this.showPics = false,
    this.showOptionalImage = false,
    this.showVehicleParameter = false,
    this.showVehicleExtraImage = false,
    this.agreementCoupon,
    this.discountValueWithoutVat,
    this.macroDescription,
    this.showBookingDiscount = false,
    this.isYoungDriverAge,
    this.isSeniorDriverAge,
  });

  Map<String, dynamic> toJson() => {
        'dropOffLocation': dropOffLocation,
        'endDate': endDate,
        'pickupLocation': pickupLocation,
        'startDate': startDate,
        if (age != null) 'age': age,
        if (channel != null) 'channel': channel,
        'showPics': showPics,
        'showOptionalImage': showOptionalImage,
        'showVehicleParameter': showVehicleParameter,
        'showVehicleExtraImage': showVehicleExtraImage,
        if (agreementCoupon != null) 'agreementCoupon': agreementCoupon,
        if (discountValueWithoutVat != null)
          'discountValueWithoutVat': discountValueWithoutVat,
        if (macroDescription != null) 'macroDescription': macroDescription,
        'showBookingDiscount': showBookingDiscount,
        if (isYoungDriverAge != null) 'isYoungDriverAge': isYoungDriverAge,
        if (isSeniorDriverAge != null) 'isSeniorDriverAge': isSeniorDriverAge,
      };
}

/* ------ Damages ------ */

class Damage {
  final String? description;
  final String? damageType;
  final String? damageDictionary;
  final int? x;
  final int? y;
  final double? percentage_x;
  final double? percentage_y;

  Damage({
    this.description,
    this.damageType,
    this.damageDictionary,
    this.x,
    this.y,
    this.percentage_x,
    this.percentage_y,
  });

  factory Damage.fromJson(Map<String, dynamic> json) => Damage(
        description: json['description'] as String?,
        damageType: json['damageType'] as String?,
        damageDictionary: json['damageDictionary'] as String?,
        x: (json['x'] as num?)?.toInt(),
        y: (json['y'] as num?)?.toInt(),
        percentage_x: (json['percentage_x'] as num?)?.toDouble(),
        percentage_y: (json['percentage_y'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (description != null) 'description': description,
        if (damageType != null) 'damageType': damageType,
        if (damageDictionary != null) 'damageDictionary': damageDictionary,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (percentage_x != null) 'percentage_x': percentage_x,
        if (percentage_y != null) 'percentage_y': percentage_y,
      };
}

class WireframeImage {
  final String image;
  final int height;
  final int width;

  WireframeImage({required this.image, required this.height, required this.width});

  factory WireframeImage.fromJson(Map<String, dynamic> json) => WireframeImage(
        image: json['image'] as String,
        height: (json['height'] as num).toInt(),
        width: (json['width'] as num).toInt(),
      );

  Map<String, dynamic> toJson() =>
      {'image': image, 'height': height, 'width': width};
}

class DamagesData {
  final List<Damage> damages;
  final WireframeImage wireframeImage;

  DamagesData({required this.damages, required this.wireframeImage});

  factory DamagesData.fromJson(Map<String, dynamic> json) => DamagesData(
        damages: (json['damages'] as List<dynamic>)
            .map((e) => Damage.fromJson(e as Map<String, dynamic>))
            .toList(),
        wireframeImage: WireframeImage.fromJson(
            json['wireframeImage'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'damages': damages.map((e) => e.toJson()).toList(),
        'wireframeImage': wireframeImage.toJson(),
      };
}

class DamagesResponse {
  final DamagesData data;

  DamagesResponse({required this.data});

  factory DamagesResponse.fromJson(Map<String, dynamic> json) =>
      DamagesResponse(
        data: DamagesData.fromJson(json['data'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {'data': data.toJson()};
}
