/// Mesma regra de senha do backend (`problema_na_senha`, em
/// backend/services/usuario/criar_usuario_service.py), conferida no app
/// para o aviso aparecer antes de enviar o cadastro.
///
/// Devolve o que falta na senha, ou `null` se ela estiver boa.
String? problemaNaSenha(String senha) {
  const tamanhoMinimo = 6;
  if (senha.length < tamanhoMinimo) {
    return 'A senha deve ter pelo menos $tamanhoMinimo caracteres.';
  }
  if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(senha)) {
    return 'A senha precisa ter pelo menos uma letra.';
  }
  if (!RegExp(r'\d').hasMatch(senha)) {
    return 'A senha precisa ter pelo menos um número.';
  }
  // Especial é tudo o que não é letra, número nem espaço (ex.: @ # ! _ -).
  if (!RegExp(r'[^\w\s]|_').hasMatch(senha)) {
    return 'A senha precisa ter pelo menos um caractere especial (ex.: @, #, !).';
  }
  return null;
}
