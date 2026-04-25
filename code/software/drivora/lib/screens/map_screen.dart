import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:google_maps_flutter/google_maps_flutter.dart';
=======
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

<<<<<<< HEAD
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
=======
class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  static const LatLng _initialPosition = LatLng(6.9271, 79.8612);
  GoogleMapController? _mapController;

  bool _trafficEnabled = false;
  bool _searchFocused = false;
  int _mapTypeIndex = 0; // 0=normal, 1=satellite, 2=terrain
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  late AnimationController _panelAnim;
  late Animation<Offset> _panelSlide;

  final List<_QuickDest> _quickDests = const [
    _QuickDest(Icons.local_gas_station_rounded, 'Fuel Station', '0.8 km'),
    _QuickDest(Icons.local_hospital_rounded, 'Hospital', '2.1 km'),
    _QuickDest(Icons.local_parking_rounded, 'Parking', '0.3 km'),
    _QuickDest(Icons.restaurant_rounded, 'Rest Stop', '1.5 km'),
  ];

  final String _appleMapStyle = '''
  [
    {"elementType":"geometry","stylers":[{"color":"#f5f5f7"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#6e6e73"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]},
    {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e8e8ed"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#d1d1d6"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#a2c4f5"}]}
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  ]
  ''';

  @override
<<<<<<< HEAD
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
=======
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelAnim, curve: Curves.easeOutCubic));
    _panelAnim.forward();

    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _panelAnim.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  MapType get _currentMapType {
    switch (_mapTypeIndex) {
      case 1: return MapType.satellite;
      case 2: return MapType.terrain;
      default: return MapType.normal;
    }
  }

  void _cycleMapType() {
    HapticFeedback.selectionClick();
    setState(() => _mapTypeIndex = (_mapTypeIndex + 1) % 3);
  }

  void _toggleTraffic() {
    HapticFeedback.selectionClick();
    setState(() => _trafficEnabled = !_trafficEnabled);
  }

  void _centerOnMe() {
    HapticFeedback.lightImpact();
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _initialPosition, zoom: 15),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
      ),
    );
  }

<<<<<<< HEAD
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
=======
  void _zoomIn() {
    HapticFeedback.selectionClick();
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: Stack(
        children: [
          // ── MAP ──
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialPosition,
                zoom: 15,
              ),
              mapType: _currentMapType,
              trafficEnabled: _trafficEnabled,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                if (_mapTypeIndex == 0) {
                  ctrl.setMapStyle(_appleMapStyle);
                }
              },
            ),
          ),

          // ── TOP OVERLAY ──
          SafeArea(
            child: SlideTransition(
              position: _panelSlide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SearchBar(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      focused: _searchFocused,
                      onClear: () {
                        _searchCtrl.clear();
                        _searchFocus.unfocus();
                      },
                    ),
                  ),

                  // Quick destination chips
                  if (!_searchFocused) ...[
                    const SizedBox(height: 10),
                    _QuickDestRow(destinations: _quickDests),
                  ],

                  // Live status banner
                  if (!_searchFocused) ...[
                    const SizedBox(height: 10),
                    _LiveStatusBanner(),
                  ],
                ],
              ),
            ),
          ),

          // ── RIGHT CONTROLS ──
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                _MapFab(
                  icon: Icons.my_location_rounded,
                  onTap: _centerOnMe,
                  tooltip: 'My Location',
                ),
                const SizedBox(height: 10),
                _MapFab(
                  icon: Icons.add_rounded,
                  onTap: _zoomIn,
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 10),
                _MapFab(
                  icon: Icons.remove_rounded,
                  onTap: _zoomOut,
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(height: 10),
                _MapFab(
                  icon: Icons.layers_rounded,
                  onTap: _cycleMapType,
                  tooltip: 'Map Type',
                  active: _mapTypeIndex != 0,
                ),
                const SizedBox(height: 10),
                _MapFab(
                  icon: Icons.traffic_rounded,
                  onTap: _toggleTraffic,
                  tooltip: 'Traffic',
                  active: _trafficEnabled,
                ),
              ],
            ),
          ),

          // ── BOTTOM SPEED CARD ──
          Positioned(
            left: 16, right: 16, bottom: 20,
            child: _BottomSpeedCard(),
          ),
        ],
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
      ),
    );
  }
}
<<<<<<< HEAD
=======

