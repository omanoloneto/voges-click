import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../painting/image_formats.dart';

class OpenedFile {
  const OpenedFile({required this.name, required this.bytes, this.path});

  final String name;
  final Uint8List bytes;

  /// Where Save can write back; null when the file came as a copy.
  final String? path;
}

/// Titles of the system file dialogs, in the user's language.
class FileDialogTitles {
  const FileDialogTitles({this.open = 'Open image', this.save = 'Save image'});

  final String open;
  final String save;
}

/// Opens and saves image files with the system dialogs.
class ImageFiles {
  FileDialogTitles titles = const FileDialogTitles();

  /// The paths of the files the user chose; none if canceled.
  Future<List<String>> pick() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: titles.open,
      type: FileType.custom,
      allowedExtensions: openableExtensions,
      allowMultiple: true,
    );
    return [...?result?.paths.nonNulls];
  }

  Future<OpenedFile> read(String path) async => OpenedFile(
    name: path.split(Platform.pathSeparator).last,
    bytes: await File(path).readAsBytes(),
    path: path,
  );

  /// The path the user chose, with the format's extension; null if canceled.
  Future<String?> chooseSaveLocation(String name, SaveFormat format) async {
    final path = await FilePicker.saveFile(
      dialogTitle: titles.save,
      fileName: name,
      type: FileType.custom,
      allowedExtensions: format.extensions,
    );
    if (path == null) return null;
    return SaveFormat.of(path) == format ? path : '$path.${format.extension}';
  }

  Future<void> write(String path, Uint8List bytes) =>
      File(path).writeAsBytes(bytes, flush: true);
}
