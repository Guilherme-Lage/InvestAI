from sqlalchemy import text

from models import db


class MetaRepository:
    """Consultas específicas de Meta que vão além do CRUD básico da
    Model. Todo acesso a dados aqui é feito com SQL puro (via `text()` do
    SQLAlchemy), sem usar o ORM nem chamar métodos da Model."""

    @staticmethod
    def _com_progresso(linha):
        dados = dict(linha)
        dados["progresso"] = (
            round((dados["valor_atual"] / dados["valor_alvo"]) * 100, 1)
            if dados["valor_alvo"] > 0 else 0
        )
        return dados

    @staticmethod
    def listar_por_usuario(usuario_id):
        sql = text("""
            SELECT id, titulo, valor_alvo, valor_atual, prazo, tipo, usuario_id
            FROM meta
            WHERE usuario_id = :usuario_id
            ORDER BY prazo
        """)
        linhas = db.session.execute(sql, {"usuario_id": usuario_id}).mappings().all()
        return [MetaRepository._com_progresso(linha) for linha in linhas]

    @staticmethod
    def listar_por_status(usuario_id, status="em_andamento"):
        """Lista as metas do usuário filtradas por status (concluída ou em
        andamento), comparando valor_atual com valor_alvo (WHERE), e
        ordenadas pelo prazo (ORDER BY).
        """
        if status == "concluida":
            condicao = "AND valor_atual >= valor_alvo"
        elif status == "em_andamento":
            condicao = "AND valor_atual < valor_alvo"
        else:
            condicao = ""

        sql = text(f"""
            SELECT id, titulo, valor_alvo, valor_atual, prazo, tipo, usuario_id
            FROM meta
            WHERE usuario_id = :usuario_id
            {condicao}
            ORDER BY prazo ASC
        """)
        linhas = db.session.execute(sql, {"usuario_id": usuario_id}).mappings().all()
        return [MetaRepository._com_progresso(linha) for linha in linhas]

    @staticmethod
    def buscar_reserva_emergencia(usuario_id):
        """Retorna a meta de reserva de emergência do usuário (RF14/RF15),
        se existir."""
        sql = text("""
            SELECT id, titulo, valor_alvo, valor_atual, prazo, tipo, usuario_id
            FROM meta
            WHERE usuario_id = :usuario_id AND tipo = 'reserva_emergencia'
            LIMIT 1
        """)
        linha = db.session.execute(sql, {"usuario_id": usuario_id}).mappings().first()
        return MetaRepository._com_progresso(linha) if linha else None
