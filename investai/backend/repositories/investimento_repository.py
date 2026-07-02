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
