// lib/screens/create/property_details_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/common_widgets.dart';
import 'map_picker_screen.dart';
import 'platform_selection_screen.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final List<XFile> images;
  final Map<String, Uint8List> imageBytes;
  const PropertyDetailsScreen(
      {super.key, required this.images, required this.imageBytes});
  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _propertyType;
  String _pricePeriod = 'monthly';
  String _compoundType = 'self_compound';
  String _furnishing = 'unfurnished';
  int _bedrooms = 1, _bathrooms = 1, _toilets = 1, _numTenants = 2;
  bool _water = true, _electricity = true, _parking = false;
  bool _gettingLocation = false;
  double? _latitude, _longitude;
  final Set<String> _features = {};

  bool get _canProceed =>
      _titleCtrl.text.isNotEmpty &&
      _priceCtrl.text.isNotEmpty &&
      _propertyType != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _addrCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _postData => {
        'title': _titleCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
        'pricePeriod': _pricePeriod,
        'address': _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'propertyType': _propertyType,
        'compoundType': _compoundType,
        'numTenants': _compoundType == 'shared_compound' ? _numTenants : null,
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        'toilets': _toilets,
        'waterAvailable': _water,
        'electricityAvailable': _electricity,
        'parkingAvailable': _parking,
        'extraFeatures': _features.toList(),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'furnishing': _furnishing,
      };

  Future<void> _getGPSLocation() async {
    setState(() => _gettingLocation = true);
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enable location services on your device.'),
          backgroundColor: Colors.red,
        ));
        setState(() => _gettingLocation = false);
        return;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission denied.'),
            backgroundColor: Colors.red,
          ));
          setState(() => _gettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permission permanently denied. Please enable it in Settings.'),
          backgroundColor: Colors.red,
        ));
        setState(() => _gettingLocation = false);
        return;
      }

      // Get the most precise current position. `best` is the highest
      // accuracy tier — typically <10 m on a device with GPS. Time-limit
      // so the call doesn\'t hang forever indoors / under cloud cover.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      // Convert coordinates to address
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final parts = <String>[
          if (place.street != null && place.street!.isNotEmpty) place.street!,
          if (place.subLocality != null && place.subLocality!.isNotEmpty)
            place.subLocality!,
          if (place.locality != null && place.locality!.isNotEmpty)
            place.locality!,
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty)
            place.administrativeArea!,
          if (place.country != null && place.country!.isNotEmpty)
            place.country!,
        ];
        final address = parts.join(', ');
        setState(() {
          _addrCtrl.text = address;
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Location found: $address'),
          backgroundColor: AppTheme.secondary,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not get location: $e'),
        backgroundColor: Colors.red,
      ));
    }
    if (mounted) setState(() => _gettingLocation = false);
  }

  /// Search for any address/place name (e.g. "East Legon, Accra") and pick
  /// from results. Lets the user post properties in other cities/countries
  /// without needing to physically be there.
  Future<void> _searchAddress() async {
    final result = await showModalBottomSheet<_AddressResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AddressSearchSheet(),
    );
    if (result != null && mounted) {
      setState(() {
        _addrCtrl.text = result.formatted;
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Address set: ${result.formatted}'),
        backgroundColor: AppTheme.secondary,
      ));
    }
  }

  /// Open the Uber-style map picker — lets the user drag the pin to the
  /// exact street / building rather than relying on a fuzzy GPS fix.
  Future<void> _pickOnMap() async {
    final result = await Navigator.push<MapPickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _addrCtrl.text.trim().isEmpty
              ? null
              : _addrCtrl.text.trim(),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _addrCtrl.text = result.formatted;
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('📍 ${result.formatted}'),
        backgroundColor: AppTheme.secondary,
      ));
    }
  }

  void _proceed() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlatformSelectionScreen(
              images: widget.images,
              imageBytes: widget.imageBytes,
              postData: _postData),
        ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Property Details'), leading: const BackButton()),
        body: Column(children: [
          const StepIndicator(current: 2),
          Expanded(
              child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Basic Information'),
                    AppTextField(
                        controller: _titleCtrl,
                        label: 'Property Title *',
                        hint: 'e.g. Spacious 3-Bedroom Flat in Lekki Phase 1',
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Title is required'
                            : null),
                    const SizedBox(height: 4),
                    const Text(
                      'Tip: Describe what makes it special — "Luxury 2-bed with pool in VI", '
                      '"Newly built self-con in Ajah", "Executive 4-bed duplex in Ikoyi"',
                      style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          flex: 2,
                          child: AppTextField(
                              controller: _priceCtrl,
                              label: 'Price *',
                              hint: '250,000',
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Required'
                                  : null)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: AppDropdown<String>(
                              label: 'Period',
                              value: _pricePeriod,
                              items: const [
                                DropdownMenuItem(
                                    value: 'monthly', child: Text('Monthly')),
                                DropdownMenuItem(
                                    value: 'yearly', child: Text('Yearly')),
                                DropdownMenuItem(
                                    value: 'outright', child: Text('Outright')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _pricePeriod = v!))),
                    ]),
                    const SizedBox(height: 16),
                    AppTextField(
                        controller: _addrCtrl,
                        label: 'Location / Address',
                        hint: 'Tap "Pick on map" to drop a pin on the exact spot'),
                    const SizedBox(height: 10),
                    // Primary action — the Uber-style map picker. Precise
                    // because the user drags the pin to the exact building
                    // instead of relying on fuzzy GPS.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickOnMap,
                        icon: const Icon(Icons.map, size: 20),
                        label: const Text('Pick on map'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Secondary fallbacks — quick GPS or typed search.
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _gettingLocation ? null : _getGPSLocation,
                          icon: _gettingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(
                              _gettingLocation ? 'Locating...' : 'Use GPS',
                              style: const TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _searchAddress,
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Type address',
                              style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                    if (_latitude != null && _longitude != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '📍 ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMid),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const SectionLabel('Property Type *'),
                    AppDropdown<String>(
                        label: 'Select Type',
                        value: _propertyType,
                        items: AppConstants.propertyTypes
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child:
                                    Text(AppConstants.formatPropertyType(t))))
                            .toList(),
                        onChanged: (v) => setState(() => _propertyType = v),
                        validator: (v) =>
                            v == null ? 'Please select a type' : null),
                    const SizedBox(height: 24),
                    const SectionLabel('Compound Type *'),
                    Row(children: [
                      Expanded(
                          child: _RadioOpt(
                              label: 'Self Compound',
                              value: 'self_compound',
                              group: _compoundType,
                              onChange: (v) =>
                                  setState(() => _compoundType = v!))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _RadioOpt(
                              label: 'Shared Compound',
                              value: 'shared_compound',
                              group: _compoundType,
                              onChange: (v) =>
                                  setState(() => _compoundType = v!))),
                    ]),
                    if (_compoundType == 'shared_compound') ...[
                      const SizedBox(height: 16),
                      StepperField(
                          label: 'Number of tenants in compound',
                          value: _numTenants,
                          onChanged: (v) => setState(() => _numTenants = v),
                          min: 2),
                    ],
                    const SizedBox(height: 24),
                    const SectionLabel('Room Details'),
                    StepperField(
                        label: 'Bedrooms',
                        value: _bedrooms,
                        onChanged: (v) => setState(() => _bedrooms = v)),
                    const SizedBox(height: 12),
                    StepperField(
                        label: 'Bathrooms',
                        value: _bathrooms,
                        onChanged: (v) => setState(() => _bathrooms = v)),
                    const SizedBox(height: 12),
                    StepperField(
                        label: 'Toilets',
                        value: _toilets,
                        onChanged: (v) => setState(() => _toilets = v)),
                    const SizedBox(height: 24),
                    const SectionLabel('Furnishing'),
                    AppDropdown<String>(
                        label: 'Furnishing level',
                        value: _furnishing,
                        items: const [
                          DropdownMenuItem(
                              value: 'unfurnished', child: Text('Unfurnished')),
                          DropdownMenuItem(
                              value: 'semi_furnished',
                              child: Text('Semi-furnished')),
                          DropdownMenuItem(
                              value: 'fully_furnished',
                              child: Text('Fully furnished')),
                        ],
                        onChanged: (v) =>
                            setState(() => _furnishing = v ?? 'unfurnished')),
                    const SizedBox(height: 24),
                    const SectionLabel('Description',
                        subtitle:
                            'Optional — tell buyers what makes this property special. The AI will build on this.'),
                    AppTextField(
                        controller: _descCtrl,
                        label: 'Description',
                        hint:
                            'e.g. Recently renovated. Close to Lekki Conservation Centre. Quiet, family-friendly neighbourhood.',
                        maxLines: 4),
                    const SizedBox(height: 24),
                    const SectionLabel('Utilities & Amenities'),
                    _UtilRow(
                        label: 'Water Supply',
                        icon: Icons.water_drop,
                        value: _water,
                        onChange: (v) => setState(() => _water = v!)),
                    _UtilRow(
                        label: 'Electricity (PHCN/Solar)',
                        icon: Icons.bolt,
                        value: _electricity,
                        onChange: (v) => setState(() => _electricity = v!)),
                    _UtilRow(
                        label: 'Parking Space',
                        icon: Icons.local_parking,
                        value: _parking,
                        onChange: (v) => setState(() => _parking = v!)),
                    const SizedBox(height: 24),
                    const SectionLabel('Additional Features',
                        subtitle: 'Select all that apply'),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppConstants.extraFeatureOptions
                            .map((f) => ToggleChip(
                                  label: f,
                                  selected: _features.contains(f),
                                  onTap: () => setState(() =>
                                      _features.contains(f)
                                          ? _features.remove(f)
                                          : _features.add(f)),
                                ))
                            .toList()),
                    const SizedBox(height: 30),
                  ]),
            ),
          )),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: ElevatedButton(
                onPressed: _canProceed ? _proceed : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canProceed ? AppTheme.primary : AppTheme.border),
                child: Text(_canProceed
                    ? 'Next: Choose Platform →'
                    : 'Fill required fields to continue'),
              )),
        ]),
      );
}

