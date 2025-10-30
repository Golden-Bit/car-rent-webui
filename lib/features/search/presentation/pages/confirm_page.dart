import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/top_nav_bar.dart';
import '../../../../core/deeplink/initial_config.dart';
import '../../../results/widgets/steps_header.dart';
import '../../../results/models/offer_adapter.dart'; // <-- per group/name/image

/// Args per navigare a ConfirmPage con la config già risolta.
/// Consigliato passare anche dataJson/selected/selectedExtras per uno StepHeader ricco.
class ConfirmArgs {
  final InitialConfig? cfg;

  /// Dati “ricchi” dal flusso manuale (Results/Extras)
  final Map<String, dynamic>? dataJson;
  final Offer? selected;                       // vettura scelta (group, name, image)
  final List<InitialExtra>? selectedExtras;    // extra scelti (codici)

  const ConfirmArgs({
    this.cfg,
    this.dataJson,
    this.selected,
    this.selectedExtras,
  });
}

class ConfirmPage extends StatefulWidget {
  static const routeName = '/confirm';
  const ConfirmPage({super.key});

  @override
  State<ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<ConfirmPage> {
  static const kBrandDark = Color(0xFFE2470C);

  // Editor + serializzazione
  late final TextEditingController _editorCtrl;
  String? _runtimeB64;     // base64url calcolato dall'editor
  String? _queryFragment;  // ?cfg=...
  String? _fullUrl;        // URL completo con cfg
  String? _error;          // errore di parsing/validazione
  String? _originalB64;    // base64 originale del deeplink (se presente)

  // Dati “ricchi” se arriviamo dal flusso manuale
  Map<String, dynamic>? _dataJson;
  Offer? _selected;
  List<InitialExtra> _selectedExtras = const [];

  // Campi visualizzati nello StepsHeader
  String? _step1Pickup;
  String? _step1Dropoff;
  String? _step1Start;
  String? _step1End;

  String? _step2Title;     // group o vehicle name
  String? _step2Subtitle;  // name
  String? _step2Thumb;     // imageUrl
  String? _step2Price;     // totale dal dataJson se disponibile

  List<String> _step3Extras = const [];
  String? _step3ExtrasTotal;

  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _editorCtrl = TextEditingController(text: ''); // contenuto verrà impostato in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;

    // 1) Args o fallback ?cfg=...
    final args = ModalRoute.of(context)?.settings.arguments;
    final ConfirmArgs? confirm = (args is ConfirmArgs) ? args : null;

    final InitialConfig? cfg = confirm?.cfg ?? _readConfigFromUrl();

    // 2) Preleva dataJson/selected/extras dal flusso manuale se presenti
    _dataJson = confirm?.dataJson;
    _selected = confirm?.selected;
    _selectedExtras = confirm?.selectedExtras ?? const [];

    // 3) JSON "vivo" iniziale nell’editor:
    final Map<String, dynamic>? json = cfg?.toJson();
    final prettyJson = (json != null)
        ? const JsonEncoder.withIndent('  ').convert(json)
        : const JsonEncoder.withIndent('  ').convert({
            'step': 4,
            'pickupLocation': 'XXX',
            'dropoffLocation': 'XXX',
            'start': DateTime.now().toUtc().toIso8601String(),
            'end': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
            'age': 30,
            'channel': 'WEB_APP',
            'vehicleId': 'ID_O_CODICE_VEICOLO',
            'extras': [
              {'code': 'GPS', 'qty:': 1, 'perDay': true},
            ],
          });
    _editorCtrl.text = prettyJson;

    _originalB64 = cfg?.originalBase64;

    // 4) Popola StepsHeader: se ho dataJson/selected, uso quelli;
    //    altrimenti provo a idratare dai campi del JSON dell’editor.
    if (_dataJson != null) {
      _hydrateHeaderFromDataJson(_dataJson!, _selected, _selectedExtras);
    } else {
      _recomputeFromEditor(); // calcola base64 + header dai soli campi del JSON
    }

    // 5) In ogni caso calcola il base64/URL iniziali
    _recomputeFromEditor();

    _hydrated = true;
  }

