import 'dart:typed_data';

import 'escolher_arquivo_io.dart'
    if (dart.library.js_interop) 'escolher_arquivo_web.dart' as plataforma;

/// Arquivo que o usuário escolheu no aparelho, já lido para a memória.
class ArquivoEscolhido {
  final String nome;
  final Uint8List bytes;
  const ArquivoEscolhido(this.nome, this.bytes);
}

/// Lançado quando a plataforma não tem seletor de arquivo implementado.
class SeletorIndisponivel implements Exception {}

/// Abre o seletor de arquivos do aparelho. `extensoes` segue o formato do
/// navegador, por exemplo `.ofx`. Devolve `null` se o usuário cancelar.
///
/// Só existe na versão web (navegador do PC ou do celular); nas outras
/// plataformas lança [SeletorIndisponivel].
Future<ArquivoEscolhido?> escolherArquivo(String extensoes) {
  return plataforma.escolherArquivo(extensoes);
}
