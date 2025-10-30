/// Adattatore resiliente per l'offerta a partire dal JSON di quotations
/// (compatibile con Vehicle.seats/doors/transmission/fuel e aggiunge id/code)
import 'dart:convert';

class Offer {
  final Map<String, dynamic> raw;

  // Identificativi (NUOVI)
  final String? id;            // Vehicle.id (string) se presente
  final String? vehicleId;     // alias utile == id, o Code/nationalCode se manca id
  final String? code;          // Vehicle.Code (ACRISS o simile)
  final String? nationalCode;  // Vehicle.nationalCode

  // Dati UI
  final String? status;        // "Available" | "Unavailable"
  final String? name;          // VehMakeModel[0].Name | Vehicle.model
  final String? group;         // Vehicle.VendorCarMacroGroup
  final String? type;          // Vehicle.VendorCarType
  final String? acriss;        // == code
  final String? transmission;  // "Manuale"/"Automatico"/string raw
  final String? fuel;          // "Benzina"/"Diesel"/"Elettrica"/"Ibrida"/...
  final int? seats;            // Vehicle.seats
  final int? doors;            // Vehicle.doors
  final int? days;             // Reference.calculated.days
  final double? pricePerDay;   // Reference.calculated.base_daily
  final double? total;         // Reference.calculated.total | fallback TotalCharge
  final String? imageUrl;      // groupPic.url

  Offer({
    required this.raw,
    // ids
    this.id,
    this.vehicleId,
    this.code,
    this.nationalCode,
    // ui
    this.status,
    this.name,
    this.group,
    this.type,
    this.acriss,
    this.transmission,
    this.fuel,
    this.seats,
    this.doors,
    this.days,
    this.pricePerDay,
    this.total,
    this.imageUrl,
  });

  static Offer fromJson(Map<String, dynamic> m) {
    final vehicle =
        (m['Vehicle'] is Map) ? (m['Vehicle'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final ref =
        (m['Reference'] is Map) ? (m['Reference'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final calc =
        (ref['calculated'] is Map) ? (ref['calculated'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final makeModels = (vehicle['VehMakeModel'] is List)
        ? List<Map<String, dynamic>>.from(vehicle['VehMakeModel'] as List)
        : <Map<String, dynamic>>[];
    final groupPic =
        (m['groupPic'] is Map) ? (m['groupPic'] as Map).cast<String, dynamic>() : const <String, dynamic>{};

    // ---------- Identificativi ----------
    final String? id = vehicle['id']?.toString() ?? vehicle['Id']?.toString();
    final String? code = (vehicle['Code'] ?? vehicle['code'])?.toString();
    final String? nationalCode = (vehicle['nationalCode'] ?? vehicle['NationalCode'])?.toString();
    // vehicleId come alias flessibile (prima id, poi code, poi nationalCode)
    final String? vehicleId = id ?? code ?? nationalCode;

    // ---------- Nome / modello ----------
    final String? name = (makeModels.isNotEmpty
            ? makeModels.first['Name']?.toString()
            : null) ??
        vehicle['model']?.toString() ??
        vehicle['brand']?.toString();

    // ---------- Trasmissione ----------
    String? gear;
    final tRaw = (vehicle['transmission'] ?? vehicle['Transmission'])?.toString();
    if (tRaw != null && tRaw.isNotEmpty) {
      final up = tRaw.toUpperCase();
      gear = (up == 'A')
          ? 'Automatico'
          : (up == 'M')
              ? 'Manuale'
              : tRaw;
    } else if (code != null && code.length >= 3) {
      final ch = code[2].toUpperCase();
      if (ch == 'M') gear = 'Manuale';
      if (ch == 'A') gear = 'Automatico';
    }

    // ---------- Carburante ----------
    String? fuel;
    final fRaw = (vehicle['fuel'] ?? vehicle['Fuel'])?.toString();
    if (fRaw != null && fRaw.isNotEmpty) {
      final up = fRaw.toUpperCase();
      switch (up) {
        case 'PETROL':
        case 'GASOLINE':
          fuel = 'Benzina';
          break;
        case 'DIESEL':
          fuel = 'Diesel';
          break;
        case 'ELECTRIC':
          fuel = 'Elettrica';
          break;
        case 'HYBRID':
          fuel = 'Ibrida';
          break;
        default:
          fuel = fRaw; // lascia com'è (metano, gpl, ecc.)
      }
    }
    if (fuel == null && code != null && code.length >= 4) {
      final ch = code[3].toUpperCase();
      fuel = (ch == 'E')
          ? 'Elettrica'
          : (ch == 'H')
              ? 'Ibrida'
              : null;
    }
    fuel ??= ((vehicle['VendorCarMacroGroup']?.toString().toUpperCase() ?? '').contains('ELECTRIC') ||
              (name?.toLowerCase() ?? '').contains('electric'))
        ? 'Elettrica'
        : null; // se non deducibile, lascia null e la UI può mostrare un placeholder

    // ---------- Seats / doors ----------
    final seats = _toInt(vehicle['seats'] ?? vehicle['Seats'] ?? vehicle['Posti']);
    final doors = _toInt(vehicle['doors'] ?? vehicle['Doors'] ?? vehicle['Porte']);

    // ---------- Prezzi / giorni ----------
    final int? days = _toInt(calc['days']);
    double? pricePerDay = _toDouble(calc['base_daily']);
    double? total = _toDouble(calc['total']);

    // fallback: TotalCharge a livello di VehicleStatus/raw
    if (total == null && m['TotalCharge'] is Map) {
      final tc = (m['TotalCharge'] as Map).cast<String, dynamic>();
      total = _toDouble(tc['RateTotalAmount']) ?? _toDouble(tc['EstimatedTotalAmount']);
    }
    // se manca base_daily ma ho total & days → calcola approx.
    if (pricePerDay == null && total != null && days != null && days > 0) {
      pricePerDay = total / days;
    }

    return Offer(
      raw: m,
      // ids
      id: id,
      vehicleId: vehicleId,
      code: code,
      nationalCode: nationalCode,
      // ui
      status: m['Status']?.toString(),
      name: name,
      group: vehicle['VendorCarMacroGroup']?.toString(),
      type: vehicle['VendorCarType']?.toString(),
      acriss: code,
      transmission: gear,
      fuel: fuel,
      seats: seats,
      doors: doors,
      days: days,
      pricePerDay: pricePerDay,
      total: total,
      imageUrl: groupPic['url']?.toString() ?? vehicle['imageUrl']?.toString() ?? vehicle['image_url']?.toString(),
    );
  }
}

/* ----------- small utils ----------- */

double? _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

// debug helper facoltativo
String pretty(Object o) => const JsonEncoder.withIndent('  ').convert(o);