  @override
  void dispose() {
    _editorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopNavBar(),
      body: Column(
        children: [
          // ---------- STEPS HEADER (Step 4) ----------
          StepsHeader(
            currentStep: 4,
            accent: kBrandDark,
            step1Pickup: _step1Pickup,
            step1Dropoff: _step1Dropoff,
            step1Start: _step1Start,
            step1End: _step1End,
            step2Title: _step2Title,
            step2Subtitle: _step2Subtitle,
            step2Thumb: _step2Thumb,
            step2Price: _step2Price,
            step3Extras: _step3Extras,
            step3ExtrasTotal: _step3ExtrasTotal,
            onTapStep: (n) {
              if (n == 3 || n == 2 || n == 1) {
                Navigator.of(context).maybePop();
              }
            },
          ),

          // ---------- CONTENUTO ----------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Config (JSON) — editabile:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),

                  // EDITOR: area monospaziata editabile
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 0.8,
                        ),
                      ),
                      child: TextField(
                        controller: _editorCtrl,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.black, // testo nero
                          fontSize: 13.5,
                        ),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Barra azioni + stato validazione
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _recomputeFromEditor,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Aggiorna'),
                      ),
                      const SizedBox(width: 12),
                      if (_error != null)
                        Flexible(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        )
                      else
                        const Text('OK', style: TextStyle(color: Colors.green)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Frammento query pronto (incolla in URL):',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _CopyLine(text: _queryFragment ?? '—'),

                  const SizedBox(height: 12),
                  const Text(
                    'URL completo con cfg (stessa pagina):',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _CopyLine(text: _fullUrl ?? '—'),

                  const SizedBox(height: 12),
                  const Text(
                    'Base64 originale del deeplink (se presente):',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _CopyLine(text: _originalB64 ?? '—'),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: FilledButton(
                      onPressed: () {
                        // TODO: invio dati/creazione prenotazione finale
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Conferma (WIP)')),
                        );
                      },
                      child: const Text('Conferma (WIP)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ricalcola base64/URL leggendo il JSON dall’editor
  /// e, se non abbiamo dataJson/selected, aggiorna lo StepHeader da JSON.
  void _recomputeFromEditor() {
    setState(() {
      try {
        _error = null;

        final dynamic parsed = jsonDecode(_editorCtrl.text);
        if (parsed is! Map<String, dynamic>) {
          throw const FormatException('Il JSON di configurazione deve essere un oggetto (dict).');
        }

        if (!parsed.containsKey('step')) {
          throw const FormatException('Campo mancante: "step".');
        }
        if (!parsed.containsKey('pickupLocation') || !parsed.containsKey('dropoffLocation')) {
          throw const FormatException('Campi mancanti: "pickupLocation" e/o "dropoffLocation".');
        }

        _runtimeB64 = _toBase64Url(parsed);

        final uri = kIsWeb ? Uri.base : null;
        _queryFragment = '?cfg=$_runtimeB64';
        _fullUrl = (uri != null)
            ? Uri(
                scheme: uri.scheme,
                host: uri.host,
                port: uri.hasPort ? uri.port : null,
                path: uri.path,
                queryParameters: {'cfg': _runtimeB64!},
                fragment: uri.fragment.isNotEmpty ? uri.fragment : null,
              ).toString()
            : _queryFragment;

        // Se non ho dataJson/selected (arrivo da deeplink puro),
        // idrato header dai soli campi del JSON:
        if (_dataJson == null) {
          _hydrateHeaderFromJson(parsed);
        }
      } catch (e) {
        _runtimeB64 = null;
        _queryFragment = null;
        _fullUrl = null;
        _error = 'Errore JSON: ${e is FormatException ? e.message : e.toString()}';
      }
    });
  }

  /// Idrata lo StepHeader usando i dati “ricchi” del flusso manuale.
  void _hydrateHeaderFromDataJson(
    Map<String, dynamic> data,
    Offer? selected,
    List<InitialExtra> chosen,
  ) {
    // Step 1
    _step1Pickup = _displayLocationName(
      data,
      codeKey: 'PickUpLocation',
      nameCandidates: const [
        'PickUpLocationName', 'pickupName', 'PickupName', 'PickupCity', 'pickupCity'
      ],
    ) ?? data['PickUpLocation']?.toString();

    _step1Dropoff = _displayLocationName(
      data,
      codeKey: 'ReturnLocation',
      nameCandidates: const [
        'ReturnLocationName', 'returnName', 'ReturnCity', 'returnCity'
      ],
    ) ?? data['ReturnLocation']?.toString();

    _step1Start = _fmtDate(data['PickUpDateTime']?.toString());
    _step1End   = _fmtDate(data['ReturnDateTime']?.toString());

    // Step 2
    _step2Title = selected?.group ?? 'Auto';
    _step2Subtitle = selected?.name ?? '';
    _step2Thumb = selected?.imageUrl;

    // Prova a leggere un totale dal dataJson o dall’offerta
    _step2Price = _formatHeaderPrice(data, selected);

    // Step 3 – etichette da optionals + totale extra
    final labels = <String>[];
    num totalExtra = 0;

    final list = data['optionals'];
    final days = _computeRentalDays(data);
    if (list is List && chosen.isNotEmpty) {
      for (final ch in chosen) {
        // cerca matching per EquipType o Description
        for (final raw in list) {
          final m = (raw as Map).cast<String, dynamic>();
          final equip = (m['Equipment'] as Map?)?.cast<String, dynamic>() ?? const {};
          final charge = (m['Charge'] as Map?)?.cast<String, dynamic>() ?? const {};
          final code = (equip['EquipType'] as String?) ?? (equip['Description'] as String?);
          final title = (equip['Description'] ?? 'Optional').toString();
          final isPerDay = (equip['isMultipliable'] as bool?) ?? true;
          if (code != null && code.toString().toLowerCase() == ch.code.toLowerCase()) {
            labels.add(title);
            final amount = (charge['Amount'] as num?) ?? 0;
            totalExtra += isPerDay ? amount * days : amount;
            break;
          }
        }
      }
    }
    _step3Extras = labels;
    _step3ExtrasTotal = labels.isEmpty ? null : _formatMoney(totalExtra, 'EUR');
  }

  /// Fallback: idrata StepHeader dai soli campi presenti nel JSON editor
  void _hydrateHeaderFromJson(Map<String, dynamic> m) {
    _step1Pickup  = _readString(m['pickupLocation']);
    _step1Dropoff = _readString(m['dropoffLocation']);
    _step1Start   = _fmtDate(_readString(m['start']));
    _step1End     = _fmtDate(_readString(m['end']));

    final vehicleId = _readString(m['vehicleId']);
    _step2Title = (vehicleId?.isNotEmpty == true) ? vehicleId : null;
    _step2Subtitle = null;
    _step2Thumb = null;
    _step2Price = null;

    final extras = <String>[];
    final rawExtras = m['extras'];
    if (rawExtras is List) {
      for (final e in rawExtras) {
        if (e is Map) {
          final em = e.cast<String, dynamic>();
          final code = _readString(em['code']);
          if (code != null && code.trim().isNotEmpty) extras.add(code.trim());
        }
      }
    }
    _step3Extras = extras;
    _step3ExtrasTotal = null;
  }

  /// Fallback: se non riceviamo args, rileggiamo `?cfg=...` dalla URL (solo web).
  InitialConfig? _readConfigFromUrl() {
    if (!kIsWeb) return null;
    try {
      final uri = Uri.base;
      final b64 = uri.queryParameters['cfg'];
      return InitialConfig.fromBase64Url(b64);
    } catch (_) {
      return null;
    }
  }

  /// Serializza una mappa JSON in base64url **senza padding**, come richiesto da `?cfg=...`.
  static String _toBase64Url(Map<String, dynamic> json) {
    final bytes = utf8.encode(jsonEncode(json));
    final b64 = base64UrlEncode(bytes);
    return b64.replaceAll('=', '');
  }

  // --------- helpers visualizzazione/formatting (copiati dagli altri step) ---------

  static String? _readString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.day} ${_monthShortIt(dt.month)}, ${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  static String _monthShortIt(int m) {
    const it = ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'];
    return it[(m - 1).clamp(0, 11)];
  }

  static String? _displayLocationName(
    Map<String, dynamic> m, {
    required String codeKey,
    required List<String> nameCandidates,
  }) {
    for (final k in nameCandidates) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return m[codeKey]?.toString();
  }

  static int _computeRentalDays(Map<String, dynamic> data) {
    try {
      final pick = DateTime.parse(data['PickUpDateTime'] as String);
      final ret  = DateTime.parse(data['ReturnDateTime'] as String);
      final hours = ret.difference(pick).inHours;
      return (hours / 24).ceil().clamp(1, 365);
    } catch (_) {
      return 1;
    }
  }

  static String? _formatHeaderPrice(Map<String, dynamic> dataJson, Offer? selected) {
    String? _fmt(num? amount, String? currencyCode) {
      if (amount == null) return null;
      final symbol = (currencyCode == null || currencyCode == 'EUR') ? '€' : currencyCode;
      try {
        // evitiamo dipendenze da intl qui, formattazione semplice:
        return '$symbol ${amount.toStringAsFixed(2)}';
      } catch (_) {
        return '$symbol ${amount.toStringAsFixed(2)}';
      }
    }

    final tc = (dataJson['TotalCharge'] is Map)
        ? Map<String, dynamic>.from(dataJson['TotalCharge'] as Map)
        : null;

    final num? amountFromData =
        (tc?['RateTotalAmount'] as num?) ?? (tc?['EstimatedTotalAmount'] as num?);
    final String? currFromData = tc?['CurrencyCode'] as String?;

    final formattedFromData = _fmt(amountFromData, currFromData);
    if (formattedFromData != null) return formattedFromData;

    final raw = selected?.raw;
    final tc2 = (raw is Map && raw!['TotalCharge'] is Map)
        ? Map<String, dynamic>.from(raw['TotalCharge'] as Map)
        : null;

    final num? amountFromRaw =
        (tc2?['RateTotalAmount'] as num?) ?? (tc2?['EstimatedTotalAmount'] as num?);
    final String? currFromRaw = tc2?['CurrencyCode'] as String?;

    return _fmt(amountFromRaw, currFromRaw);
  }

  static String _formatMoney(num amount, String? currency) {
    final sym = (currency == null || currency == 'EUR') ? '€' : currency;
    return '$sym ${amount.toStringAsFixed(2)}';
  }
}

/* ===========================
 *  WIDGET DI SUPPORTO: riga copiabile
 * ===========================
 */
class _CopyLine extends StatelessWidget {
  final String text;
  const _CopyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final canCopy = text != '—' && text.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          IconButton(
            tooltip: 'Copia',
            onPressed: canCopy
                ? () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copiato negli appunti')),
                    );
                  }
                : null,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
    );
  }
}
