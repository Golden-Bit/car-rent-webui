/// Adattatore resiliente per l'offerta a partire dal JSON di quotations
/// (compatibile con l'API aggiornata: Vehicle.seats/doors/transmission/fuel)
import 'dart:convert';

class Offer {
  final Map<String, dynamic> raw;

  final String? status;       // "Available" | "Unavailable"
  final String? name;         // Vehicle.VehMakeModel[0].Name | Vehicle.model
  final String? group;        // Vehicle.VendorCarMacroGroup
  final String? type;         // Vehicle.VendorCarType
  final String? acriss;       // Vehicle.Code
  final String? transmission; // "Manuale"/"Automatico"
  final String? fuel;         // "Benzina"/"Diesel"/"Elettrica"/"Ibrida"/...
  final int? seats;           // Vehicle.seats
  final int? doors;           // Vehicle.doors
  final int? days;            // Reference.calculated.days
  final double? pricePerDay;  // Reference.calculated.base_daily
  final double? total;        // Reference.calculated.total
  final String? imageUrl;     // groupPic.url

  Offer({
    required this.raw,
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
        (m['Vehicle'] is Map) ? m['Vehicle'] as Map : const <String, dynamic>{};
    final ref =
        (m['Reference'] is Map) ? m['Reference'] as Map : const <String, dynamic>{};
    final calc =
        (ref['calculated'] is Map) ? ref['calculated'] as Map : const <String, dynamic>{};
    final makeModels = (vehicle['VehMakeModel'] is List)
        ? List<Map<String, dynamic>>.from(vehicle['VehMakeModel'])
        : <Map<String, dynamic>>[];
    final groupPic =
        (m['groupPic'] is Map) ? m['groupPic'] as Map : const <String, dynamic>{};

    final acriss = vehicle['Code']?.toString();
    final name = (makeModels.isNotEmpty
            ? makeModels.first['Name']?.toString()
            : null) ??
        vehicle['model']?.toString();

    // trasmissione
    String? gear;
    final tRaw = (vehicle['transmission'] ?? vehicle['Transmission'])?.toString();
    if (tRaw != null && tRaw.isNotEmpty) {
      gear = (tRaw.toUpperCase() == 'A') ? 'Automatico' : (tRaw.toUpperCase() == 'M') ? 'Manuale' : tRaw;
    } else if (acriss != null && acriss.length >= 3) {
      final ch = acriss[2].toUpperCase();
      if (ch == 'M') gear = 'Manuale';
      if (ch == 'A') gear = 'Automatico';
    }

    // carburante
    String? fuel;
    final fRaw = (vehicle['fuel'] ?? vehicle['Fuel'])?.toString().toUpperCase();
    if (fRaw != null) {
      switch (fRaw) {
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
          fuel = fRaw;
      }
    }
    if (fuel == null && acriss != null && acriss.length >= 4) {
      final ch = acriss[3].toUpperCase();
      fuel = (ch == 'E')
          ? 'Elettrica'
          : (ch == 'H')
              ? 'Ibrida'
              : null;
    }
    fuel ??= ((vehicle['VendorCarMacroGroup']?.toString().toUpperCase() ?? '')
                .contains('ELECTRIC') ||
            (name?.toLowerCase() ?? '').contains('electric'))
        ? 'Elettrica'
        : 'Benzina/Diesel';

    // seats/doors con fallback
    final seats = _toInt(vehicle['seats'] ?? vehicle['Seats'] ?? vehicle['Posti']);
    final doors = _toInt(vehicle['doors'] ?? vehicle['Doors'] ?? vehicle['Porte']);

    return Offer(
      raw: m,
      status: m['Status']?.toString(),
      name: name,
      group: vehicle['VendorCarMacroGroup']?.toString(),
      type: vehicle['VendorCarType']?.toString(),
      acriss: acriss,
      transmission: gear,
      fuel: fuel,
      seats: seats,
      doors: doors,
      days: _toInt(calc['days']),
      pricePerDay: _toDouble(calc['base_daily']),
      total: _toDouble(calc['total']),
      imageUrl: groupPic['url']?.toString(),
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
