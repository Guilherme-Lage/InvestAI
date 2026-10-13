import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String?> salvarArquivo(Uint8List bytes, String nome, String mimeType) async {
  // O navegador só baixa um arquivo a partir de um link: criamos um
  // temporário apontando para os bytes em memória e "clicamos" nele.
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = nome;
  web.document.body!.appendChild(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
  return null;
}
