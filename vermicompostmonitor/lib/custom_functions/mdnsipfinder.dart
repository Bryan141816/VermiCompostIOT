import 'package:multicast_dns/multicast_dns.dart';

final MDnsClient _sharedClient = MDnsClient();
bool _clientStarted = false;

Future<List<String>> resolveMdnsHostname(String hostname) async {
  // Start the shared client if it's not already running
  if (!_clientStarted) {
    await _sharedClient.start();
    _clientStarted = true;
  }

  final String queryName = '$hostname.local';
  List<String> ips = [];

  try {
    await for (final IPAddressResourceRecord record
        in _sharedClient
            .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(queryName),
            )
            .timeout(Duration(seconds: 5), onTimeout: (sink) => sink.close())) {
      ips.add(record.address.address);
      print('Found IPv4: ${record.address}');
    }
  } catch (e) {
    print('mDNS lookup error for $hostname: $e');
  }

  return ips;
}