// ── SEARCH BAR ────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused
              ? AppTheme.accentBlue.withOpacity(0.4)
              : const Color(0x0A000000),
        ),
        boxShadow: [
          BoxShadow(
            color: focused
                ? AppTheme.accentBlue.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            blurRadius: focused ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(Icons.search_rounded,
                color: AppTheme.accentBlue, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1D1D1F),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search destination…',
                hintStyle: TextStyle(
                  color: const Color(0xFF6E6E73).withOpacity(0.5),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 16),
              ),
            ),
          ),
          if (focused || controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Icon(Icons.cancel_rounded,
                    color: Color(0xFFAEAEB2), size: 18),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.mic_rounded,
                  color: Color(0xFF8E8E93), size: 20),
            ),
        ],
      ),
    );
  }
}

// ── QUICK DESTINATIONS ────────────────────────
class _QuickDest {
  final IconData icon;
  final String label;
  final String distance;
  const _QuickDest(this.icon, this.label, this.distance);
}

class _QuickDestRow extends StatelessWidget {
  final List<_QuickDest> destinations;
  const _QuickDestRow({required this.destinations});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: destinations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final d = destinations[i];
          return GestureDetector(
            onTap: () => HapticFeedback.selectionClick(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(d.icon, size: 14, color: AppTheme.accentBlue),
                  const SizedBox(width: 6),
                  Text(
                    d.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    d.distance,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── LIVE STATUS BANNER ────────────────────────
class _LiveStatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (ctx, svc, _) {
        if (!svc.isConnected) return const SizedBox.shrink();
        final data = svc.currentData;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D1F).withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LIVE ADAS',
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentGreen,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  '│',
                  style: TextStyle(color: Colors.white24),
                ),
                const SizedBox(width: 16),
                Text(
                  '${data.speed.toInt()} KM/H',
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentBlue,
                  ),
                ),
                const Spacer(),
                if (data.ldwActive)
                  _MiniChip('LANE', AppTheme.accentAmber)
                else if (data.brakeActive)
                  _MiniChip('AEB', AppTheme.accentRed)
                else
                  _MiniChip('SAFE', AppTheme.accentGreen),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── MAP FAB ───────────────────────────────────
class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  const _MapFab({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active ? AppTheme.accentBlue : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (active ? AppTheme.accentBlue : Colors.black)
                  .withOpacity(active ? 0.25 : 0.1),
              blurRadius: active ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: active
                ? AppTheme.accentBlue
                : const Color(0x0A000000),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? Colors.white : const Color(0xFF1D1D1F),
        ),
      ),
    );
  }
}

// ── BOTTOM SPEED CARD ─────────────────────────
class _BottomSpeedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (ctx, svc, _) {
        final data = svc.currentData;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0x0A000000)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENT SPEED',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        svc.isConnected
                            ? '${data.speed.toInt()}'
                            : '--',
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1D1D1F),
                          height: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 3, left: 4),
                        child: Text(
                          'KM/H',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Container(
                width: 1, height: 40,
                color: const Color(0x0A000000),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoItem(
                      'TTC',
                      svc.isConnected
                          ? '${data.ttc.toStringAsFixed(1)}s'
                          : '--',
                      data.ttc < 3.0 && svc.isConnected
                          ? AppTheme.accentRed
                          : const Color(0xFF1D1D1F),
                    ),
                    _InfoItem(
                      'STATUS',
                      svc.isConnected ? 'LIVE' : 'STANDBY',
                      svc.isConnected
                          ? AppTheme.accentGreen
                          : const Color(0xFFAEAEB2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 8,
            color: Color(0xFF8E8E93),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
