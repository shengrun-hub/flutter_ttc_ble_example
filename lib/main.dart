import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ttc_ble/flutter_ttc_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'communication.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<BLEDevice> _dataList = <BLEDevice>[];
  Function _bleCallback;

  @override
  void initState() {
    super.initState();
    print('main -> initState()');
    WidgetsBinding.instance.addObserver(this);

    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    //TODO BLE 插件初始化
    FlutterTtcBle.init();

    /// 添加蓝牙事件监听
    _bleCallback = (message) {
      if (message is Map<dynamic, dynamic>) {
        if (message.containsKey('event')) {
          switch (message['event']) {
            case 'bluetooth_state_changed':
              if (message['state'] == 'on') {
                print('main -> 蓝牙打开');
                _refresh(); //开始扫描
              }
              if (message['state'] == 'off') {
                print('main -> 蓝牙关闭');
              }
              break;
          }
        }
      }
      return;
    };
    FlutterTtcBle.addBLECallBack(_bleCallback);
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  @override
  void didChangeDependencies() {
    print('main -> didChangeDependencies()');
    super.didChangeDependencies();
  }

  @override
  void deactivate() {
    //当State对象从树中被移除时，会调用此回调。
    print('main -> deactivate()');
    super.deactivate();
  }

  @override
  void dispose() {
    //当State对象从树中被永久移除时调用，通常在此回调中释放资源。
    print('main -> dispose()');
    FlutterTtcBle.removeBLECallBack(_bleCallback);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  //Flutter生命周期：https://blog.csdn.net/brycegao321/article/details/86583223
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('main -> didChangeAppLifecycleState() - state=$state');
    if (state == AppLifecycleState.paused) {
      FlutterTtcBle.stopLeScan();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    //print('main -> build()');
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter BLE Demo V1.2'),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            itemBuilder: (context, index) {
              return _buildRow(_dataList[index]);
            },
            itemCount: _dataList.length,
            separatorBuilder: (context, index) => Divider(
                thickness: 0.8, color: Color.fromARGB(0xff, 0xdd, 0xdd, 0xdd)),
          ),
        ),
      ),
    );
  }

  ///下拉刷新（扫描设备）
  Future<Null> _refresh() async {
    var scan = await _checkScan();
    if (!scan) return;

    setState(() {
      _dataList.clear();
    });

    FlutterTtcBle.startLeScan((device) {
      setState(() {
        //刷新UI要在setState()方法内进行
        //为了防止列表中设备重复，这里判断一下
        if (!_dataList.contains(device)) _dataList.add(device);
      });
      return;
    });

    await Future.delayed(Duration(seconds: 5), () {
      print('refresh() - delayed 5s');
      setState(() {
        //
      });
    });
  }

  ///安卓蓝牙扫描麻烦呀，扫描前得检查一通
  Future<bool> _checkScan() async {
    var isBluetoothEnabled = await FlutterTtcBle.isBluetoothEnabled();
    if (!isBluetoothEnabled) {
      print('请求打开蓝牙');
      FlutterTtcBle.requestEnableBluetooth();
      return false;
    }

    var isLocationEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!isLocationEnabled) {
      print('请求打开位置服务');
      _showAlertDialog('扫描设备需要开启位置服务，点击“设置”，可开启位置服务。', '设置', () {
        FlutterTtcBle.requestEnableLocationService();
      });
      return false;
    }

    // Use location.
    //https://pub.dev/packages/permission_handler
    var status = await Permission.location.request();

    switch (status) {
      case PermissionStatus.denied:
        print('XXX 用户拒绝访问位置权限');
        return false;

      case PermissionStatus.granted:
        print('用户允许访问位置权限');
        return true;

      case PermissionStatus.permanentlyDenied: //Only supported on Android
        print('XXX 用户拒绝访问位置权限，且不再询问');
        _showAlertDialog('扫描设备需要位置权限，点击“设置”->“权限管理”，可开启位置权限。', '设置', () {
          openAppSettings();
        });
        return false;

      case PermissionStatus.restricted: //Only supported on iOS
        print('XXX restricted');
        break;

      case PermissionStatus.undetermined:
        print('尚未请求过位置权限');
        break;
    }
    return false;
  }

  ///加载列表项
  Widget _buildRow(BLEDevice device) {
    // 这里使用 Builder 避免异常：Navigator operation requested with a context that does not include a Navigator.
    // 参考 https://blog.csdn.net/nimeghbia/article/details/84388725

    return Builder(
      builder: (context) => new ListTile(
        title: new Text(
          device.name != null ? device.name : "Unknown Device",
        ),
        subtitle: new Text(
          '${device.deviceId}'
          '\nAdvertisData=${_advertisDataToString(device.advertisData)}'
          '\nServiceUUIDs=${device.advertisServiceUUIDs}'
          '\nServiceData=${_serviceDataToString(device.serviceData)}',
        ),
        onTap: () {
          _toCommPage(context, device);
        },
      ),
    );
  }

  String _advertisDataToString(Uint8List advertisData) {
    return advertisData == null ? "" : hex.encode(advertisData);
  }

  String _serviceDataToString(Map<String, Uint8List> serviceData) {
    StringBuffer sb = StringBuffer('{');
    int i = 0;
    serviceData.forEach((uuid, data) => (String uuid, Uint8List data) {
          sb.write("$uuid: ${hex.encode(data)}");
          if (i < serviceData.length - 1) {
            sb.write(', ');
          }
          i++;
        });
    sb.write('}');
    return sb.toString();
  }

  ///跳转到数据交互页面
  void _toCommPage(BuildContext context, BLEDevice device) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (BuildContext context) => CommPage(device)),
    );

    print('从数据交互页面返回 $result');

    ///这是在页面底部显示一个弹出提示
    //Scaffold.of(context).showSnackBar(SnackBar(content: Text(result)));
    //TODO 监听平台消息
  }


  Future<void> _showAlertDialog(
      String message, String okText, Function okCallback) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(message),
          actions: <Widget>[
            FlatButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text(okText),
              onPressed: () {
                Navigator.of(context).pop();
                okCallback();
              },
            ),
          ],
        );
      },
    );
  }
}
