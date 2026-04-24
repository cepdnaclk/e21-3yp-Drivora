import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _initialPosition = LatLng(6.9271, 79.8612);
  GoogleMapController? _controller;

  // Dark Map Style JSON to match ADAS aesthetic
  final String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#f5f5f7"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#6e6e73"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#ffffff"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#0a84ff"}]
    }
  ]
  ''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('NAVIGATION'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 15),
            onMapCreated: (controller) {
              _controller = controller;
              // Setting style if supported (usually handled via theme/platform)
            },
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Apple-style Floating Search Bar
          Positioned(
            top: 20, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.panel.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.shadowLg,
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppTheme.accentBlue, size: 20),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text('Where to?', 
                      style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  const Icon(Icons.mic, color: AppTheme.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          
          // Map Control Buttons
          Positioned(
            bottom: 40, right: 20,
            child: Column(
              children: [
                _mapActionBtn(Icons.my_location, () {}),
                const SizedBox(height: 12),
                _mapActionBtn(Icons.layers_outlined, () {}),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _mapActionBtn(IconData icon, VoidCallback onTap) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: AppTheme.panel,
        shape: BoxShape.circle,
        boxShadow: AppTheme.shadow,
        border: Border.all(color: AppTheme.border),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.textPrimary, size: 22),
        onPressed: onTap,
      ),
    );
  }
}
