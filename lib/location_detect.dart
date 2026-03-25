// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;

// class LocationDetectScreen extends StatefulWidget {
//   const LocationDetectScreen({super.key});

//   @override
//   State<LocationDetectScreen> createState() => _LocationDetectScreenState();
// }

// class _LocationDetectScreenState extends State<LocationDetectScreen> {
//   // ── State ──────────────────────────────────────────────────────────────────
//   String _resolvedLocationString = '';
//   bool _isLoading = false;
//   final List<String> _logs = ['Waiting for actions...'];

//   // ── Helpers ────────────────────────────────────────────────────────────────
//   void _log(String message) {
//     setState(() => _logs.add('> $message'));
//     debugPrint(message);
//   }

//   // ── STEP 1 : Check / request permissions ──────────────────────────────────
//   Future<bool> _handlePermission() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       _log('Location services are disabled. Please enable them.');
//       return false;
//     }

//     LocationPermission permission = await Geolocator.checkPermission();

//     if (permission == LocationPermission.denied) {
//       _log('Requesting location permission...');
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         _log('Location permission denied.');
//         return false;
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       _log(
//         'Location permission permanently denied. '
//         'Please enable it from app settings.',
//       );
//       return false;
//     }

//     return true;
//   }

//   // ── STEP 2 : Get GPS coordinates ──────────────────────────────────────────
//   Future<Position?> _getGpsPosition() async {
//     _log('Requesting GPS position...');

//     try {
//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       _log('GPS Received: Lat ${position.latitude}, Lon ${position.longitude}');
//       return position;
//     } catch (e) {
//       _log('GPS Error: $e');
//       return null;
//     }
//   }

//   // ── STEP 3 : Reverse-geocode with OpenStreetMap Nominatim (FREE) ──────────
//   Future<String> _reverseGeocode(double lat, double lon) async {
//     _log('Calling OpenStreetMap Nominatim API...');

//     final url = Uri.parse(
//       'https://nominatim.openstreetmap.org/reverse'
//       '?format=json&lat=$lat&lon=$lon',
//     );

//     final response = await http.get(
//       url,
//       // Nominatim requires a User-Agent header
//       headers: {'User-Agent': 'FlutterApp/1.0'},
//     );

//     if (response.statusCode != 200) {
//       throw Exception('Nominatim returned ${response.statusCode}');
//     }

//     final data = jsonDecode(response.body) as Map<String, dynamic>;
//     final address = data['address'] as Map<String, dynamic>? ?? {};

//     // ── Mirror the JS logic exactly ────────────────────────────────────────
//     // 1. Local area
//     final localArea =
//         address['neighbourhood'] as String? ??
//         address['suburb'] as String? ??
//         address['residential'] as String? ??
//         address['road'] as String?;

//     // 2. City (OSM uses state_district for many Indian cities)
//     final city =
//         address['city'] as String? ??
//         address['state_district'] as String? ??
//         address['town'] as String? ??
//         address['county'] as String?;

//     // 3. State
//     final state = address['state'] as String?;

//     // 4. Combine without repeating words
//     final parts = <String>[];
//     if (localArea != null) parts.add(localArea);
//     if (city != null && city != localArea) parts.add(city);
//     if (state != null) parts.add(state);

//     return parts.join(', ');
//   }

//   // ── Main entry-point called by the button ─────────────────────────────────
//   Future<void> getLocation() async {
//     setState(() {
//       _isLoading = true;
//       _resolvedLocationString = '';
//     });

//     try {
//       // 1. Permission
//       final hasPermission = await _handlePermission();
//       if (!hasPermission) return;

//       // 2. GPS
//       final position = await _getGpsPosition();
//       if (position == null) return;

//       // 3. Reverse geocode
//       final location = await _reverseGeocode(
//         position.latitude,
//         position.longitude,
//       );

//       _log('Resolved Location: $location');
//       setState(() => _resolvedLocationString = location);
//     } catch (e) {
//       _log('Geocoding Error: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   // ── UI (minimal — just enough to trigger & see the logic) ─────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Location Detection')),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Trigger button
//             ElevatedButton.icon(
//               onPressed: _isLoading ? null : getLocation,
//               icon:
//                   _isLoading
//                       ? const SizedBox(
//                         width: 18,
//                         height: 18,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                       : const Icon(Icons.location_on),
//               label: Text(_isLoading ? 'Detecting…' : 'Detect Location'),
//             ),

//             const SizedBox(height: 12),

//             // Resolved location display
//             if (_resolvedLocationString.isNotEmpty)
//               Chip(
//                 avatar: const Icon(Icons.place, size: 18),
//                 label: Text(_resolvedLocationString),
//               ),

//             const SizedBox(height: 16),

//             // Log console
//             const Text(
//               'Console Log:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 6),
//             Expanded(
//               child: Container(
//                 padding: const EdgeInsets.all(8),
//                 color: const Color(0xFF1E1E1E),
//                 child: ListView.builder(
//                   itemCount: _logs.length,
//                   itemBuilder:
//                       (_, i) => Text(
//                         _logs[i],
//                         style: const TextStyle(
//                           color: Color(0xFF00FF00),
//                           fontFamily: 'monospace',
//                           fontSize: 12,
//                         ),
//                       ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }