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

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ttc_ble/flutter_ttc_ble.dart';

///数据交互页面
class CommPage extends StatefulWidget {
  final BLEDevice _device;

  CommPage(this._device);

  @override
  _CommPageState createState() => _CommPageState(_device);
}

class _CommPageState extends State<CommPage> {
  final _txDataController = TextEditingController();
  final _textStyle = TextStyle(
      color: Color.fromARGB(0xff, 0, 0, 0),
      fontSize: 18,
      fontWeight: FontWeight.normal);

  BLEDevice _device;
  String _connectionState = "Not connected";
  String _rxData = "";
  bool _disposed = false;

  _CommPageState(this._device);

  Function _bleCallback;

  @override
  void initState() {
    super.initState();
    print('CommPage initState()');
    // bool 参数：断线后是否重连（不包括APP发起的断线）
    FlutterTtcBle.connect(_device.deviceId, false);

    // TODO 接收平台端消息
    _bleCallback = (message) {
      //print("CommPage 接收到平台端消息 type=${message.runtimeType}");
      print("CommPage 收到BLE消息 $message");

      //Android 端发送 HashMap<String, Any> 消息，flutter 端接收类型为 Map<dynamic, dynamic>
      if (message is Map<dynamic, dynamic>) {
        if (message.containsKey('event')) {
          switch (message['event']) {
            case BLEEvent.CONNECTED: //与设备建立连接
              if (!_disposed) {
                setState(() {
                  _connectionState = "Connected";
                });
              }
              break;

            case BLEEvent.MTU_CHANGED: //MTU变化
              print(
                  'mtu_changed: ${message['deviceId']}, mtu=${message['mtu']}');
              break;

            case BLEEvent.CONNECT_TIMEOUT: //连接超时
              print('connect_timeout: ${message['deviceId']}');
              break;

            case BLEEvent.DISCONNECTED: //断开连接
              if (!_disposed) {
                setState(() {
                  _connectionState = "Disconnected";
                });
              }
              break;

            case BLEEvent.DATA_WRITTEN: //数据发送结果的通知
              {
                var status = message['status']; //int类型
//                Uint8List value = (message['value'] as Uint8List);
//                String utf8String = "";
//                try {
//                  utf8String = utf8.decode(value);
//                } on Exception catch (e) {
//                  print(e);
//                }
//
//                print(
//                    '数据发送结果 status=$status >>> ${hex.encode(value)}, utf8String=$utf8String');
                if (status == 0) {
                  //发送成功
                } else {
                  //发送失败
                }
              }
              break;

            case BLEEvent.DATA_AVAILABLE: //收到数据
              {
                /// 数据类型：Uint8List 即 java 端的 byte[]
                /// 具体参考：https://docs.flutter.io/flutter/services/StandardMessageCodec-class.html
                Uint8List value = (message['value'] as Uint8List);

                String utf8String = "";
                try {
                  utf8String = utf8.decode(value);
                } on Exception catch (e) {
                  print(e);
                }

                String hexString = hex.encode(value);

                print('<- utf8String=$utf8String, hexString=$hexString');

                if (!_disposed) {
                  setState(() {
                    _rxData =
                        "${DateTime.now()}\nHEX: $hexString\nString: $utf8String";
                  });
                }
              }
              break;
          }
        }
      }
    };

    //TODO 监听平台消息
    FlutterTtcBle.addBLECallBack(_bleCallback);
  }

  @override
  void didChangeDependencies() {
    print('CommPage -> didChangeDependencies()');
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(CommPage oldWidget) {
    print('CommPage -> didUpdateWidget()');
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    print('CommPage -> dispose()');
    _disposed = true;
    FlutterTtcBle.removeBLECallBack(_bleCallback);
    FlutterTtcBle.disconnect(_device.deviceId); //断开连接
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope 监听左上角返回和实体返回
    return new WillPopScope(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _device.name != null ? _device.name : 'Unknown Device',
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              children: <Widget>[
                SizedBox(height: 16.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start, //子控件靠左
                  children: <Widget>[
                    Text(
                      _device.deviceId,
                      style: _textStyle,
                    ),
                    SizedBox(height: 10.0),
                    Text(
                      _connectionState,
                      style: _textStyle,
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      "RX",
                      style: _textStyle,
                    ),
                    SizedBox(height: 10.0),
                    Text(
                      _rxData,
                      style: _textStyle,
                    ),
                  ],
                ),
                SizedBox(height: 10.0),
                Text(
                  "TX",
                  style: _textStyle,
                ),
                AccentColorOverride(
                  child: TextField(
                    controller: _txDataController,
                  ),
                ),
                SizedBox(height: 6.0),
                RaisedButton(
                  child: Text('SEND'),
                  onPressed: () {
                    ///发送数据
                    FlutterTtcBle.send(_device.deviceId,
                        _stringToData(_txDataController.text));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    RaisedButton(
                      child: Text('CONNECT'),
                      onPressed: () {
                        ///连接设备
                        FlutterTtcBle.connect(_device.deviceId, false);
                      },
                    ),
                    SizedBox(width: 12.0),
                    RaisedButton(
                      child: Text('DISCONNECT'),
                      onPressed: () {
                        ///断开连接
                        FlutterTtcBle.disconnect(_device.deviceId);
                      },
                    ),
                    SizedBox(width: 12.0),
                    RaisedButton(
                      child: Text('READ'),
                      onPressed: () {
                        ///读取数据
                        // https://www.bluetooth.com/specifications/gatt/characteristics
                        // Generic Access: 00001800-0000-1000-8000-00805f9b34fb
                        // Device Name: 00002a00-0000-1000-8000-00805f9b34fb
                        FlutterTtcBle.readCharacteristic(
                            _device.deviceId,
                            '00001800-0000-1000-8000-00805f9b34fb',
                            '00002a00-0000-1000-8000-00805f9b34fb');
                      },
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    RaisedButton(
                      child: Text('CONNECTION SATE'),
                      onPressed: () {
                        ///获取连接状态
                        _getConnectionState();
                      },
                    ),
                    SizedBox(width: 12.0),
                    RaisedButton(
                      child: Text('REQUEST MTU'),
                      onPressed: () {
                        ///更新MTU
                        FlutterTtcBle.requestMtu(_device.deviceId, 103);
                      },
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    RaisedButton(
                      child: Text('CONNECTION PRIORITY'),
                      shape: BeveledRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(1.0)),
                      ),
                      onPressed: () {
                        ///更新链接参数
                        FlutterTtcBle.requestConnectionPriority(
                            _device.deviceId, ConnectionPriority.high);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        onWillPop: _onBackPressed);
  }

  void _getConnectionState() async {
    final bool connected = await FlutterTtcBle.isConnected(_device.deviceId);
    print('是否已连接：$connected');
  }

  Future<bool> _onBackPressed() {
    //用户点击了左上角返回按钮或实体返回建
    print('用户点击了左上角返回按钮或实体返回建');
    Navigator.pop(context, "I\'m back!");
    return Future.value(false);
  }

  /// 将 String 转化为 Uint8List
  Uint8List _stringToData(String hexValue) {
    List<int> data;
    try {
      //长度为单数时 hex.decode() 会抛异常
      String hexComplete = hexValue.length % 2 == 0 ? hexValue : "0" + hexValue;
      data = hex.decode(hexComplete);
    } on Exception catch (e) {
      print(e);
      //HEX转化异常时按照字符转化
      //hexValue.codeUnits 的类型为 CodeUnits，需要转化一下
      data = Uint8List.fromList(hexValue.codeUnits);
    }
    return data;
  }
}

class AccentColorOverride extends StatelessWidget {
  const AccentColorOverride({Key key, this.color, this.child})
      : super(key: key);

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      child: child,
      data: Theme.of(context).copyWith(
        accentColor: color,
        brightness: Brightness.dark,
      ),
    );
  }
}
