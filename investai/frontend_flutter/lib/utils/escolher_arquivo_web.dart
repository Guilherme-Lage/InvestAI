import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'escolher_arquivo.dart';

Future<ArquivoEscolhido?> escolherArquivo(String extensoes) {
  final resultado = Completer<ArquivoEscolhido?>();

  // O navegador só abre o seletor de arquivos a partir de um
  // <input type="file">: criamos um invisível e "clicamos" nele.
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = extensoes
    ..style.display = 'none';
  web.document.body!.appendChild(input);

  void concluir(ArquivoEscolhido? arquivo) {
    input.remove();
    if (!resultado.isCompleted) resultado.complete(arquivo);
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      final arquivo = input.files?.item(0);
      if (arquivo == null) {
        concluir(null);
        return;
      }
      arquivo.arrayBuffer().toDart.then(
            (conteudo) => concluir(ArquivoEscolhido(arquivo.name, conteudo.toDart.asUint8List())),
            onError: (_) => concluir(null),
          );
    }.toJS,
  );
  // Disparado quando o usuário fecha o seletor sem escolher nada.
  input.addEventListener('cancel', (web.Event _) { concluir(null); }.toJS);

  input.click();
  return resultado.future;
}
