import 'package:flutter/material.dart';
import "package:vermicompostmonitor/custom_functions/databasehelper.dart"; // Adjust path as needed
import 'package:vermicompostmonitor/pages/device_dashboard/device_dashboard.dart';
import 'package:vermicompostmonitor/main.dart';

class DevicesGridPage extends StatefulWidget {
  @override
  _DevicesGridPageState createState() => _DevicesGridPageState();
}

class _DevicesGridPageState extends State<DevicesGridPage> with RouteAware {
  late Future<List<Map<String, dynamic>>> _devicesFuture;

  void _loadDevices() {
    setState(() {
      _devicesFuture = DatabaseHelper.instance.getDevices();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when user comes back to this screen
    _loadDevices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Devices'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_sharp),
            onPressed: () {
              Navigator.pushNamed(context, '/AddNewDevice');
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading devices'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No devices found'));
          }

          final devices = snapshot.data!;
          print(devices);

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return DeviceTile(
                name: device['device_name'],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceDashboardPage(device: device),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class DeviceTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const DeviceTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.dns, size: 30),

              SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
