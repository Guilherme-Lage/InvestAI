import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> salvarArquivo(Uint8List bytes, String nome, String mimeType) async {
  // Nem toda plataforma tem pasta Downloads; a de documentos sempre existe.
  final pasta = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final arquivo = File('${pasta.path}${Platform.pathSeparator}$nome');
  await arquivo.writeAsBytes(bytes, flush: true);
  return arquivo.path;
}
