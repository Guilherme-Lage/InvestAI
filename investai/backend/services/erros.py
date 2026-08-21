class ErroAutenticacao(Exception):
    """Erro de autenticação (e-mail/senha incorretos). Retorna HTTP 401.

    Erros de validação de dados usam o `ValueError` nativo do Python,
    seguindo o mesmo padrão do restante das Services.
    """
