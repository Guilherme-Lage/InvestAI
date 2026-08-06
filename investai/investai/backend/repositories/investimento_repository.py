from models import Investimento, db


class InvestimentoRepository:
    """Consultas específicas de Investimento que vão além do CRUD básico."""

    @staticmethod
    def listar_por_usuario(usuario_id):
        return Investimento.query.filter_by(usuario_id=usuario_id).all()

    @staticmethod
    def total_aplicado(usuario_id):
        total = (
            db.session.query(db.func.sum(Investimento.valor_aplicado))
            .filter_by(usuario_id=usuario_id)
            .scalar()
        )
        return total or 0.0

    @staticmethod
    def ranking_por_rendimento(usuario_id, limite=5, tipo=None):
        """Ranking dos investimentos do usuário ordenados pelo maior
        rendimento atual (WHERE + ORDER BY + LIMIT), com filtro opcional
        por tipo de investimento.
        """
        consulta = Investimento.query.filter(Investimento.usuario_id == usuario_id)

        if tipo:
            consulta = consulta.filter(Investimento.tipo == tipo)

        consulta = consulta.order_by(Investimento.rendimento_atual.desc()).limit(limite)
        return consulta.all()
