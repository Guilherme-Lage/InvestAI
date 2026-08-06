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
    def somar_por_tipo(usuario_id, tipo):
        total = (
            db.session.query(db.func.sum(Movimentacao.valor))
            .filter_by(usuario_id=usuario_id, tipo=tipo)
            .scalar()
        )
        return total or 0.0

    @staticmethod
    def extrato(usuario_id, tipo=None, data_inicio=None, data_fim=None, ordenar="data_desc"):
        """Extrato de movimentações do usuário com filtros combináveis
        (WHERE por tipo e por intervalo de datas) e ordenação (ORDER BY).
        """
        consulta = Movimentacao.query.filter(Movimentacao.usuario_id == usuario_id)

        if tipo:
            consulta = consulta.filter(Movimentacao.tipo == tipo)
        if data_inicio:
            consulta = consulta.filter(Movimentacao.data >= data_inicio)
        if data_fim:
            consulta = consulta.filter(Movimentacao.data <= data_fim)

        criterio = ORDENACOES_VALIDAS.get(ordenar, ORDENACOES_VALIDAS["data_desc"])
        consulta = consulta.order_by(criterio)

        return consulta.all()
