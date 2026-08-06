from models import Meta, db


class MetaRepository:
    """Consultas específicas de Meta que vão além do CRUD básico."""

    @staticmethod
    def listar_por_usuario(usuario_id):
        return Meta.query.filter_by(usuario_id=usuario_id).order_by(Meta.prazo).all()

    @staticmethod
    def listar_concluidas(usuario_id):
        return (
            Meta.query.filter(Meta.usuario_id == usuario_id, Meta.valor_atual >= Meta.valor_alvo)
            .order_by(Meta.prazo)
            .all()
        )

    @staticmethod
    def listar_por_status(usuario_id, status="em_andamento"):
        """Lista as metas do usuário filtradas por status (concluída ou em
        andamento), comparando valor_atual com valor_alvo (WHERE), e
        ordenadas pelo prazo (ORDER BY).
        """
        consulta = Meta.query.filter(Meta.usuario_id == usuario_id)

        if status == "concluida":
            consulta = consulta.filter(Meta.valor_atual >= Meta.valor_alvo)
        elif status == "em_andamento":
            consulta = consulta.filter(Meta.valor_atual < Meta.valor_alvo)

        return consulta.order_by(Meta.prazo.asc()).all()