class _RadioOpt extends StatelessWidget {
  final String label, value, group;
  final void Function(String?) onChange;
  const _RadioOpt(
      {required this.label,
      required this.value,
      required this.group,
      required this.onChange});
  @override
  Widget build(BuildContext context) {
    final sel = value == group;
    return GestureDetector(
        onTap: () => onChange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
              border: Border.all(
                  color: sel ? AppTheme.primary : AppTheme.border,
                  width: sel ? 2 : 1),
              borderRadius: BorderRadius.circular(10),
              color: sel ? AppTheme.primary.withOpacity(0.06) : Colors.white),
          child: Row(children: [
            Icon(
                sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: sel ? AppTheme.primary : AppTheme.textLight,
                size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: sel ? AppTheme.primary : AppTheme.textDark,
                        fontWeight:
                            sel ? FontWeight.w600 : FontWeight.normal))),
          ]),
        ));
  }
}

class _UtilRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final void Function(bool?) onChange;
  const _UtilRow(
      {required this.label,
      required this.icon,
      required this.value,
      required this.onChange});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: AppTheme.textMid),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Switch.adaptive(
              value: value,
              onChanged: onChange,
              activeTrackColor: AppTheme.secondary),
          Text(value ? 'Yes' : 'No',
              style: TextStyle(
                  color: value ? AppTheme.secondary : AppTheme.textMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _AddressResult {
  final String formatted;
  final double latitude;
  final double longitude;
  const _AddressResult(
      {required this.formatted,
      required this.latitude,
      required this.longitude});
}

/// Bottom sheet that lets the user type any address, geocode it, and pick
/// from the returned results. Uses the `geocoding` package — no extra API
/// keys required.
class _AddressSearchSheet extends StatefulWidget {
  const _AddressSearchSheet();
  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _searching = false;
  String? _errorMsg;
  List<_AddressResult> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _errorMsg = null;
      _results = [];
    });
    try {
      final locations = await locationFromAddress(query);
      final results = <_AddressResult>[];
      for (final loc in locations.take(5)) {
        try {
          final placemarks =
              await placemarkFromCoordinates(loc.latitude, loc.longitude);
          if (placemarks.isEmpty) continue;
          final p = placemarks.first;
          final parts = <String>[
            if (p.street != null && p.street!.isNotEmpty) p.street!,
            if (p.subLocality != null && p.subLocality!.isNotEmpty)
              p.subLocality!,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
            if (p.administrativeArea != null &&
                p.administrativeArea!.isNotEmpty)
              p.administrativeArea!,
            if (p.country != null && p.country!.isNotEmpty) p.country!,
          ];
          final label = parts.join(', ');
          if (label.isEmpty) continue;
          results.add(_AddressResult(
              formatted: label,
              latitude: loc.latitude,
              longitude: loc.longitude));
        } catch (_) {
          // Skip placemark resolution failure for this hit.
        }
      }
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = results;
        if (results.isEmpty) {
          _errorMsg = 'No matches. Try being more specific (add city/country).';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _errorMsg = 'Could not search. Check your internet and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Search an address',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark)),
              const SizedBox(height: 4),
              const Text(
                  'Type any city, neighbourhood, or full address — anywhere in the world.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMid)),
              const SizedBox(height: 14),
              TextField(
                controller: _queryCtrl,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText: 'e.g. East Legon, Accra',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _runSearch,
                        ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(_errorMsg!,
                    style:
                        const TextStyle(fontSize: 13, color: AppTheme.error)),
              ],
              const SizedBox(height: 14),
              if (_results.isNotEmpty)
                const Text('Results',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMid)),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      leading: const Icon(Icons.place, color: AppTheme.primary),
                      title: Text(r.formatted,
                          style: const TextStyle(
                              fontSize: 14, color: AppTheme.textDark)),
                      subtitle: Text(
                          '${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMid)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppTheme.textLight),
                      onTap: () => Navigator.pop(context, r),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
