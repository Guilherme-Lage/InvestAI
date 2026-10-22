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

    @staticmethod
    def liberar_da_movimentacao(movimentacao_id):
        """Apaga a marca de "já importada" ligada a um lançamento, para a
        linha do extrato poder ser importada de novo. Não faz commit: quem
        chama apaga o lançamento na mesma transação."""
        sql = text("""
            DELETE FROM transacao_importada
            WHERE movimentacao_id = :movimentacao_id
        """)
        db.session.execute(sql, {"movimentacao_id": movimentacao_id})
