// Copyright 2018-present the Flutter authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ttc_ble/flutter_ttc_ble.dart';
import 'package:flutter_ttc_ble_example/ble_manager.dart';
import 'package:flutter_ttc_ble_example/oad_screen.dart';
import 'log_util.dart';

///数据交互页面
class CommPage extends StatefulWidget {
  final BLEDevice device;

  const CommPage({Key? key, required this.device}) : super(key: key);

  @override
  State<CommPage> createState() => _CommPageState();
}

class _CommPageState extends State<CommPage> with BleCallback2 {
  static const tag = 'CommPage';
  final _txDataController = TextEditingController(text: '123456');
  final _textStyle = const TextStyle(
      color: Color.fromARGB(0xff, 0, 0, 0),
      fontSize: 18,
      fontWeight: FontWeight.normal);

  late String _deviceId;
  String _connectionState = "Not connected";
  String _rxData = "";
  bool _disposed = false;

  @override
  void onBluetoothStateChanged(BluetoothState state) {
    jPrint('onBluetoothStateChanged() - state=$state');
  }

  @override
  void onConnected(String deviceId) {
    //与设备建立连接
    //todo 开启数据通知，这样才能实时接收设备端的数据
    BleManager().enableNotification(deviceId: deviceId);
    if (!_disposed) {
      setState(() {
        _connectionState = "Connected";
      });
    }
  }

  @override
  void onDisconnected(String deviceId) {
    //断开连接
    if (!_disposed) {
      setState(() {
        _connectionState = "Disconnected";
      });
    }
  }

  @override
  void onMtuChanged(String deviceId, int mtu) {
    //MTU变化（仅Android有该消息）
    jPrint('onMtuChanged() - $deviceId, mtu=$mtu');
  }

  @override
  void onConnectTimeout(String deviceId) {
    //连接超时
    jPrint('onConnectTimeout() - $deviceId');
  }

  @override
  void onNotificationStateChanged(String deviceId, String serviceUuid,
      String characteristicUuid, bool enabled, String? error) {
    jPrint(
        'onNotificationStateChanged() - $serviceUuid/$characteristicUuid enabled=$enabled, error=$error');
  }

  @override
  void onConnectionUpdated(String deviceId, int interval, int latency, int timeout, int status) {
    jPrint('onConnectionUpdated() - interval=$interval, latency=$latency, timeout=$timeout, status=$status');
  }

