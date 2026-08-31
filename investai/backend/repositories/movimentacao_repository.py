from datetime import date, timedelta

from sqlalchemy import text

from models import db

# Whitelist de ordenações aceitas: nunca interpolar o parâmetro "ordenar"
# vindo do cliente direto na SQL (risco de injection). Só os fragmentos
# fixos abaixo, escolhidos por chave, entram na consulta.
ORDENACOES_VALIDAS = {
    "data_asc": "data ASC",
    "data_desc": "data DESC",
    "valor_asc": "valor ASC",
    "valor_desc": "valor DESC",
}


class MovimentacaoRepository:
    """Consultas específicas de Movimentacao que vão além do CRUD básico
    da Model. Todo acesso a dados aqui é feito com SQL puro (via `text()`
    do SQLAlchemy), sem usar o ORM nem chamar métodos da Model."""

    @staticmethod
    def somar_por_tipo(usuario_id, tipo, data_inicio=None, data_fim=None):
        sql = text("""
            SELECT COALESCE(SUM(valor), 0.0) AS total
            FROM movimentacao
            WHERE usuario_id = :usuario_id
              AND tipo = :tipo
              AND (:data_inicio IS NULL OR data >= :data_inicio)
              AND (:data_fim IS NULL OR data <= :data_fim)
        """)
        total = db.session.execute(sql, {
            "usuario_id": usuario_id, "tipo": tipo,
            "data_inicio": data_inicio, "data_fim": data_fim,
        }).scalar()
        return float(total or 0.0)

    @staticmethod
    def extrato(usuario_id, tipo=None, categoria=None, data_inicio=None, data_fim=None, ordenar="data_desc"):
        """Extrato de movimentações do usuário com filtros combináveis
        (WHERE por tipo, categoria e por intervalo de datas) e ordenação
        (ORDER BY). Usado no histórico completo de transações (RF19).
        """
        criterio = ORDENACOES_VALIDAS.get(ordenar, ORDENACOES_VALIDAS["data_desc"])
        sql = text(f"""
            SELECT id, descricao, tipo, valor, data, categoria, usuario_id
            FROM movimentacao
            WHERE usuario_id = :usuario_id
              AND (:tipo IS NULL OR tipo = :tipo)
              AND (:categoria IS NULL OR categoria = :categoria)
              AND (:data_inicio IS NULL OR data >= :data_inicio)
              AND (:data_fim IS NULL OR data <= :data_fim)
            ORDER BY {criterio}
        """)
        linhas = db.session.execute(sql, {
            "usuario_id": usuario_id, "tipo": tipo, "categoria": categoria,
            "data_inicio": data_inicio, "data_fim": data_fim,
        }).mappings().all()
        return [dict(linha) for linha in linhas]

    @staticmethod
    def gastos_por_categoria(usuario_id, data_inicio=None, data_fim=None):
        """Soma dos gastos do usuário agrupados por categoria (GROUP BY),
        usada no gráfico de gastos por categoria (RF11) e nos alertas de
        limite (RF13)."""
        sql = text("""
            SELECT categoria, COALESCE(SUM(valor), 0.0) AS total
            FROM movimentacao
            WHERE usuario_id = :usuario_id
              AND tipo = 'gasto'
              AND (:data_inicio IS NULL OR data >= :data_inicio)
              AND (:data_fim IS NULL OR data <= :data_fim)
            GROUP BY categoria
            ORDER BY total DESC
        """)
        linhas = db.session.execute(sql, {
            "usuario_id": usuario_id, "data_inicio": data_inicio, "data_fim": data_fim,
        }).mappings().all()
        return [{"categoria": linha["categoria"], "total": float(linha["total"])} for linha in linhas]

    @staticmethod
    def ultima_data_movimentacao(usuario_id, tipo=None):
        """Data (string 'AAAA-MM-DD') da movimentação mais recente do
        usuário. Base do alerta de inatividade (RF12)."""
        sql = text("""
            SELECT data
            FROM movimentacao
            WHERE usuario_id = :usuario_id
              AND (:tipo IS NULL OR tipo = :tipo)
            ORDER BY data DESC
            LIMIT 1
        """)
        linha = db.session.execute(sql, {"usuario_id": usuario_id, "tipo": tipo}).first()
        return linha[0] if linha else None

    @staticmethod
    def media_gastos_mensais(usuario_id, meses=3):
        """Média de gastos mensais do usuário nos últimos `meses` meses
        (considerando a data de hoje como referência). Usada para calcular
        a capacidade de sobrevivência financeira (RF09) e a meta de reserva
        de emergência (RF14/RF15)."""
        hoje = date.today()
        data_inicio = (hoje - timedelta(days=30 * meses)).isoformat()
        total = MovimentacaoRepository.somar_por_tipo(
            usuario_id, "gasto", data_inicio=data_inicio, data_fim=hoje.isoformat()
        )
        return total / meses if meses else 0.0

    @staticmethod
    def resumo_mensal(usuario_id, ano, mes):
        """Total de entradas, saídas e saldo do usuário no mês/ano
        informado (RF10 - relatório financeiro mensal)."""
        prefixo = f"{ano:04d}-{mes:02d}%"

        totais_sql = text("""
            SELECT
                COALESCE(SUM(CASE WHEN tipo = 'renda' THEN valor ELSE 0 END), 0.0) AS total_entradas,
                COALESCE(SUM(CASE WHEN tipo = 'gasto' THEN valor ELSE 0 END), 0.0) AS total_saidas
            FROM movimentacao
            WHERE usuario_id = :usuario_id AND data LIKE :prefixo
        """)
        totais = db.session.execute(totais_sql, {"usuario_id": usuario_id, "prefixo": prefixo}).mappings().first()

        itens_sql = text("""
            SELECT id, descricao, tipo, valor, data, categoria, usuario_id
            FROM movimentacao
            WHERE usuario_id = :usuario_id AND data LIKE :prefixo
            ORDER BY data DESC
        """)
        itens = db.session.execute(itens_sql, {"usuario_id": usuario_id, "prefixo": prefixo}).mappings().all()

        total_entradas = float(totais["total_entradas"])
        total_saidas = float(totais["total_saidas"])

        return {
            "ano": ano,
            "mes": mes,
            "total_entradas": total_entradas,
            "total_saidas": total_saidas,
            "saldo_periodo": total_entradas - total_saidas,
            "itens": [dict(item) for item in itens],
        }
