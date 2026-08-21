from datetime import date, datetime, timedelta

from models import Movimentacao, db

ORDENACOES_VALIDAS = {
    "data_asc": Movimentacao.data.asc(),
    "data_desc": Movimentacao.data.desc(),
    "valor_asc": Movimentacao.valor.asc(),
    "valor_desc": Movimentacao.valor.desc(),
}


class MovimentacaoRepository:
    """Consultas específicas de Movimentacao que vão além do CRUD básico."""

    @staticmethod
    def listar_por_usuario(usuario_id):
        return Movimentacao.query.filter_by(usuario_id=usuario_id).all()

    @staticmethod
    def listar_por_tipo(tipo):
        return Movimentacao.query.filter_by(tipo=tipo).all()

    @staticmethod
    def somar_por_tipo(usuario_id, tipo, data_inicio=None, data_fim=None):
        consulta = db.session.query(db.func.coalesce(db.func.sum(Movimentacao.valor), 0.0)).filter(
            Movimentacao.usuario_id == usuario_id, Movimentacao.tipo == tipo
        )
        if data_inicio:
            consulta = consulta.filter(Movimentacao.data >= data_inicio)
        if data_fim:
            consulta = consulta.filter(Movimentacao.data <= data_fim)
        return float(consulta.scalar() or 0.0)

    @staticmethod
    def extrato(usuario_id, tipo=None, categoria=None, data_inicio=None, data_fim=None, ordenar="data_desc"):
        """Extrato de movimentações do usuário com filtros combináveis
        (WHERE por tipo, categoria e por intervalo de datas) e ordenação
        (ORDER BY). Usado no histórico completo de transações (RF19).
        """
        consulta = Movimentacao.query.filter(Movimentacao.usuario_id == usuario_id)

        if tipo:
            consulta = consulta.filter(Movimentacao.tipo == tipo)
        if categoria:
            consulta = consulta.filter(Movimentacao.categoria == categoria)
        if data_inicio:
            consulta = consulta.filter(Movimentacao.data >= data_inicio)
        if data_fim:
            consulta = consulta.filter(Movimentacao.data <= data_fim)

        criterio = ORDENACOES_VALIDAS.get(ordenar, ORDENACOES_VALIDAS["data_desc"])
        consulta = consulta.order_by(criterio)

        return consulta.all()

    @staticmethod
    def gastos_por_categoria(usuario_id, data_inicio=None, data_fim=None):
        """Soma dos gastos do usuário agrupados por categoria (GROUP BY),
        usada no gráfico de gastos por categoria (RF11) e nos alertas de
        limite (RF13)."""
        consulta = (
            db.session.query(
                Movimentacao.categoria,
                db.func.coalesce(db.func.sum(Movimentacao.valor), 0.0).label("total"),
            )
            .filter(Movimentacao.usuario_id == usuario_id, Movimentacao.tipo == "gasto")
        )
        if data_inicio:
            consulta = consulta.filter(Movimentacao.data >= data_inicio)
        if data_fim:
            consulta = consulta.filter(Movimentacao.data <= data_fim)

        consulta = consulta.group_by(Movimentacao.categoria).order_by(db.desc("total"))
        return [{"categoria": categoria, "total": float(total)} for categoria, total in consulta.all()]

    @staticmethod
    def ultima_data_movimentacao(usuario_id, tipo=None):
        """Data (string 'AAAA-MM-DD') da movimentação mais recente do
        usuário. Base do alerta de inatividade (RF12)."""
        consulta = Movimentacao.query.filter(Movimentacao.usuario_id == usuario_id)
        if tipo:
            consulta = consulta.filter(Movimentacao.tipo == tipo)
        ultima = consulta.order_by(Movimentacao.data.desc()).first()
        return ultima.data if ultima else None

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
        prefixo = f"{ano:04d}-{mes:02d}"
        consulta_base = Movimentacao.query.filter(
            Movimentacao.usuario_id == usuario_id, Movimentacao.data.like(f"{prefixo}%")
        )

        total_entradas = float(
            db.session.query(db.func.coalesce(db.func.sum(Movimentacao.valor), 0.0))
            .filter(
                Movimentacao.usuario_id == usuario_id,
                Movimentacao.tipo == "renda",
                Movimentacao.data.like(f"{prefixo}%"),
            )
            .scalar()
            or 0.0
        )
        total_saidas = float(
            db.session.query(db.func.coalesce(db.func.sum(Movimentacao.valor), 0.0))
            .filter(
                Movimentacao.usuario_id == usuario_id,
                Movimentacao.tipo == "gasto",
                Movimentacao.data.like(f"{prefixo}%"),
            )
            .scalar()
            or 0.0
        )
        itens = consulta_base.order_by(Movimentacao.data.desc()).all()

        return {
            "ano": ano,
            "mes": mes,
            "total_entradas": total_entradas,
            "total_saidas": total_saidas,
            "saldo_periodo": total_entradas - total_saidas,
            "itens": itens,
        }
