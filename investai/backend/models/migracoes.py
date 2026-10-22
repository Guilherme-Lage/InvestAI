from sqlalchemy import inspect, text

# Colunas acrescentadas depois que a tabela já existia nos bancos em uso.
# O db.create_all() só cria tabelas que faltam; coluna nova em tabela
# antiga precisa ser acrescentada à mão, senão o backend quebra ao subir
# num banco criado antes da mudança. Para acrescentar uma coluna a uma
# tabela existente, ponha-a aqui também: (tabela, coluna, tipo SQL).
COLUNAS_ACRESCENTADAS = [
    ("transacao_importada", "movimentacao_id", "INTEGER"),
]


def acrescentar_colunas_faltantes(db):
    """Acrescenta as colunas de COLUNAS_ACRESCENTADAS que ainda não existem.
    Roda toda vez que o backend sobe; quando já está tudo certo, não faz
    nada. Devolve a lista do que foi acrescentado."""
    inspetor = inspect(db.engine)
    tabelas = set(inspetor.get_table_names())
    acrescentadas = []
    for tabela, coluna, tipo in COLUNAS_ACRESCENTADAS:
        if tabela not in tabelas:
            continue
        existentes = {c["name"] for c in inspetor.get_columns(tabela)}
        if coluna in existentes:
            continue
        with db.engine.begin() as conexao:
            conexao.execute(text(f"ALTER TABLE {tabela} ADD COLUMN {coluna} {tipo}"))
        acrescentadas.append(f"{tabela}.{coluna}")
    return acrescentadas
