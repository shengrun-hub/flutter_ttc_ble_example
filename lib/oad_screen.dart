import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ttc_ble/flutter_ttc_ble.dart';
import 'package:flutter_ttc_ble/oad/oad.dart';
import 'package:flutter_ttc_ble/oad/oad_listener.dart';
import 'package:flutter_ttc_ble/oad/oad_proxy.dart';
import 'dart:io';

import 'package:flutter_ttc_ble_example/select_file_screen.dart';
import 'package:provider/provider.dart';

class OADScreen extends StatefulWidget {
  final String deviceId;

  const OADScreen({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<OADScreen> createState() => _OADScreenState();
}

class _OADScreenViewModel extends ChangeNotifier {
  String _filepath = '';
  OADProxy? _oadProxy;
  double _oadProgress = 0;
  bool _isProgramming = false;
  final List<String> logs = [];
  final ScrollController logController = ScrollController();

  void addLog(String msg) {
    logs.add('${currentTime('HH:mm:ss.SSS')} / $msg');
    if (logs.length > 2000) {
      logs.removeAt(0);
    }
    logController.jumpTo(logController.position.maxScrollExtent);
    notifyListeners();
  }

  void clearLog() {
    logs.clear();
    notifyListeners();
  }

  bool get isProgramming => _isProgramming;

  set isProgramming(bool value) {
    _isProgramming = value;
    notifyListeners();
  }

  double get oadProgress => _oadProgress;

  set oadProgress(value) {
    _oadProgress = value;
    notifyListeners();
  }

  String get filepath => _filepath;

  set filepath(value) {
    _filepath = value;
    notifyListeners();
  }

  OADProxy? get oadProxy => _oadProxy;

  void updateOADProxy(OADType type, OADListener listener) {
    _oadProxy?.release();
    _oadProxy = OADProxy.getOADProxy(type, listener);
    notifyListeners();
  }
}

class _OADScreenState extends State<OADScreen> with OADListener, BleCallback2 {
  final _OADScreenViewModel _viewModel = _OADScreenViewModel();
  final _assetsFile = "assets/TCR2_04_01_20200423_V3.3.bin";
  late String _deviceId;

  Future _pickFile() async {
    if (Platform.isAndroid) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        String? path = result.files.single.path;
        print('selected file path: $path');
        if (path != null) {
          //todo
          _viewModel.filepath = path;
        }
      } else {
        // User canceled the picker
      }
    } else {
      //iOS从沙盒目录中选文件
      final result = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const SelectFileScreen(
                    fileExtensions: ['.bin'],
                  )));
      if (result is String) {
        final String path = result;
        print('selected file path: $path');
        //todo
        _viewModel.filepath = path;
      }
    }
  }

  void _writeOADResetCMD() {
    _viewModel.addLog('_writeOADResetCMD()');
    //01CC33C33CAA55A55A0102030405060504030201
    bleProxy.write(
        deviceId: _deviceId,
        serviceUuid: Uuids.tiResetService,
        characteristicUuid: Uuids.tiReset,
        value: '01CC33C33CAA55A55A0102030405060504030201'.toData());
  }

  @override
  void onDisconnected(String deviceId) {
    _viewModel.addLog('onDisconnected()');
  }

  @override
  void onMtuChanged(String deviceId, int mtu) {
    _viewModel.addLog('onMtuChanged() - mtu=$mtu');
  }

  @override
  void initState() {
    _deviceId = widget.deviceId;
    _viewModel._oadProxy = OADProxy.getOADProxy(OADType.cc2640R2OAD, this);
    bleProxy.addBleCallback(this);
    super.initState();
  }

  @override
  void dispose() {
    _viewModel._oadProxy?.release();
    bleProxy.removeBleCallback(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<_OADScreenViewModel>(
      create: (context) => _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OAD'),
        ),
        body: Consumer<_OADScreenViewModel>(
          builder: (context, vm, child) {
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                      controller: vm.logController,
                      // shrinkWrap: true,
                      // physics: NeverScrollableScrollPhysics(), //禁止滚动
                      itemCount: vm.logs.length,
                      itemBuilder: (context, index) {
                        return Text(vm.logs[index]);
                      }),
                ),
                _buildProgress(vm),
                _buildSpinner(vm),
                _buildFile(vm),
                _buildOADButtons(vm),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOADButtons(_OADScreenViewModel vm) {
    return Row(
      children: [
        const SizedBox(width: 10),
        Expanded(child: Container()),
        ElevatedButton(
          onPressed: () {
            _writeOADResetCMD();
          },
          child: const Text('OAD Reset'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () {
            //todo
            if (!vm.isProgramming) {
              vm.oadProxy?.prepare(_deviceId, vm.filepath, false);
              // vm.oadProxy
              //     ?.prepare(_deviceId, _assetsFile, true);
            } else {
              vm.oadProxy?.stopProgramming();
              vm.isProgramming = false;
            }
          },
          child: Text(vm.isProgramming ? '停止升级' : '开始升级'),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildFile(_OADScreenViewModel vm) {
    return Row(
      children: [
        Expanded(child: Text('升级文件 ${vm.filepath}')),
        ElevatedButton(
            onPressed: () {
              _pickFile();
            },
            child: const Text('选择文件')),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildProgress(_OADScreenViewModel vm) {
    return Row(
      children: [
        const SizedBox(width: 10),
        Text('${vm.oadProgress ~/ 1}%'),
        Expanded(
          child: LinearProgressIndicator(
            value: vm.oadProgress / 100, //value的范围是0~1
            valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.blue),
            backgroundColor: Colors.grey,
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildSpinner(_OADScreenViewModel vm) {
    final items = [OADType.cc2640R2OAD, OADType.largeMtuOAD]
        .map((e) =>
            DropdownMenuItem<OADType>(value: e, child: Text(_oadTypeDesc(e))))
        .toList();
    return Row(
      children: [
        const SizedBox(width: 10),
        const Text('升级类型'),
        const SizedBox(width: 10),
        DropdownButton<OADType>(
          items: items,
          value: vm.oadProxy?.type ?? OADType.cc2640R2OAD,
          onChanged: (type) {
            //更新升级代理
            vm.updateOADProxy(type!, this);
          },
        ),
      ],
    );
  }

  String _oadTypeDesc(OADType type) {
    switch (type) {
      case OADType.cc2640R2OAD:
        return "CC2640 R2 OAD";
      case OADType.largeMtuOAD:
        return "Large MTU OAD";
      default:
        return type.toString();
    }
  }

  @override
  void onBlockWrite(String deviceId, Uint8List bytes) {
    // print("onBlockWrite() - ${bytes.toHex(withSpace: true)}");
    _viewModel.addLog("onBlockWrite() - ${bytes.toHex(withSpace: true)}");
  }

  @override
  void onFinished(String deviceId, int nBytes, int milliseconds) {
    _viewModel.addLog("onFinished()");
    _viewModel.isProgramming = false;
  }

  @override
  void onInterrupted(
      String deviceId, int iBytes, int nBytes, int milliseconds) {
    //
  }

  @override
  void onPrepared(String deviceId) {
    _viewModel.addLog("准备就绪，开始升级……");
    _viewModel.oadProxy?.startProgramming(30);
    _viewModel.isProgramming =
        _viewModel.oadProxy != null && _viewModel.oadProxy!.isProgramming();
  }

  @override
  void onProgressChanged(
      String deviceId, int iBytes, int nBytes, int milliseconds) {
    _viewModel.oadProgress = iBytes * 100 / nBytes;
    // int progress = (iBytes * 100 / nBytes) ~/ 1;
    // print("onProgressChanged() - $progress%");
  }

  @override
  void onStatusChange(String deviceId, int status) {
    _viewModel.addLog(OADStatus.getMessage(status));
  }
}
