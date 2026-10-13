import 'dart:typed_data';

import 'salvar_arquivo_io.dart'
    if (dart.library.js_interop) 'salvar_arquivo_web.dart' as plataforma;

/// Entrega ao usuário um arquivo gerado pelo app (ex.: relatório exportado).
///
/// No desktop grava na pasta Downloads e devolve o caminho completo; na
/// web quem salva é o navegador, que não informa onde - aí devolve `null`.
Future<String?> salvarArquivo(Uint8List bytes, String nome, String mimeType) {
  return plataforma.salvarArquivo(bytes, nome, mimeType);
}
