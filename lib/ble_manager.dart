import 'dart:typed_data';

import 'package:flutter_ttc_ble/flutter_ttc_ble.dart';

//与蓝牙设备通信的UUID
const uuidService = '00001000-0000-1000-8000-00805f9b34fb';
const uuidWrite = '00001001-0000-1000-8000-00805f9b34fb';
const uuidNotify = '00001002-0000-1000-8000-00805f9b34fb';

class BleManager {
  static final BleManager _bleManager = BleManager._sharedInstance();

  BleManager._sharedInstance();

  factory BleManager() => _bleManager;

  ///发送数据
  void sendData({required String deviceId, required Uint8List data}) {
    FlutterTtcBle.writeCharacteristic(
        deviceId: deviceId,
        serviceUuid: uuidService,
        characteristicUuid: uuidWrite,
        value: data,
        writeType: CharacteristicWriteType.writeNoResponse);
  }

  ///开启通知以接收设备端数据
  void enableNotification({required String deviceId}) {
    FlutterTtcBle.setCharacteristicNotification(
        deviceId: deviceId,
        serviceUuid: uuidService,
        characteristicUuid: uuidNotify,
        enable: true);
  }
}
