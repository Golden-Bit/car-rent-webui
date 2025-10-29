import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:flutter/material.dart';
import '../../data/myrent_repository.dart';

class LocationDropdown extends StatefulWidget {
  final String hintText;
  final void Function(Location) onSelected;
  final Location? initialValue;
  final bool dense;

  const LocationDropdown({
    super.key,
    required this.hintText,
    required this.onSelected,
    this.initialValue,
    this.dense = false,
  });

  @override
  State<LocationDropdown> createState() => _LocationDropdownState();
}

class _LocationDropdownState extends State<LocationDropdown> {
  final repo = MyrentRepository();

  final TextEditingController _displayCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  final LayerLink _link = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  Size _fieldSize = const Size(0, 0);

  List<Location> _all = [];
  List<Location> _filtered = [];
  Location? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LocationDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Aggiorna testo se cambia il valore iniziale dall'esterno
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != null) {
      _selected = widget.initialValue;
      _displayCtrl.text = _labelFor(_selected!);
    }
  }

  @override
  void dispose() {
    _closeOverlay();
    _displayCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _all = await repo.fetchLocations();
      if (widget.initialValue != null) {
        _selected = widget.initialValue;
        _displayCtrl.text = _labelFor(_selected!);
      }
      setState(() {
        _filtered = _all;
      });
    } catch (e) {
      // feedback semplice
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento sedi: $e')),
        );
      }
    }
  }

  IconData _iconFor(Location loc) =>
      loc.isAirport ? Icons.local_airport : Icons.location_city;

  String _labelFor(Location loc) =>
      '${loc.locationName.toUpperCase()}${loc.isAirport ? " AEROPORTO" : ""}';

  void _openOverlay() {
    if (_isOpen) return;

    final box =
        _fieldKey.currentContext!.findRenderObject() as RenderBox; // target
    _fieldSize = box.size;

    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context, rootOverlay: true)!.insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeOverlay() {
    if (!_isOpen) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _searchCtrl.clear();
    setState(() {
      _filtered = _all;
      _isOpen = false;
    });
  }

  void _toggleOverlay() => _isOpen ? _closeOverlay() : _openOverlay();

  OverlayEntry _buildOverlayEntry() {
    final theme = Theme.of(context);
    const double panelMaxHeight = 420;

    return OverlayEntry(
      maintainState: true,
      builder: (context) {
        return Stack(
          children: [
            // tappo trasparente per chiudere cliccando fuori
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeOverlay,
                behavior: HitTestBehavior.translucent,
              ),
            ),

            // pannello ancorato sotto al campo
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, _fieldSize.height + 4),
              child: Material(
                elevation: 8,
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _fieldSize.width,
                    minWidth: _fieldSize.width,
                    maxHeight: panelMaxHeight,
                  ),
                  child: SizedBox(
                    width: _fieldSize.width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // barra di ricerca
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Cerca località',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (q) {
                              setState(() {
                                _filtered = _all
                                    .where(
                                      (l) =>
                                          l.locationName
                                              .toLowerCase()
                                              .contains(q.toLowerCase()) ||
                                          (l.locationCity ?? '')
                                              .toLowerCase()
                                              .contains(q.toLowerCase()) ||
                                          l.locationCode
                                              .toLowerCase()
                                              .contains(q.toLowerCase()),
                                    )
                                    .toList();
                              });
                            },
                          ),
                        ),
                        const Divider(height: 1),

                        // lista voci
                        Flexible(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final loc = _filtered[i];
                              return ListTile(
                                leading: Icon(
                                  _iconFor(loc),
                                  color: theme.colorScheme.primary,
                                ),
                                title: Text(_labelFor(loc)),
                                subtitle: (loc.locationCity != null)
                                    ? Text(
                                        (loc.locationCity ?? '')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.black54),
                                      )
                                    : null,
                                onTap: () {
                                  _selected = loc;
                                  _displayCtrl.text = _labelFor(loc);
                                  widget.onSelected(loc);
                                  _closeOverlay();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: TextField(
        key: _fieldKey,
        controller: _displayCtrl,
        readOnly: true,
        onTap: _toggleOverlay,
        decoration: InputDecoration(
          hintText: widget.hintText,
          suffixIcon: Icon(_isOpen ? Icons.expand_less : Icons.expand_more),
        ),
      ),
    );
  }
}
