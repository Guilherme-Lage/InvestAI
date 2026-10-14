from sqlalchemy import text

from models import db


class TransacaoImportadaRepository:
    """Consultas específicas de TransacaoImportada. Todo acesso a dados
    aqui é feito com SQL puro (via `text()` do SQLAlchemy), sem usar o ORM
    nem chamar métodos da Model."""

    @staticmethod
    def identificadores_do_usuario(usuario_id):
        """Conjunto dos identificadores de extrato que o usuário já
        importou - usado para não importar a mesma transação duas vezes."""
        sql = text("""
            SELECT identificador
            FROM transacao_importada
            WHERE usuario_id = :usuario_id
        """)
        linhas = db.session.execute(sql, {"usuario_id": usuario_id}).all()
        return {linha[0] for linha in linhas}
