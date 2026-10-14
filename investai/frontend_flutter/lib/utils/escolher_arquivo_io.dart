import 'escolher_arquivo.dart';

Future<ArquivoEscolhido?> escolherArquivo(String extensoes) async {
  // No desktop seria preciso um pacote com código nativo, que no Windows
  // exige o Modo Desenvolvedor ligado para compilar. Como o app é usado
  // pelo navegador, ficou só a versão web.
  throw SeletorIndisponivel();
}
