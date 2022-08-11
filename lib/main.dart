import 'package:flutter/material.dart';
import 'package:flutter_ttc_ble/flutter_ttc_ble.dart';
import 'package:flutter_ttc_ble/scan_screen.dart';

import 'communication.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ScanScreen(
        title: 'TTC Flutter BLE Demo',
        onDeviceClick: (BuildContext context, BLEDevice device) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CommPage(device: device)));
        },
      ),
    );
  }
}
