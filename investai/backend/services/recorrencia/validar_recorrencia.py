from datetime import date

TIPOS_VALIDOS = ("renda", "gasto")
DATA_MINIMA = date(2000, 1, 1)


def validar_campos(dados, parcial=False):
    """Confere e normaliza os campos de uma recorrência, devolvendo só os
    que podem ir para a Model. Levanta ValueError com a mensagem pronta
    para o usuário.

    Com `parcial=True` (edição) valida apenas o que foi enviado; sem isso
    (criação) os campos obrigatórios precisam estar presentes.
    """
    campos = {}

    if not parcial or "descricao" in dados:
        descricao = (dados.get("descricao") or "").strip()
        if not descricao:
            raise ValueError("Informe uma descrição.")
        campos["descricao"] = descricao

    if not parcial or "tipo" in dados:
        tipo = dados.get("tipo") or "gasto"
        if tipo not in TIPOS_VALIDOS:
            raise ValueError("O tipo deve ser 'renda' ou 'gasto'.")
        campos["tipo"] = tipo

    if not parcial or "valor" in dados:
        try:
            valor = float(dados.get("valor"))
        except (TypeError, ValueError):
            raise ValueError("Informe um valor válido.")
        if valor <= 0:
            raise ValueError("O valor deve ser maior que zero.")
        campos["valor"] = valor

    if not parcial or "categoria" in dados:
        campos["categoria"] = (dados.get("categoria") or "outros").strip().lower()

    # A data de início só é definida na criação: depois disso ela é
    # controlada pelo sistema (ver AtualizarRecorrenciaService).
    inicio = None
    if not parcial:
        try:
            inicio = date.fromisoformat(dados.get("data_inicio") or date.today().isoformat())
        except (TypeError, ValueError):
            raise ValueError("Informe a data de início no formato AAAA-MM-DD.")
        if inicio < DATA_MINIMA:
            raise ValueError("A data de início é antiga demais.")
        campos["data_inicio"] = inicio.isoformat()

    if not parcial or "dia_mes" in dados:
        # Na criação, sem dia informado, vale o dia da data de início.
        try:
            dia_mes = int(dados.get("dia_mes") or (inicio.day if inicio else None))
        except (TypeError, ValueError):
            raise ValueError("Informe o dia do mês.")
        if not 1 <= dia_mes <= 31:
            raise ValueError("O dia do mês deve ficar entre 1 e 31.")
        campos["dia_mes"] = dia_mes

    return campos
