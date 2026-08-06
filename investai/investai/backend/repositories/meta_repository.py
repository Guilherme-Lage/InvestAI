from models import Meta


class MetaRepository:
    """Consultas específicas de Meta que vão além do CRUD básico."""

    @staticmethod
    def listar_por_usuario(usuario_id):
        return Meta.query.filter_by(usuario_id=usuario_id).all()

    @staticmethod
    def listar_concluidas(usuario_id):
        metas = Meta.query.filter_by(usuario_id=usuario_id).all()
        return [m for m in metas if m.valor_atual >= m.valor_alvo]
