import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

///iOS选取升级文件(.bin)
class SelectFileScreen extends StatefulWidget {
  final List<String> fileExtensions;

  const SelectFileScreen({Key? key, required this.fileExtensions}) : super(key: key);

  @override
  State<SelectFileScreen> createState() => _SelectFileScreenState();
}

class _SelectFileViewModel extends ChangeNotifier {
  List<String> _documentFiles = [];

  List<String> get documentFiles => _documentFiles;

  set documentFiles(List<String> value) {
    _documentFiles = value;
    notifyListeners();
  }
}

class _SelectFileScreenState extends State<SelectFileScreen> {
  late List<String> fileExtensions;
  final _viewModel = _SelectFileViewModel();



  Future<List<String>> _pickDocumentFiles() async {
    final docDir = await getApplicationDocumentsDirectory();
    final documentPath = docDir.path;
    Directory dir = Directory(documentPath);
    return dir
        .list()
        .map((event) => event.path)
        .where((event) => fileExtensions.any((fileExtension) => event.endsWith(fileExtension)))
        .toList();
  }

  String _parseFileName(String path) {
    final idx = path.lastIndexOf('/');
    return path.substring(idx + 1);
  }

  @override
  void initState() {
    fileExtensions = widget.fileExtensions;
    _pickDocumentFiles().then((value) => _viewModel.documentFiles = value);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<_SelectFileViewModel>(
      create: (context) => _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('选择文件'),
        ),
        body: Consumer<_SelectFileViewModel>(
          builder: (context, vm, child) {
            return ListView.builder(
              itemCount: vm.documentFiles.length,
              itemBuilder: (context, index) {
                return ListTile(
                  onTap: () {
                    Navigator.pop(context, vm.documentFiles[index]);
                  },
                  title: Text(_parseFileName(vm.documentFiles[index])),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