  @override
  void onDataReceived(String deviceId, String serviceUuid,
      String characteristicUuid, Uint8List data) {
    //收到数据
    /// 数据类型：Uint8List 即 java 端的 byte[]
    /// 具体参考：https://docs.flutter.io/flutter/services/StandardMessageCodec-class.html

    String utf8String = "";
    try {
      utf8String = utf8.decode(data);
    } on Exception catch (e) {
      jPrint(e);
    }

    String hexString = data.toHex();

    jPrint('<- utf8String=$utf8String, hexString=$hexString');

    if (!_disposed) {
      setState(() {
        _rxData = "${DateTime.now()}\nHEX: $hexString\nString: $utf8String";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    jPrint('CommPage initState()');
    _deviceId = widget.device.deviceId;
    //连接设备
    bleProxy.connect(deviceId: _deviceId);

    //TODO 监听平台消息
    bleProxy.addBleCallback(this);
  }

  @override
  void dispose() {
    jPrint('CommPage -> dispose()');
    _disposed = true;
    bleProxy.removeBleCallback(this);
    bleProxy.disconnect(deviceId: _deviceId); //断开连接
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope 监听左上角返回和实体返回
    return WillPopScope(
        onWillPop: _onBackPressed,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.device.name ?? 'Unknown Device',
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              children: <Widget>[
                const SizedBox(height: 16.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start, //子控件靠左
                  children: <Widget>[
                    Text(
                      _deviceId,
                      style: _textStyle,
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      _connectionState,
                      style: _textStyle,
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      "RX",
                      style: _textStyle,
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      _rxData,
                      style: _textStyle,
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Text(
                  "TX",
                  style: _textStyle,
                ),
                TextField(
                  controller: _txDataController,
                ),
                const SizedBox(height: 6.0),
                ElevatedButton(
                  child: const Text('SEND'),
                  onPressed: () {
                    ///发送数据
                    BleManager().sendData(
                        deviceId: _deviceId,
                        data: _stringToData(_txDataController.text));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    ElevatedButton(
                      child: const Text('CONNECT'),
                      onPressed: () {
                        ///连接设备
                        bleProxy.connect(deviceId: _deviceId);
                      },
                    ),
                    const SizedBox(width: 12.0),
                    ElevatedButton(
                      child: const Text('DISCONNECT'),
                      onPressed: () {
                        ///断开连接
                        bleProxy.disconnect(deviceId: _deviceId);
                      },
                    ),
                    const SizedBox(width: 12.0),
                    ElevatedButton(
                      child: const Text('READ'),
                      onPressed: () {
                        ///读取数据
                        // https://www.bluetooth.com/specifications/gatt/characteristics
                        // Generic Access: 00001800-0000-1000-8000-00805f9b34fb
                        // Device Name: 00002a00-0000-1000-8000-00805f9b34fb
                        bleProxy.read(
                            deviceId: _deviceId,
                            serviceUuid: Uuids.deviceInformation,
                            characteristicUuid: Uuids.softwareRevision);
                      },
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    ElevatedButton(
                      child: const Text('CONNECTION SATE'),
                      onPressed: () {
                        ///获取连接状态
                        _getConnectionState();
                      },
                    ),
                    const SizedBox(width: 12.0),
                    ElevatedButton(
                      child: const Text('REQUEST MTU'),
                      onPressed: () {
                        ///更新MTU
                        bleProxy.requestMtu(deviceId: _deviceId, mtu: 251);
                      },
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    ElevatedButton(
                      child: const Text('CONNECTION PRIORITY'),
                      onPressed: () {
                        ///更新链接参数
                        bleProxy.requestConnectionPriority(
                            deviceId: _deviceId,
                            priority: ConnectionPriority.high);
                      },
                    ),
                    const SizedBox(width: 12.0),
                    ElevatedButton(
                      child: const Text('GET SERVICES'),
                      onPressed: () {
                        ///获取GATT服务
                        bleProxy
                            .getGattServices(deviceId: _deviceId)
                            .then((services) => _printGattServices(services));
                      },
                    ),
                  ],
                ),
                ElevatedButton(onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => OADScreen(deviceId: _deviceId)));
                }, child: const Text('OAD'),),
              ],
            ),
          ),
        ));
  }

  void _printGattServices(List<GattService> services) {
    // print() 打印的字符串长度最大是1K，所以这里使用循环打印
    for (var service in services) {
      jPrint('$tag 服务: ${service.uuid}, isPrimary=${service.isPrimary}');
      for (var characteristic in service.characteristics) {
        jPrint('$tag\t特征: ${jsonEncode(characteristic)}');
      }
    }
  }

  void _getConnectionState() async {
    final bool connected = await bleProxy.isConnected(deviceId: _deviceId);
    jPrint('是否已连接：$connected');
  }

  Future<bool> _onBackPressed() {
    //用户点击了左上角返回按钮或实体返回建
    jPrint('用户点击了左上角返回按钮或实体返回建');
    Navigator.pop(context, "I'm back!");
    return Future.value(false);
  }

  /// 将 String 转化为 Uint8List
  Uint8List _stringToData(String hexValue) {
    Uint8List data;
    try {
      data = hexValue.toData();
    } on Exception catch (e) {
      jPrint(e);
      //HEX转化异常时按照字符转化
      //hexValue.codeUnits 的类型为 CodeUnits，需要转化一下
      data = Uint8List.fromList(hexValue.codeUnits);
    }
    return data;
  }
}
