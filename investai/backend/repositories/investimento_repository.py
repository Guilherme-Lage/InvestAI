from sqlalchemy import text

from models import db


class InvestimentoRepository:
    """Consultas específicas de Investimento que vão além do CRUD básico
    da Model. Todo acesso a dados aqui é feito com SQL puro (via `text()`
    do SQLAlchemy), sem usar o ORM nem chamar métodos da Model."""

    @staticmethod
    def listar_por_usuario(usuario_id):
        sql = text("""
            SELECT id, nome, tipo, valor_aplicado, rendimento_atual, liquidez, usuario_id
            FROM investimento
            WHERE usuario_id = :usuario_id
        """)
        linhas = db.session.execute(sql, {"usuario_id": usuario_id}).mappings().all()
        return [dict(linha) for linha in linhas]

    @staticmethod
    def ranking_por_rendimento(usuario_id, limite=5, tipo=None):
        """Ranking dos investimentos do usuário ordenados pelo maior
        rendimento atual (WHERE + ORDER BY + LIMIT), com filtro opcional
        por tipo de investimento.
        """
        sql = text("""
            SELECT id, nome, tipo, valor_aplicado, rendimento_atual, liquidez, usuario_id
            FROM investimento
            WHERE usuario_id = :usuario_id
              AND (:tipo IS NULL OR tipo = :tipo)
            ORDER BY rendimento_atual DESC
            LIMIT :limite
        """)
        linhas = db.session.execute(sql, {
            "usuario_id": usuario_id, "tipo": tipo, "limite": limite,
        }).mappings().all()
        return [dict(linha) for linha in linhas]
