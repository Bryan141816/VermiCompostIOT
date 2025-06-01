import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:vermicompostmonitor/custom_functions/mdnsipfinder.dart';
import 'package:vermicompostmonitor/pages/device_dashboard/device_settings.dart'; // Update this path accordingly
import 'package:vermicompostmonitor/pages/device_dashboard/device_record_firebase.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';

class DeviceDashboardPage extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceDashboardPage({super.key, required this.device});

  @override
  State<DeviceDashboardPage> createState() => _DeviceDashboardPage();
}

class _DeviceDashboardPage extends State<DeviceDashboardPage> {
  Timer? _timer;
  double temp0 = 0.0;
  double temp1 = 0.0;
  int moisture1 = 0;
  int moisture2 = 0;
  double water_level = 0.0;

  bool isLoading = true;

  List<String> resolvedIps = [];
  String baseUrl = '';
  bool hasResolved = false;

  String connectionType = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAsync();
    });
    _timer = Timer.periodic(Duration(seconds: 2), (_) => fetchData());
  }

  Future<void> _initAsync() async {
    await resolveHostnameAndFetch();

    int calibrated = widget.device['device_calibrated'];

    if (calibrated == 0 && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              CalibrateStartUp(resolvedIps: resolvedIps, device: widget.device),
        ),
      );
    }
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _warningActive = false; // track if warning is currently active

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Call this function after each successful data fetch
  void _checkWarning() async {
    final avgTemp = (temp0 + temp1) / 2;
    final avgMoisture = (moisture1 + moisture2) / 2;
    final waterLevel = water_level;

    bool shouldWarn = avgTemp > 35 || avgMoisture < 80 || waterLevel < 20;

    if (shouldWarn && !_warningActive) {
      // Warning just became active
      _warningActive = true;
      try {
        await _audioPlayer.play(AssetSource('sounds/chime.mp3'));
      } catch (e) {
        print('Error playing sound: $e');
      }
    } else if (!shouldWarn) {
      _warningActive = false;
    }
  }

  bool _useFirebase = false;
  int _failedAttempts = 0;

  Future<void> resolveHostnameAndFetch() async {
    final mdnsHostname = widget.device['device_mdns'];
    try {
      final ips = await resolveMdnsHostname(mdnsHostname);

      if (ips.isNotEmpty) {
        connectionType = "Local network";
        if (!mounted) return;
        setState(() {
          resolvedIps = ips;
          baseUrl = 'http://${resolvedIps.first}';
          hasResolved = true;
          _useFirebase = false; // Use HTTP fetching
        });
        print('Resolved IPs for $mdnsHostname: $resolvedIps');
        fetchData(); // initial fetch
      } else {
        print('No IP addresses found for $mdnsHostname, switching to Firebase');
        if (!mounted) return;
        setState(() {
          _useFirebase = true;
          isLoading = true;
        });
        fetchDataFromFirebase();
      }
    } catch (e) {
      print('Error resolving hostname: $e');
      if (!mounted) return;
      setState(() {
        _useFirebase = true;
        isLoading = true;
      });
      fetchDataFromFirebase();
    }
  }

  Future<void> fetchData() async {
    if (_useFirebase) {
      fetchDataFromFirebase();
      return;
    }

    if (!hasResolved) return;

    try {
      final response = await http.get(Uri.parse('$baseUrl/get_data'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          temp0 = data['temp0'] ?? 0.0;
          temp1 = data['temp1'] ?? 0.0;
          moisture1 = data['moisture1'] ?? 0;
          moisture2 = data['moisture2'] ?? 0;
          water_level = data['water_level'] ?? 0.0;
          isLoading = false;
        });
        _failedAttempts = 0; // reset failure count on success
        _checkWarning(); // check warning after new data
      } else {
        _handleFetchError();
        print('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      _handleFetchError();
      print('Error fetching data: $e');
    }
  }

  void _handleFetchError() {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      print('Failed 5 times, switching to Firebase fetching');
      if (!mounted) return;
      setState(() {
        _useFirebase = true;
        isLoading = true;
      });
      fetchDataFromFirebase();
    }
  }

  DatabaseReference get _firebaseRef => FirebaseDatabase.instance.ref(
    'RealTimeData/${widget.device['device_id']}',
  );

  void fetchDataFromFirebase() {
    _firebaseRef.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        if (!mounted) return;
        setState(() {
          temp0 = (data['temp0'] ?? 0.0).toDouble();
          temp1 = (data['temp1'] ?? 0.0).toDouble();
          moisture1 = data['moisture1'] ?? 0;
          moisture2 = data['moisture2'] ?? 0;
          water_level = (data['water_level'] ?? 0.0).toDouble();
          isLoading = false;
          connectionType = "Firebase connection";
        });
        _checkWarning(); // check warning after new data
      } else {
        print('No data found in Firebase RealTimeData/0934');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final avgTemp = (temp0 + temp1) / 2;
    final avgMoisture = (moisture1 + moisture2) / 2;

    bool warningActive = avgTemp > 35 || avgMoisture < 80 || water_level < 20;

    return Scaffold(
      backgroundColor: Color(0xFFF3FFEE),
      appBar: AppBar(
        title: Text(widget.device['device_name'] ?? 'Device Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: (isLoading || _useFirebase)
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeviceDashboardSettingsPage(
                          device: widget.device,
                          resolvedIps: resolvedIps,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 8),
                    Text(
                      'Running in ${connectionType}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (warningActive)
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Warning: Check device conditions!\n'
                                'Avg Temp: ${avgTemp.toStringAsFixed(1)}°C (Limit: 35°C)\n'
                                'Avg Moisture: ${avgMoisture.toStringAsFixed(0)}% (Min: 80%)\n'
                                'Water Level: ${water_level.toStringAsFixed(0)}% (Min: 20%)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    StaggeredGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        StaggeredGridTile.count(
                          crossAxisCellCount: 1,
                          mainAxisCellCount: 1,
                          child: _buildTile(
                            Color(0xFF49FF7D),
                            'Temperature 1',
                            '${temp0.toStringAsFixed(1)}°C',
                            Icons.thermostat,
                          ),
                        ),
                        StaggeredGridTile.count(
                          crossAxisCellCount: 1,
                          mainAxisCellCount: 1,
                          child: _buildTile(
                            Color(0xFF49FF7D),
                            'Temperature 2',
                            '${temp1.toStringAsFixed(1)}°C',
                            Icons.thermostat,
                          ),
                        ),
                        StaggeredGridTile.count(
                          crossAxisCellCount: 1,
                          mainAxisCellCount: 1,
                          child: _buildTile(
                            Color(0xFF3CB4FF),
                            'Moisture 1',
                            '$moisture1%',
                            Icons.water_drop,
                          ),
                        ),
                        StaggeredGridTile.count(
                          crossAxisCellCount: 1,
                          mainAxisCellCount: 1,
                          child: _buildTile(
                            Color(0xFF3CB4FF),
                            'Moisture 2',
                            '$moisture2%',
                            Icons.water_drop,
                          ),
                        ),
                        StaggeredGridTile.count(
                          crossAxisCellCount: 2,
                          mainAxisCellCount: 1,
                          child: _buildTile(
                            Color(0xFF3CB4FF),
                            'Water Level',
                            '${water_level.toStringAsFixed(1)}%',
                            Icons.water,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecordsListPage(
                              device_id: widget.device['device_id'].toString(),
                            ),
                          ),
                        );
                      },
                      child: Text("View Records"),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        minimumSize: Size(double.infinity, 48),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTile(Color color, String title, String content, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      height: 100,
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              content,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
