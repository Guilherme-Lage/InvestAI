from sqlalchemy import text

from models import db


class LimiteCategoriaRepository:
    """Consultas específicas de LimiteCategoria (RF13). Todo acesso a
    dados aqui é feito com SQL puro (via `text()` do SQLAlchemy), sem
    usar o ORM nem chamar métodos da Model."""

    @staticmethod
    def listar_por_usuario(usuario_id):
        sql = text("""
            SELECT id, categoria, valor_limite, usuario_id
            FROM limite_categoria
            WHERE usuario_id = :usuario_id
            ORDER BY categoria
        """)
        linhas = db.session.execute(sql, {"usuario_id": usuario_id}).mappings().all()
        return [dict(linha) for linha in linhas]

    @staticmethod
    def buscar_por_categoria(usuario_id, categoria):
        sql = text("""
            SELECT id, categoria, valor_limite, usuario_id
            FROM limite_categoria
            WHERE usuario_id = :usuario_id AND categoria = :categoria
            LIMIT 1
        """)
        linha = db.session.execute(sql, {"usuario_id": usuario_id, "categoria": categoria}).mappings().first()
        return dict(linha) if linha else None
