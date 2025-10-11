class File {
  File(String arg);
  void writeAsStringSync(String arg) {
    throw UnsupportedError('files not supported on this platform');
  }
}