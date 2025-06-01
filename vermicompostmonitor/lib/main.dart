import 'package:flutter/material.dart';
import 'pages/pairing_sequence/device_pairing.dart';
import 'package:vermicompostmonitor/custom_functions/databasehelper.dart';
import 'package:vermicompostmonitor/pages/home/home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:vermicompostmonitor/pages/login/google_login.dart';
import 'package:http/http.dart' as http;
import 'package:vermicompostmonitor/pages/device_dashboard/device_settings.dart';

class LoggingHttpClient extends http.BaseClient {
  final http.Client _inner;

  LoggingHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    print('HTTP Request: ${request.method} ${request.url}');
    return _inner.send(request).then((response) {
      print('HTTP Response: ${response.statusCode} ${response.reasonPhrase}');
      return response;
    });
  }
}

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔧 Eagerly initialize the database
  await DatabaseHelper.instance.database;
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF96FF6D)),
        useMaterial3: true,
      ),
      initialRoute: '/SignIn',

      routes: {
        '/SignIn': (context) => GoogleSignInPage(),
        '/DevicesGrid': (context) => DevicesGridPage(),
        '/AddNewDevice': (context) => DevicePairingInitial(),
      },
    );
  }
}
