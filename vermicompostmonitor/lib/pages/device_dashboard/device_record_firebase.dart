import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

String formatTimestamp(String unixTimestamp) {
  final int timestamp = int.tryParse(unixTimestamp) ?? 0;
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  final formatter = DateFormat('hh:mm a MMM/dd/yyyy'); // includes AM/PM
  return formatter.format(date);
}

class RecordsListPage extends StatefulWidget {
  final String device_id;
  @override
  const RecordsListPage({super.key, required this.device_id});
  _RecordsListPageState createState() => _RecordsListPageState();
}

class _RecordsListPageState extends State<RecordsListPage> {
  late DatabaseReference _ref;
  List<Record> records = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    final deviceId = widget.device_id;
    _ref = FirebaseDatabase.instance.ref('RecordsData/$deviceId');
    print(widget.device_id);

    _ref.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        List<Record> loadedRecords = [];

        data.forEach((key, value) {
          loadedRecords.add(
            Record(
              timestamp: key,
              moisture1: value['moisture1']?.toDouble() ?? 0,
              moisture2: value['moisture2']?.toDouble() ?? 0,
              temp0: value['temp0']?.toDouble() ?? 0,
              temp1: value['temp1']?.toDouble() ?? 0,
              waterLevel: value['water_level']?.toDouble() ?? 0,
            ),
          );
        });

        // Sort records by timestamp in descending order (newest to oldest)
        loadedRecords.sort(
          (a, b) => int.parse(b.timestamp).compareTo(int.parse(a.timestamp)),
        );

        setState(() {
          records = loadedRecords;
          isLoading = false;
        });
      } else {
        setState(() {
          records = [];
          isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Records List')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : records.isEmpty
          ? Center(child: Text('No Records Found'))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(formatTimestamp(record.timestamp)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Moisture1: ${record.moisture1}'),
                        Text('Moisture2: ${record.moisture2}'),
                        Text('Temp0: ${record.temp0}°C'),
                        Text('Temp1: ${record.temp1}°C'),
                        Text('Water Level: ${record.waterLevel}'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class Record {
  final String timestamp;
  final double moisture1;
  final double moisture2;
  final double temp0;
  final double temp1;
  final double waterLevel;

  Record({
    required this.timestamp,
    required this.moisture1,
    required this.moisture2,
    required this.temp0,
    required this.temp1,
    required this.waterLevel,
  });
}
