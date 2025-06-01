import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vermicompostmonitor/custom_functions/databasehelper.dart';

class DeviceDashboardSettingsPage extends StatefulWidget {
  final Map<String, dynamic> device;
  final List<String> resolvedIps;
  const DeviceDashboardSettingsPage({
    super.key,
    required this.device,
    required this.resolvedIps,
  });

  @override
  State<DeviceDashboardSettingsPage> createState() =>
      _DeviceDashboardSettingsPage();
}

class _DeviceDashboardSettingsPage extends State<DeviceDashboardSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3FFEE),
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsetsGeometry.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.device["device_name"]}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
            ),
            Text(
              '${widget.resolvedIps.first}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
            SizedBox(height: 25),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CalibrateStartUp(resolvedIps: widget.resolvedIps),
                  ),
                );
              },
              child: Text('Calibrate Sensors'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                minimumSize: Size(double.infinity, 48),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalibrateStartUp extends StatefulWidget {
  final List<String> resolvedIps;
  final Map<String, dynamic>? device;
  const CalibrateStartUp({
    super.key,
    required this.resolvedIps,
    this.device = null,
  });
  @override
  _CalibrateStartUp createState() => _CalibrateStartUp();
}

class _CalibrateStartUp extends State<CalibrateStartUp> {
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
              'Sensor Calibration',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "To have a accurate and better experience sensors must be calibrated. Just follow the following instructions and you will be done in a few minute.",
              style: TextStyle(fontSize: 16, color: Color(0xFF7B7B7B)),
            ),
            SizedBox(height: 8),
            Spacer(), // pushes the button to the bottom
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MoistureDryCalibration(
                      resolvedIps: widget.resolvedIps,
                      device: widget.device,
                    ),
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

class MoistureDryCalibration extends StatefulWidget {
  final List<String> resolvedIps;
  final Map<String, dynamic>? device;
  const MoistureDryCalibration({
    super.key,
    required this.resolvedIps,
    this.device,
  });
  @override
  _MoistureDryCalibration createState() => _MoistureDryCalibration();
}

class _MoistureDryCalibration extends State<MoistureDryCalibration> {
  bool isLoading = false;

  Future<void> _calibrateDry() async {
    setState(() => isLoading = true);
    await Future.delayed(Duration(seconds: 5)); // Delay for sensor to stabilize

    final url = Uri.parse(
      'http://${widget.resolvedIps.first}/calibrate?target=moisture_dry',
    );
    print(url);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MoistureWetCalibration(
              resolvedIps: widget.resolvedIps,
              device: widget.device,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calibration failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      setState(() => isLoading = false);
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
              'Moisture Sensor Calibration',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please make sure the 2 moisture sensor are dry.',
              style: TextStyle(fontSize: 16, color: Color(0xFF7B7B7B)),
            ),
            SizedBox(height: 20),
            Spacer(),
            isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _calibrateDry,
                    child: Text("Continue"),
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
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class MoistureWetCalibration extends StatefulWidget {
  final List<String> resolvedIps;
  final Map<String, dynamic>? device;
  const MoistureWetCalibration({
    super.key,
    required this.resolvedIps,
    this.device,
  });
  @override
  _MoistureWetCalibration createState() => _MoistureWetCalibration();
}

class _MoistureWetCalibration extends State<MoistureWetCalibration> {
  bool isLoading = false;

  Future<void> _calibrateWet() async {
    setState(() => isLoading = true);
    await Future.delayed(Duration(seconds: 5)); // Delay for sensor to stabilize

    final url = Uri.parse(
      'http://${widget.resolvedIps.first}/calibrate?target=moisture_wet',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaterLevelEmpty(
              resolvedIps: widget.resolvedIps,
              device: widget.device,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calibration failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      setState(() => isLoading = false);
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
              'Moisture Sensor Calibration',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Now submerged the 2 sensors into the water.',
              style: TextStyle(fontSize: 16, color: Color(0xFF7B7B7B)),
            ),
            SizedBox(height: 8),
            Spacer(), // pushes the button to the bottom
            isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _calibrateWet,
                    child: Text("Continue"),
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
            SizedBox(height: 8),

            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class WaterLevelEmpty extends StatefulWidget {
  final List<String> resolvedIps;
  final Map<String, dynamic>? device;
  const WaterLevelEmpty({super.key, required this.resolvedIps, this.device});
  @override
  _WaterLevelEmpty createState() => _WaterLevelEmpty();
}

class _WaterLevelEmpty extends State<WaterLevelEmpty> {
  bool isLoading = false;

  Future<void> _calibrateEmpty() async {
    setState(() => isLoading = true);
    await Future.delayed(Duration(seconds: 5)); // Delay for sensor to stabilize

    final url = Uri.parse(
      'http://${widget.resolvedIps.first}/calibrate?target=tankempty',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaterLevelFull(
              resolvedIps: widget.resolvedIps,
              device: widget.device,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calibration failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      setState(() => isLoading = false);
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
              'Water Level Sensor',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Place the sensor on top of your tank and make sure the tank is empty.',
              style: TextStyle(fontSize: 16, color: Color(0xFF7B7B7B)),
            ),
            SizedBox(height: 8),
            Spacer(), // pushes the button to the bottom
            isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _calibrateEmpty,
                    child: Text("Continue"),
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

            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class WaterLevelFull extends StatefulWidget {
  final List<String> resolvedIps;
  final Map<String, dynamic>? device;
  const WaterLevelFull({super.key, required this.resolvedIps, this.device});
  @override
  _WaterLevelFull createState() => _WaterLevelFull();
}

class _WaterLevelFull extends State<WaterLevelFull> {
  bool isLoading = false;

  Future<void> _calibrateFull() async {
    setState(() => isLoading = true);
    await Future.delayed(Duration(seconds: 5)); // Delay for sensor to stabilize

    final url = Uri.parse(
      'http://${widget.resolvedIps.first}/calibrate?target=tankfull',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CompleteCalibration(device: widget.device),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calibration failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      setState(() => isLoading = false);
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
              'Water Level Sensor',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Now fill up the tank with it's max capacity.",
              style: TextStyle(fontSize: 16, color: Color(0xFF7B7B7B)),
            ),
            SizedBox(height: 8),
            Spacer(), // pushes the button to the bottom
            isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _calibrateFull,
                    child: Text("Continue"),
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

            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class CompleteCalibration extends StatefulWidget {
  final Map<String, dynamic>? device;
  const CompleteCalibration({super.key, this.device});

  @override
  _CompleteCalibration createState() => _CompleteCalibration();
}

class _CompleteCalibration extends State<CompleteCalibration> {
  @override
  void initState() {
    super.initState();
    _updateIfDeviceExists();
  }

  Future<void> _updateIfDeviceExists() async {
    if (widget.device != null) {
      final device = widget.device!;
      await DatabaseHelper.instance.updateDevice(
        id: device['device_id'],
        name: device['device_name'],
        mdns: device['device_mdns'],
        ssid: device['wifi_ssid'],
        password: device['wifi_password'],
        calibrated: true, // Set calibrated to true (1 in DB)
      );
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
              'Calibration Complete',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Your sensors are now fully calibrated",
              style: TextStyle(fontSize: 16, color: Color(0xFF7B7B7B)),
            ),
            SizedBox(height: 8),
            Spacer(), // pushes the button to the bottom
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
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
