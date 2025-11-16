import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:campus_gaurd_final/app_drawer.dart';
import 'package:campus_gaurd_final/floating_chatbot.dart';
import 'package:campus_gaurd_final/home_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ActiveSosScreen extends StatefulWidget {
  final String sosId;

  const ActiveSosScreen({super.key, required this.sosId});

  @override
  State<ActiveSosScreen> createState() => _ActiveSosScreenState();
}

class _ActiveSosScreenState extends State<ActiveSosScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  GeoPoint? _sosLocation;

  @override
  void initState() {
    super.initState();
    _loadSosData();
    _getCurrentLocation();
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      }
    });
  }

  Future<void> _loadSosData() async {
    try {
      final doc = await _firestore.collection('sos_events').doc(widget.sosId).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _sosLocation = data?['location'] as GeoPoint?;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _stopSOS() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop SOS'),
        content: const Text('Are you sure you want to stop the SOS alert?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Stop SOS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Get contacts for safe message
        final contactsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('trusted_contacts')
            .get();

        // Update database status to 'cancelled'
        try {
          await _firestore.collection('sos_events').doc(widget.sosId).update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update SOS status: $e')),
            );
          }
          return;
        }

        // Navigate to home screen first
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }

        // Then open messaging app with safe message
        await Future.delayed(const Duration(milliseconds: 800));
        if (contactsSnapshot.docs.isNotEmpty) {
          final List<String> phoneNumbers = contactsSnapshot.docs
              .map((doc) {
                final data = doc.data();
                final phone = data['phone']?.toString() ?? '';
                return phone.replaceAll(RegExp(r'[^\d+]'), '');
              })
              .where((phone) => phone.isNotEmpty && phone.length >= 10)
              .toList();

          if (phoneNumbers.isNotEmpty) {
            final messageBody = 'I am safe now. Thank you for your concern.';
            bool smsOpened = false;
            for (String phone in phoneNumbers) {
              try {
                // Try SMS URI first
                final smsUri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(messageBody)}');
                if (await canLaunchUrl(smsUri)) {
                  await launchUrl(smsUri, mode: LaunchMode.externalApplication);
                  smsOpened = true;
                  break;
                }
              } catch (e) {
                // Try alternative format
                try {
                  final smsUri2 = Uri(
                    scheme: 'sms',
                    path: phone,
                    queryParameters: {'body': messageBody},
                  );
                  if (await canLaunchUrl(smsUri2)) {
                    await launchUrl(smsUri2, mode: LaunchMode.externalApplication);
                    smsOpened = true;
                    break;
                  }
                } catch (e2) {
                  continue;
                }
              }
            }
            if (!smsOpened && phoneNumbers.isNotEmpty) {
              // Fallback: try with tel: scheme
              try {
                final telUri = Uri(scheme: 'tel', path: phoneNumbers.first);
                if (await canLaunchUrl(telUri)) {
                  await launchUrl(telUri, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                // Ignore
              }
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to stop SOS alert: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active SOS'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: true, // Show hamburger menu
      ),
      drawer: AppDrawer(),
      floatingActionButton: const FloatingChatbot(),
      body: Stack(
        children: [
          // Google Maps with live location (same as home screen)
          _isLoadingLocation || _currentPosition == null
              ? const Center(child: CircularProgressIndicator(color: Colors.red))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 16.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: MapType.normal,
                  markers: {
                    Marker(
                      markerId: const MarkerId('current_location'),
                      position: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                    if (_sosLocation != null)
                      Marker(
                        markerId: const MarkerId('sos_location'),
                        position: LatLng(_sosLocation!.latitude, _sosLocation!.longitude),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        infoWindow: const InfoWindow(title: 'SOS Triggered Location'),
                      ),
                  },
                ),
          // Stop SOS Button at bottom center
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _stopSOS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  'Stop SOS',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
