import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:vermicompostmonitor/custom_functions/databasehelper.dart';

class SessionStorage {
  static final SessionStorage _instance = SessionStorage._internal();

  factory SessionStorage() => _instance;

  SessionStorage._internal();

  // Example fields to store data
  Map<String, dynamic> handshakeData = {};
  String? device_name;
  String? ssid;
  String? password;

  void clear() {
    ssid = null;
    password = null;
    handshakeData.clear();
  }
}

class DevicePairingInitial extends StatefulWidget {
  @override
  _DevicePairingInitial createState() => _DevicePairingInitial();
}

class _DevicePairingInitial extends State<DevicePairingInitial> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Power Up',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Plug in your vermicompost device and wait about 30 seconds.',
              style: TextStyle(fontSize: 16, color: Color(0xFF7B7B7B)),
            ),
            SizedBox(height: 8),
            Text(
              'Tip: Keep your phone or tablet close to the vermicompost device through out the setup',
              style: TextStyle(fontSize: 16, color: Color(0xFF7B7B7B)),
            ),
            Spacer(), // pushes the button to the bottom
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConnectToDevicePage(),
                  ),
                );
              },
              child: Text("Continue"),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                minimumSize: Size(double.infinity, 48), // full-width
                backgroundColor: Colors.blue, // button background
                foregroundColor: Colors.white, // text/icon color
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class ConnectToDevicePage extends StatefulWidget {
  @override
  _ConnectToDevicePage createState() => _ConnectToDevicePage();
}

class _ConnectToDevicePage extends State<ConnectToDevicePage> {
  bool isLoading = false;

  Future<void> _attemptHandshakeAndNavigate() async {
    setState(() => isLoading = true);

    try {
      final response = await http
          .get(Uri.parse('http://10.0.0.1/handshake'))
          .timeout(Duration(seconds: 5)); // Add timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Received handshake response: $data');
        SessionStorage().handshakeData = data;

        // Navigate only if successful
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WifiScannerPage()),
        );
      } else {
        _showError(
          'Device responded with error: ${response.statusCode}. Are you connected to the correct Wi-Fi?',
        );
      }
    } on http.ClientException catch (e) {
      _showError('Connection failed: $e');
    } on TimeoutException {
      _showError(
        'Connection timed out. Make sure you are connected to the VermiCompost device.',
      );
    } catch (e) {
      _showError('Unexpected error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect to Your VermiCompost Device',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Go to your phone's or tablet's Wi-Fi settings and join your VermiCompost Device's network: Vermi_Compost_XXXX. Then return to this app.",
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
            SizedBox(height: 8),
            Text(
              "XXXX is the 4 digit of Vermi Compost's Device ID",
              style: TextStyle(fontSize: 16, color: Color(0xFF7B7B7B)),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: isLoading ? null : _attemptHandshakeAndNavigate,
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("I'm Already Connected"),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                minimumSize: Size(double.infinity, 48),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class WifiScannerPage extends StatefulWidget {
  @override
  _WifiScannerPageState createState() => _WifiScannerPageState();
}

class _WifiScannerPageState extends State<WifiScannerPage> {
  List<WiFiAccessPoint> accessPoints = [];

  @override
  void initState() {
    super.initState();
    checkAndScan();
  }

  Future<void> checkAndScan() async {
    final can = await WiFiScan.instance.canStartScan();
    if (can == CanStartScan.yes) {
      await WiFiScan.instance.startScan();
      final results = await WiFiScan.instance.getScannedResults();
      setState(() {
        accessPoints = results;
      });
    } else {
      print("Can't scan WiFi: $can");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Wifi Network',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Select your local Wi-Fi network with an internet connection.",
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                  ), // Border color & width
                  borderRadius: BorderRadius.circular(12), // Border radius
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    12,
                  ), // Clip child to radius
                  child: ListView.builder(
                    itemCount: accessPoints.length,
                    itemBuilder: (context, index) {
                      final ap = accessPoints[index];
                      return ListTile(
                        title: Text(ap.ssid),
                        subtitle: Text(
                          ap.capabilities.contains("WPA") ||
                                  ap.capabilities.contains("WEP") ||
                                  ap.capabilities.contains("WPA2") ||
                                  ap.capabilities.contains("WPA3")
                              ? "Secured"
                              : "Open",
                        ),
                        trailing: Icon(
                          ap.capabilities.contains("WPA") ||
                                  ap.capabilities.contains("WEP") ||
                                  ap.capabilities.contains("WPA2") ||
                                  ap.capabilities.contains("WPA3")
                              ? Icons.lock
                              : Icons.lock_open,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          if (ap.capabilities.contains("WPA") ||
                              ap.capabilities.contains("WEP") ||
                              ap.capabilities.contains("WPA2") ||
                              ap.capabilities.contains("WPA3")) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    GivePasswordWidget(ssid: ap.ssid),
                              ),
                            );
                          } else {}
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class GivePasswordWidget extends StatefulWidget {
  final String ssid;

  const GivePasswordWidget({Key? key, required this.ssid}) : super(key: key);

  @override
  _GivePasswordWidgetState createState() => _GivePasswordWidgetState();
}

class _GivePasswordWidgetState extends State<GivePasswordWidget> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connectToNetwork() async {
    final password = _passwordController.text.trim();
    final ssid = widget.ssid;

    if (password.isEmpty) {
      _showError('Please enter a password.');
      return;
    }

    final uri = Uri.parse(
      'http://10.0.0.1/connect_to_network?ssid=${Uri.encodeComponent(ssid)}&password=${Uri.encodeComponent(password)}',
    );

    setState(() => _isLoading = true);

    try {
      final response = await http.get(uri).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        SessionStorage().ssid = ssid;
        SessionStorage().password = password;
        final body = response.body.trim().toLowerCase();
        if (body == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Network connection successful.")),
          );
          // Navigate or show success here if needed
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FinalizeSetupPage()),
          );
        } else {
          _showError('Failed to connect. Server response: $body');
        }
      } else {
        _showError('Failed to connect. Error: ${response.statusCode}');
      }
    } on TimeoutException {
      _showError('Connection timed out.');
    } catch (e) {
      _showError('Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter Password for '${widget.ssid}'",
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _isPasswordHidden,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordHidden = !_isPasswordHidden;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _connectToNetwork,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Connect'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                minimumSize: Size(double.infinity, 48),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class FinalizeSetupPage extends StatefulWidget {
  const FinalizeSetupPage({Key? key}) : super(key: key);

  @override
  _FinalizeSetupPage createState() => _FinalizeSetupPage();
}

class _FinalizeSetupPage extends State<FinalizeSetupPage> {
  final TextEditingController _DeviceNameController = TextEditingController(
    text: SessionStorage().handshakeData["device_name"],
  );
  bool _isLoading = false;
  Future<void> _saveDevice() async {
    setState(() => _isLoading = true);

    try {
      // 1. Insert into SQLite
      await DatabaseHelper.instance.insertDevice(
        id: int.parse(SessionStorage().handshakeData["device_id"]),
        name: _DeviceNameController.text,
        mdns: SessionStorage().handshakeData["device_mdns"],
        ssid: SessionStorage().ssid ?? "",
        password: SessionStorage().password ?? "",
        calibrated: false,
      );

      // 3. Navigate to root ('/')
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showError('Error: $e');
      print(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Where Almost There!",
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 8),
            Text(
              "Enter a name for this device.",
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _DeviceNameController,
              decoration: InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
                // Remove suffixIcon since it's not for password
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveDevice,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Finish Setup'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                minimumSize: Size(double.infinity, 48),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
