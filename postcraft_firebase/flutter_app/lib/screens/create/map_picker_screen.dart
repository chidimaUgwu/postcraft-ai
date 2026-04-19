// lib/screens/create/map_picker_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/common_widgets.dart';

/// Result returned by [MapPickerScreen] — the exact coordinates the user
/// confirmed plus a human-readable address string.
class MapPickResult {
  final double latitude;
  final double longitude;
  final String formatted;
  const MapPickResult({
    required this.latitude,
    required this.longitude,
    required this.formatted,
  });
}

/// Uber-style map picker. The marker is anchored to the centre of the
/// screen — the user drags the map under it and the reverse-geocoded
/// address updates as they pan. Free OpenStreetMap tiles, no API key.
class MapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // Sensible default if we have no initial location and can\'t get GPS —
  // roughly centred on West Africa.
  static const LatLng _fallbackCenter = LatLng(9.0820, 8.6753);

  LatLng _center = _fallbackCenter;
  double _zoom = 15;
  String _address = 'Move the map to pick a location';
  bool _resolvingAddress = false;
  bool _gettingGps = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) _address = widget.initialAddress!;
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _center = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      // Reverse-geocode the seed coords on first frame.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resolveAddress(_center));
    } else {
      // Try to jump to current GPS — user can still override.
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyLocation());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Debounce the reverse-geocode so we only fire once the user has stopped
  /// panning for 400 ms.
  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _center = camera.center;
    _zoom = camera.zoom;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _resolveAddress(_center);
    });
  }

  Future<void> _resolveAddress(LatLng pt) async {
    if (!mounted) return;
    setState(() => _resolvingAddress = true);
    try {
      final placemarks =
          await placemarkFromCoordinates(pt.latitude, pt.longitude);
      if (!mounted) return;
      if (placemarks.isEmpty) {
        setState(() {
          _address = '${pt.latitude.toStringAsFixed(5)}, '
              '${pt.longitude.toStringAsFixed(5)}';
          _resolvingAddress = false;
        });
        return;
      }
      final p = placemarks.first;
      final parts = <String>[
        if (p.street != null && p.street!.isNotEmpty) p.street!,
        if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
        if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
        if (p.administrativeArea != null &&
            p.administrativeArea!.isNotEmpty)
          p.administrativeArea!,
        if (p.country != null && p.country!.isNotEmpty) p.country!,
      ];
      setState(() {
        _address = parts.isEmpty
            ? '${pt.latitude.toStringAsFixed(5)}, ${pt.longitude.toStringAsFixed(5)}'
            : parts.join(', ');
        _resolvingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address = '${pt.latitude.toStringAsFixed(5)}, '
            '${pt.longitude.toStringAsFixed(5)}';
        _resolvingAddress = false;
      });
    }
  }

  /// Search-by-address — forward-geocode the query and fly the map to the
  /// first hit.
  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    _searchFocus.unfocus();
    try {
      final locations = await locationFromAddress(q);
      if (!mounted || locations.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No match. Try adding city / country.'),
            backgroundColor: AppTheme.error,
          ));
        }
        return;
      }
      final hit = locations.first;
      final pt = LatLng(hit.latitude, hit.longitude);
      _mapController.move(pt, 16);
      _center = pt;
      await _resolveAddress(pt);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not search that address.'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() => _gettingGps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() => _gettingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enable location services on your device.'),
          backgroundColor: AppTheme.error,
        ));
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _gettingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permission denied.'),
          backgroundColor: AppTheme.error,
        ));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      final pt = LatLng(pos.latitude, pos.longitude);
      _mapController.move(pt, 17);
      _center = pt;
      setState(() => _gettingGps = false);
      await _resolveAddress(pt);
    } catch (_) {
      if (!mounted) return;
      setState(() => _gettingGps = false);
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      MapPickResult(
        latitude: _center.latitude,
        longitude: _center.longitude,
        formatted: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick location on map'),
        leading: const BackButton(),
      ),
      body: Stack(children: [
        // ── MAP ───────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _zoom,
            onPositionChanged: _onMapMoved,
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.postcraft_ai',
              maxZoom: 19,
            ),
          ],
        ),

        // ── CENTER PIN (Uber style — pin is fixed, map moves under it) ─
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Icon(Icons.location_pin,
                  size: 48, color: AppTheme.primary),
            ),
          ),
        ),

        // ── SEARCH BAR ────────────────────────────────────────
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Search any city or address…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        }),
                filled: true,
                fillColor: AppTheme.surfaceOf(context),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),

        // ── LOCATE-ME FAB ─────────────────────────────────────
        Positioned(
          right: 16,
          bottom: 180,
          child: FloatingActionButton(
            heroTag: 'locate-me',
            backgroundColor: AppTheme.surfaceOf(context),
            foregroundColor: AppTheme.primary,
            onPressed: _gettingGps ? null : _goToMyLocation,
            child: _gettingGps
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary))
                : const Icon(Icons.my_location),
          ),
        ),

        // ── BOTTOM ADDRESS CARD + CONFIRM ────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding:
                  const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    const Icon(Icons.place,
                        color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resolvingAddress
                            ? 'Resolving address…'
                            : _address,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface(context)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceMuted(context)),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Use this location'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// Re-export a helper to keep import sites minimal.
class SectionLabelSpacer extends StatelessWidget {
  const SectionLabelSpacer({super.key});
  @override
  Widget build(BuildContext context) =>
      const SectionLabel('Pick on map', subtitle: null);
}
