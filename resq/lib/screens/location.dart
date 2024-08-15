import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as l;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'BluetoothManager.dart'; // Import the global manager
import 'timer_email.dart'; // Import the TimerPage
import 'addingemail.dart'; // Import the AddingEmailPage
import 'infopage.dart'; // Import the Infare
import 'about.dart'; // Import the AboutPage
import 'profile_page.dart'; // Import the ProfilePage

class Location extends StatefulWidget {
  const Location({Key? key}) : super(key: key);

  @override
  State<Location> createState() => _LocationState();
}

class _LocationState extends State<Location> with WidgetsBindingObserver {
  bool gpsEnabled = true;
  bool permissionGranted = true;
  bool isLoading = true;
  l.Location location = l.Location();
  late StreamSubscription<l.LocationData> subscription;
  GoogleMapController? mapController;
  Marker? userMarker;
  LatLng? lastKnownPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadLastKnownLocation().then((_) {
      checkStatus();
    });

    // Start listening to Bluetooth data
    final connection = BluetoothManager().connection;
    if (connection != null) {
      connection.input!.listen((Uint8List data) {
        String incomingData = String.fromCharCodes(data).trim();
        print('Received from Bluetooth: $incomingData');

        if (incomingData == '1') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TimerPage(
              coordinates: lastKnownPosition,
            )),
          );
        }
      }).onDone(() {
        print('Disconnected by remote or connection lost');
      });
    }
  }

  @override
  void dispose() {
    stopTracking();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    startTracking();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: lastKnownPosition ?? const LatLng(0, 0),
                          zoom: 15.0,
                        ),
                        markers: userMarker != null ? {userMarker!} : {},
                        onMapCreated: (controller) {
                          mapController = controller;
                          if (userMarker != null) {
                            mapController?.animateCamera(
                                CameraUpdate.newLatLng(userMarker!.position));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 80.0,
                  left: 16.0,
                  child: SpeedDial(
                    icon: Icons.menu,
                    activeIcon: Icons.close,
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    activeBackgroundColor: Colors.blue,
                    activeForegroundColor: Colors.white,
                    buttonSize: const Size(56.0, 56.0),
                    visible: true,
                    closeManually: false,
                    renderOverlay: true,
                    overlayOpacity: 0.5,
                    overlayColor: Colors.black,
                    tooltip: 'Options',
                    heroTag: 'speed-dial-hero-tag',
                    elevation: 8.0,
                    shape: const CircleBorder(),
                    direction: SpeedDialDirection.down,
                    children: [
                      SpeedDialChild(
                        child: const Icon(Icons.contact_phone),
                        backgroundColor: Colors.red,
                        label: 'Add Emergency Contacts',
                        labelStyle: const TextStyle(fontSize: 16.0),
                        labelBackgroundColor: Colors.white,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AddingEmailPage()),
                          );
                        },
                      ),
                      SpeedDialChild(
                        child: const Icon(Icons.help),
                        backgroundColor: const Color.fromARGB(255, 255, 0, 0),
                        label: 'How to Connect',
                        labelStyle: const TextStyle(fontSize: 16.0),
                        labelBackgroundColor: Colors.white,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Infare()),
                          );
                        },
                      ),
                      SpeedDialChild(
                        child: const Icon(Icons.info),
                        backgroundColor: Colors.orange,
                        label: 'About Page',
                        labelStyle: const TextStyle(fontSize: 16.0),
                        labelBackgroundColor: Colors.white,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AboutPage()),
                          );
                        },
                      ),
                      SpeedDialChild(
                        child: const Icon(Icons.person),
                        backgroundColor: Colors.green,
                        label: 'Profile',
                        labelStyle: const TextStyle(fontSize: 16.0),
                        labelBackgroundColor: Colors.white,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ProfilePage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> checkStatus() async {
    bool permissionGranted = await isPermissionGranted();
    if (permissionGranted) {
      bool gpsEnabled = await isGpsEnabled();
      if (gpsEnabled) {
        startTracking();
      } else {
        bool isGpsActive = await location.requestService();
        setState(() {
          gpsEnabled = isGpsActive;
          if (gpsEnabled) {
            startTracking();
          }
        });
      }
    } else {
      await requestLocationPermission();
    }
  }

  Future<bool> isPermissionGranted() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  Future<bool> isGpsEnabled() async {
    return await location.serviceEnabled();
  }

  Future<void> requestLocationPermission() async {
    PermissionStatus permissionStatus =
        await Permission.locationWhenInUse.request();
    setState(() {
      permissionGranted = permissionStatus == PermissionStatus.granted;
    });
    if (permissionGranted) {
      checkStatus();
    }
  }

  void startTracking() async {
    subscription = location.onLocationChanged.listen((event) {
      updateLocation(event);
    });
  }

  void stopTracking() {
    subscription.cancel();
  }

  void updateLocation(l.LocationData data) async {
    LatLng newPosition = LatLng(data.latitude!, data.longitude!);
    setState(() {
      userMarker = Marker(
        markerId: const MarkerId('userMarker'),
        position: newPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
      lastKnownPosition = newPosition;
      isLoading = false;
    });

    if (mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(newPosition));
      saveLastKnownLocation(newPosition);
    }
  }

  Future<void> saveLastKnownLocation(LatLng position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latitude', position.latitude);
    await prefs.setDouble('longitude', position.longitude);
  }

  Future<void> loadLastKnownLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble('latitude');
    final longitude = prefs.getDouble('longitude');
    if (latitude != null && longitude != null) {
      setState(() {
        lastKnownPosition = LatLng(latitude, longitude);
      });
    }
    setState(() {
      isLoading = false;
    });
  }
}
