import 'dart:convert';

class InitialConfig {
  final int step; // 1..4
  final String pickupLocation;
  final String dropoffLocation;
  final DateTime start;
  final DateTime end;
  final int? age;
  final String? coupon;
  final String? channel;
  final String? vehicleId; // per step ≥ 2
  final List<InitialExtra> extras; // per step ≥ 3

  // Conserviamo input originale (deeplink) o, nel flusso manuale, possiamo
  // popolarlo con toJson() per mostrarti comunque un JSON in ConfirmPage.
  final Map<String, dynamic>? originalMap;
  final String? originalBase64;

  InitialConfig({
    required this.step,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.start,
    required this.end,
    this.age,
    this.coupon,
    this.channel,
    this.vehicleId,
    this.extras = const [],
    this.originalMap,
    this.originalBase64,
  });

  factory InitialConfig.fromJson(Map<String, dynamic> m) => InitialConfig(
        step: (m['step'] as num?)?.toInt() ?? 1,
        pickupLocation: m['pickupLocation'] as String,
        dropoffLocation: m['dropoffLocation'] as String,
        start: DateTime.parse(m['start'] as String),
        end: DateTime.parse(m['end'] as String),
        age: (m['age'] as num?)?.toInt(),
        coupon: m['coupon'] as String?,
        channel: m['channel'] as String?,
        vehicleId: m['vehicleId']?.toString(),
        extras: ((m['extras'] as List?) ?? const [])
            .map((e) => InitialExtra.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        originalMap: m,
      );

  static InitialConfig? fromBase64Url(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      final norm = b64.replaceAll('-', '+').replaceAll('_', '/');
      final pad = '=' * ((4 - norm.length % 4) % 4);
      final bytes = base64.decode(norm + pad);
      final m = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final cfg = InitialConfig.fromJson(m);
      return cfg.copyWith(originalBase64: b64);
    } catch (_) {
      return null;
    }
  }

  /// NEW: factory per il **flusso manuale** (Step 1 appena fatta la quotation).
  factory InitialConfig.fromManual({
    required String pickupCode,
    required String dropoffCode,
    required DateTime startUtc,
    required DateTime endUtc,
    int? age,
    String? coupon,
    String? channel,
    int initialStep = 2, // dopo la ricerca siamo in Results (Step 2)
  }) {
    final cfg = InitialConfig(
      step: initialStep,
      pickupLocation: pickupCode,
      dropoffLocation: dropoffCode,
      start: startUtc,
      end: endUtc,
      age: age,
      coupon: coupon,
      channel: channel,
      vehicleId: null,
      extras: const [],
      originalMap: null, // lo compileremo subito sotto
      originalBase64: null,
    );
    // Compiliamo originalMap con il toJson per avere un JSON da mostrare
    return cfg.withOriginalFromSelf();
  }

  /// Serializzazione coerente (utile anche per riempire originalMap in manuale).
  Map<String, dynamic> toJson() => {
        'step': step,
        'pickupLocation': pickupLocation,
        'dropoffLocation': dropoffLocation,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        if (age != null) 'age': age,
        if (coupon != null) 'coupon': coupon,
        if (channel != null) 'channel': channel,
        if (vehicleId != null) 'vehicleId': vehicleId,
        if (extras.isNotEmpty) 'extras': extras.map((e) => e.toJson()).toList(),
      };

  /// NEW: converte la configurazione in parametri di query per la webapp risultati.
  ///
  /// Esempio URL:
  ///   https://www.mysite.com/result_page?pickup=...&dropoff=...&start=...&end=...&age=...
  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      'pickup': pickupLocation,
      'dropoff': dropoffLocation,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'step': step.toString(),
    };

    if (age != null) {
      params['age'] = age!.toString();
    }
    if (coupon != null && coupon!.isNotEmpty) {
      params['coupon'] = coupon!;
    }
    if (channel != null && channel!.isNotEmpty) {
      params['channel'] = channel!;
    }
    if (vehicleId != null && vehicleId!.isNotEmpty) {
      params['vehicleId'] = vehicleId!;
    }

    // Nota: extras, originalMap e originalBase64 NON sono inclusi nella query string
    // perché complessi; se servisse passarli si può usare toBase64Url() in un
    // singolo parametro, es: cfg=<base64>.

    return params;
  }

  /// NEW: serializza l'intera configurazione in una stringa base64 URL-safe,
  /// simmetrica rispetto a fromBase64Url().
  ///
  /// Utile se vuoi passare tutta la config in un solo parametro di query:
  ///   final cfgParam = cfg.toBase64Url();
  ///   Uri.https('www.mysite.com', '/result_page', {'cfg': cfgParam});
  String toBase64Url() {
    final jsonStr = jsonEncode(toJson());
    final bytes = utf8.encode(jsonStr);
    final b64 = base64.encode(bytes);
    final urlSafe =
        b64.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
    return urlSafe;
  }

  /// copyWith comodo per aggiornare lo step, il vehicleId, gli extra, ecc.
  InitialConfig copyWith({
    int? step,
    String? pickupLocation,
    String? dropoffLocation,
    DateTime? start,
    DateTime? end,
    int? age,
    String? coupon,
    String? channel,
    String? vehicleId,
    List<InitialExtra>? extras,
    Map<String, dynamic>? originalMap,
    String? originalBase64,
  }) {
    return InitialConfig(
      step: step ?? this.step,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      start: start ?? this.start,
      end: end ?? this.end,
      age: age ?? this.age,
      coupon: coupon ?? this.coupon,
      channel: channel ?? this.channel,
      vehicleId: vehicleId ?? this.vehicleId,
      extras: extras ?? this.extras,
      originalMap: originalMap ?? this.originalMap,
      originalBase64: originalBase64 ?? this.originalBase64,
    );
  }

  /// Se originalMap è nullo, lo riempiamo con il nostro toJson().
  InitialConfig withOriginalFromSelf() {
    return originalMap == null ? copyWith(originalMap: toJson()) : this;
  }
}

/// Args tipizzati per passare InitialConfig ad AdvancedSearchPage
class AdvancedSearchArgsFromConfig {
  final InitialConfig cfg;
  const AdvancedSearchArgsFromConfig(this.cfg);
}

class InitialExtra {
  final String code; // mappabile su EquipType o Description
  final int qty; // default 1
  final bool perDay; // solo suggerimento UI

  InitialExtra({
    required this.code,
    this.qty = 1,
    this.perDay = true,
  });

  factory InitialExtra.fromJson(Map<String, dynamic> m) => InitialExtra(
        code: m['code']?.toString() ?? '',
        qty: (m['qty'] as num?)?.toInt() ?? 1,
        perDay: (m['perDay'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'qty': qty,
        'perDay': perDay,
      };
}
