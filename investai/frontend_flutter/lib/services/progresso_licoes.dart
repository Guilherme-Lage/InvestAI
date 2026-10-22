import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Quais lições da trilha "Aprenda a investir" o usuário já concluiu.
///
/// Fica guardado no próprio aparelho, separado por conta: é só uma marca de
/// leitura, sem valor para o backend, e assim a trilha funciona sem mudar o
/// banco de dados.
class ProgressoLicoes {
  static Future<String> _chave() async {
    final sessao = await ApiService.carregarSessao();
    return 'licoes_concluidas_${sessao?['id'] ?? 'sem_conta'}';
  }

  static Future<Set<String>> concluidas() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(await _chave()) ?? const []).toSet();
  }

  static Future<void> concluir(String idLicao) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = await _chave();
    final atuais = (prefs.getStringList(chave) ?? const []).toSet()..add(idLicao);
    await prefs.setStringList(chave, atuais.toList());
  }
}
