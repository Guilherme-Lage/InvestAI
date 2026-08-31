from sqlalchemy import text

from models import db


class TokenRevogadoRepository:
    """Consulta de TokenRevogado em SQL puro (via `text()` do SQLAlchemy),
    sem usar o ORM (`.query()`/`.filter()`) — usada pelo decorator de
    autenticação e pelo logout para checar/registrar tokens revogados
    (RF02)."""

    @staticmethod
    def buscar_por_jti(jti):
        sql = text("""
            SELECT id, jti, usuario_id
            FROM token_revogado
            WHERE jti = :jti
        """)
        linha = db.session.execute(sql, {"jti": jti}).mappings().first()
        return dict(linha) if linha else None
