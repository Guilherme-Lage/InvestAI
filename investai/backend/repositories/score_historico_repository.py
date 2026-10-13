from sqlalchemy import text

from models import db


class ScoreHistoricoRepository:
    """Consultas específicas de ScoreHistorico. Todo acesso a dados aqui é
    feito com SQL puro (via `text()` do SQLAlchemy), sem usar o ORM nem
    chamar métodos da Model."""

    @staticmethod
    def listar_desde(usuario_id, data_inicio):
        """Retratos do score a partir de `data_inicio` ('AAAA-MM-DD'), do
        mais antigo para o mais recente - a ordem do gráfico."""
        sql = text("""
            SELECT data, score
            FROM score_historico
            WHERE usuario_id = :usuario_id AND data >= :data_inicio
            ORDER BY data ASC
        """)
        linhas = db.session.execute(sql, {
            "usuario_id": usuario_id, "data_inicio": data_inicio,
        }).mappings().all()
        return [{"data": linha["data"], "score": int(linha["score"])} for linha in linhas]

    @staticmethod
    def buscar_por_data(usuario_id, data):
        sql = text("""
            SELECT id, data, score, usuario_id
            FROM score_historico
            WHERE usuario_id = :usuario_id AND data = :data
            LIMIT 1
        """)
        linha = db.session.execute(sql, {"usuario_id": usuario_id, "data": data}).mappings().first()
        return dict(linha) if linha else None
