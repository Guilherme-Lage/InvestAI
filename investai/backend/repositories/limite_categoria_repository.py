from models import LimiteCategoria


class LimiteCategoriaRepository:
    """Consultas específicas de LimiteCategoria (RF13)."""

    @staticmethod
    def listar_por_usuario(usuario_id):
        return LimiteCategoria.query.filter_by(usuario_id=usuario_id).order_by(LimiteCategoria.categoria).all()

    @staticmethod
    def buscar_por_categoria(usuario_id, categoria):
        return LimiteCategoria.query.filter_by(usuario_id=usuario_id, categoria=categoria).first()
