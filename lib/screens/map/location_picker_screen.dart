import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/widgets/common/app_toast.dart';

class LocationPickerResult {
  final String address;
  final String city;
  final double latitude;
  final double longitude;

  LocationPickerResult({
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late MapController _mapController;
  late LatLng _currentLocation;
  String _addressText = 'Memuat lokasi...';
  String _cityName = 'Jakarta';
  bool _isLoadingAddress = false;
  bool _isLocating = false;
  final _searchController = TextEditingController();

  // Preset quick locations
  final List<Map<String, dynamic>> _quickLocations = [
    {
      'name': 'Jakarta Pusat',
      'lat': -6.1805,
      'lng': 106.8284,
      'city': 'Jakarta',
    },
    {
      'name': 'Jakarta Selatan',
      'lat': -6.2615,
      'lng': 106.8106,
      'city': 'Jakarta Selatan',
    },
    {'name': 'Bandung', 'lat': -6.9175, 'lng': 107.6191, 'city': 'Bandung'},
    {'name': 'Surabaya', 'lat': -7.2575, 'lng': 112.7521, 'city': 'Surabaya'},
    {
      'name': 'Yogyakarta',
      'lat': -7.7956,
      'lng': 110.3695,
      'city': 'Yogyakarta',
    },
    {'name': 'Medan', 'lat': 3.5952, 'lng': 98.6722, 'city': 'Medan'},
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Default to provided coordinates, or Jakarta if none
    final lat = widget.initialLat ?? -6.2088;
    final lng = widget.initialLng ?? 106.8456;
    _currentLocation = LatLng(lat, lng);

    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressText = widget.initialAddress!;
    } else {
      _reverseGeocode(_currentLocation);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'DoctorComputerFlutterApp/1.0 (contact@doctorcomputer.id)',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        final road =
            address?['road'] ??
            address?['suburb'] ??
            address?['neighbourhood'] ??
            address?['quarter'] ??
            '';
        final city =
            address?['city'] ??
            address?['town'] ??
            address?['county'] ??
            address?['state'] ??
            'Jakarta';
        final state = address?['state'] ?? '';
        final country = address?['country'] ?? 'Indonesia';

        String resolvedAddress = '';
        if (road.isNotEmpty) {
          resolvedAddress = 'Jl. $road, $city, $state, $country';
        } else {
          resolvedAddress =
              data['display_name'] ??
              'Koordinat: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        }

        if (mounted) {
          setState(() {
            _addressText = resolvedAddress;
            _cityName = city.toString();
            _isLoadingAddress = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Geocode fallback: $e');
    }

    if (mounted) {
      setState(() {
        _addressText =
            'Lokasi Pin: ${_currentLocation.latitude.toStringAsFixed(5)}, ${_currentLocation.longitude.toStringAsFixed(5)}';
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoadingAddress = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=id&limit=1',
      );
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'DoctorComputerFlutterApp/1.0 (contact@doctorcomputer.id)',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          final first = list.first;
          final lat =
              double.tryParse(first['lat'].toString()) ??
              _currentLocation.latitude;
          final lon =
              double.tryParse(first['lon'].toString()) ??
              _currentLocation.longitude;
          final target = LatLng(lat, lon);

          setState(() {
            _currentLocation = target;
            _addressText = first['display_name'] ?? query;
            _isLoadingAddress = false;
          });
          _mapController.move(target, 16.0);
          return;
        }
      }
    } catch (e) {
      debugPrint('Search address error: $e');
    }

    if (mounted) {
      setState(() => _isLoadingAddress = false);
      AppToast.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lokasi tidak ditemukan, coba nama kota atau jalan lain.',
          ),
        ),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage(
          'Aktifkan layanan lokasi perangkat untuk menggunakan lokasi saat ini.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showLocationMessage('Izin lokasi belum diberikan.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Izin lokasi ditolak permanen. Aktifkan melalui Pengaturan aplikasi.',
          action: SnackBarAction(
            label: 'Pengaturan',
            onPressed: Geolocator.openAppSettings,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final target = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() => _currentLocation = target);
      _mapController.move(target, 16);
      await _reverseGeocode(target);
    } catch (error) {
      debugPrint('Could not get current device location: $error');
      _showLocationMessage(
        'Lokasi saat ini gagal didapatkan. Periksa GPS dan coba lagi.',
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showLocationMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    AppToast.of(context)
        .showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      _currentLocation = point;
    });
    _reverseGeocode(point);
  }

  void _selectQuickLocation(Map<String, dynamic> loc) {
    final target = LatLng(loc['lat'] as double, loc['lng'] as double);
    setState(() {
      _currentLocation = target;
      _cityName = loc['city'] as String;
    });
    _mapController.move(target, 15.0);
    _reverseGeocode(target);
  }

  void _confirmSelection() async {
    final result = LocationPickerResult(
      address: _addressText,
      city: _cityName,
      latitude: _currentLocation.latitude,
      longitude: _currentLocation.longitude,
    );

    // Also persist to Supabase DB for current logged-in user
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      await auth.updateProfile(
        auth.currentUser!.fullName,
        auth.currentUser!.phone,
        result.address,
        result.city,
        latitude: result.latitude,
        longitude: result.longitude,
      );
    }

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Alamat via Peta'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Gunakan lokasi saya saat ini',
            onPressed: _isLocating ? null : _useCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              onTap: (tapPosition, point) => _onMapTapped(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'id.doctorcomputer.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 60,
                    height: 60,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.redAccent,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Search & Quick City Pills
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari alamat, jalan, atau kota...',
                      prefixIcon: Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => _searchAddress(_searchController.text),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: _searchAddress,
                  ),
                ),
                const SizedBox(height: 8),

                // Quick City Selectors
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickLocations.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final loc = _quickLocations[index];
                      return ActionChip(
                        backgroundColor: AppColors.surface,
                        label: Text(
                          loc['name'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        avatar: Icon(
                          Icons.near_me,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        onPressed: () => _selectQuickLocation(loc),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Card with Address Details & Confirm Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alamat Terpilih:',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_isLoadingAddress)
                                const Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Mengambil rincian alamat...',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  _addressText,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Koordinat: ${_currentLocation.latitude.toStringAsFixed(5)}, ${_currentLocation.longitude.toStringAsFixed(5)}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _confirmSelection,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Gunakan Alamat Ini & Simpan ke DB',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
