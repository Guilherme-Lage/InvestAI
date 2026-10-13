import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:investai/models/usuario.dart';
import 'package:investai/services/api_service.dart';

/// Faz toda chamada HTTP falhar como se o aparelho estivesse sem rede.
class _SemRede implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const SocketException('sem rede');
}

Future<T> _semRede<T>(Future<T> Function() corpo) {
  return HttpOverrides.runZoned(corpo, createHttpClient: (_) => _SemRede());
}

void main() {
  test('offline, o app abre com o perfil e a renda que o usuário tinha', () async {
    SharedPreferences.setMockInitialValues({});
    await ApiService.salvarSessao(
      Usuario(
        id: 3,
        nome: 'Maria Teste',
        email: 'maria@exemplo.com',
        perfilRisco: 'arrojado',
        rendaMensal: 4200.5,
        despesaMensalEstimada: 3100,
      ),
      'token-qualquer',
    );

    final usuario = await _semRede(ApiService.verificarSessao);

    expect(usuario, isNotNull);
    expect(usuario!.id, 3);
    expect(usuario.nome, 'Maria Teste');
    expect(usuario.perfilRisco, 'arrojado');
    expect(usuario.rendaMensal, 4200.5);
    expect(usuario.despesaMensalEstimada, 3100);
  });

  test('sessão antiga, sem perfil salvo, cai no perfil mais cauteloso', () async {
    // Formato gravado pelas versões anteriores do app.
    SharedPreferences.setMockInitialValues({
      'usuario_id': 3,
      'usuario_nome': 'Maria Teste',
      'usuario_email': 'maria@exemplo.com',
      'auth_token': 'token-qualquer',
    });

    final usuario = await _semRede(ApiService.verificarSessao);

    expect(usuario!.perfilRisco, 'conservador');
    expect(usuario.rendaMensal, 0);
  });

  test('sem sessão salva não há usuário, com ou sem rede', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await _semRede(ApiService.verificarSessao), isNull);
  });

  test('sair apaga também os dados financeiros guardados', () async {
    SharedPreferences.setMockInitialValues({});
    await ApiService.salvarSessao(
      Usuario(
        id: 3,
        nome: 'Maria Teste',
        email: 'maria@exemplo.com',
        perfilRisco: 'arrojado',
        rendaMensal: 4200.5,
      ),
      'token-qualquer',
    );

    await ApiService.limparSessao();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('usuario_')), isEmpty);
    expect(prefs.getString('auth_token'), isNull);
  });
}
