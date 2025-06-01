import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('VermiCompostDevices.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE devices (
        device_id INTEGER PRIMARY KEY,
        device_name TEXT NOT NULL,
        device_mdns TEXT NOT NULL,
        wifi_ssid TEXT NOT NULL,
        wifi_password TEXT NOT NULL,
        device_calibrated INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertDevice({
    required int id,
    required String name,
    required String mdns,
    required String ssid,
    required String password,
    required bool calibrated,
  }) async {
    final db = await instance.database;
    return await db.insert('devices', {
      'device_id': id,
      'device_name': name,
      'device_mdns': mdns,
      'wifi_ssid': ssid,
      'wifi_password': password,
      'device_calibrated': calibrated ? 1 : 0,
    });
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final db = await instance.database;
    return await db.query('devices');
  }

  Future<int> updateDevice({
    required int id,
    required String name,
    required String mdns,
    required String ssid,
    required String password,
    required bool calibrated,
  }) async {
    final db = await instance.database;
    return await db.update(
      'devices',
      {
        'device_name': name,
        'device_mdns': mdns,
        'wifi_ssid': ssid,
        'wifi_password': password,
        'device_calibrated': calibrated ? 1 : 0,
      },
      where: 'device_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDevice(int id) async {
    final db = await instance.database;
    return await db.delete('devices', where: 'device_id = ?', whereArgs: [id]);
  }
}
