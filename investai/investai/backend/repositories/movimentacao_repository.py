from models import Movimentacao, db


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
