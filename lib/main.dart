import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc_app/screens/my_screen.dart';
import 'screens/join_screen.dart';
import 'services/signalling.service.dart';

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = DevHttpOverrides();

  ByteData data =
      await PlatformAssetBundle().load('assets/ssl/server-cert.pem');
  SecurityContext.defaultContext
      .setTrustedCertificatesBytes(data.buffer.asUint8List());

  // start videoCall app
  runApp(VideoCallApp());
}

class VideoCallApp extends StatelessWidget {
  VideoCallApp({super.key});

  // generate callerID of local user
  // final String selfCallerID =
  //     Random().nextInt(999999).toString().padLeft(6, '0');
  final String selfCallerID = "shivanshukgupta@gmail.com";

  @override
  Widget build(BuildContext context) {
    // init signalling service
    // SignallingService.instance.init(
    //   websocketUrl: websocketUrl,
    //   selfCallerID: selfCallerID,
    // );

    // return material app
    return MaterialApp(
      darkTheme: ThemeData.dark().copyWith(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(),
      ),
      themeMode: ThemeMode.dark,
      home: MyScreen(),
    );
  }
}
