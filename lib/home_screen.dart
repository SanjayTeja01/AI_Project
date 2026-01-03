import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campus_gaurd_final/l10n/app_localizations.dart';
import 'package:campus_gaurd_final/active_sos_screen.dart';
import 'package:campus_gaurd_final/floating_chatbot.dart';
import 'package:campus_gaurd_final/app_drawer.dart';
import 'package:campus_gaurd_final/auth_screen.dart';
import 'package:campus_gaurd_final/app_bar_language_selector.dart';
import 'package:campus_gaurd_final/language_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentLocation();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkActiveSOS();
    }
  }

  Future<void> _checkActiveSOS() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final activeSOS = await _firestore
          .collection('sos_events')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (activeSOS.docs.isNotEmpty && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveSosScreen(sosId: activeSOS.docs.first.id),
          ),
        );
      }
    } catch (e) {
      // Ignore errors
    }
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

  Future<void> _triggerSOS() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.locationServicesDisabled ?? 'Location services are disabled. Please enable them.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n?.locationPermissionDenied ?? 'Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.locationPermissionPermanentlyDenied ?? 'Location permissions are permanently denied')),
          );
        }
        return;
      }

    try {
      // Get contacts from Firestore
      final contactsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('trusted_contacts')
          .get();

      if (contactsSnapshot.docs.isEmpty) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.noEmergencyContacts ?? 'No emergency contacts found. Please add contacts first.')),
          );
        }
        return;
      }

      // Get current location
      final position = _currentPosition ?? await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final locationLink =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      // Get username from database
      String username = 'Your Friend';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          username = userDoc.data()?['username'] ?? user.displayName ?? 'Your Friend';
        }
      } catch (e) {
        username = user.displayName ?? 'Your Friend';
      }

      // Create SOS event in database with status 'active'
      DocumentReference sosEventRef;
      try {
        sosEventRef = await _firestore.collection('sos_events').add({
          'userId': user.uid,
          'triggeredAt': FieldValue.serverTimestamp(),
          'location': GeoPoint(position.latitude, position.longitude),
          'locationLink': locationLink,
          'status': 'active',
          'cancelledAt': null,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create SOS event: $e')),
          );
        }
        return;
      }

      // Prepare SMS message
      final List<String> phoneNumbers = contactsSnapshot.docs
          .map((doc) {
            final data = doc.data();
            final phone = data['phone']?.toString() ?? '';
            return phone.replaceAll(RegExp(r'[^\d+]'), '');
          })
          .where((phone) => phone.isNotEmpty && phone.length >= 10)
          .toList();

      if (phoneNumbers.isNotEmpty) {
        final messageBody =
            'EMERGENCY! $username is in an emergency. Their last known location is: $locationLink';
        
        // Navigate to ActiveSOS screen first
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveSosScreen(sosId: sosEventRef.id),
            ),
          );
        }

        // Then open messaging app after a short delay
        await Future.delayed(const Duration(milliseconds: 800));
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
      } else {
        // Even if no contacts, navigate to ActiveSOS screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveSosScreen(sosId: sosEventRef.id),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = LanguageProvider();
    
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Text(l10n?.appTitle ?? 'Campus Guard');
          },
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          AppBarLanguageSelector(languageProvider: languageProvider),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }
            },
          ),
        ],
      ),
      drawer: AppDrawer(),
      floatingActionButton: const FloatingChatbot(),
      body: Stack(
        children: [
          // Google Maps with live location
          _isLoadingLocation || _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
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
                  },
                ),
          // SOS Button at bottom center
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _triggerSOS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                ),
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      l10n?.sos ?? 'SOS',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
