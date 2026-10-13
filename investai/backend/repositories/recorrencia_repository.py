from sqlalchemy import text

from models import db


class RecorrenciaRepository:
    """Consultas específicas de Recorrencia. Todo acesso a dados aqui é
    feito com SQL puro (via `text()` do SQLAlchemy), sem usar o ORM nem
    chamar métodos da Model."""

    @staticmethod
    def listar_por_usuario(usuario_id):
        sql = text("""
            SELECT id, descricao, tipo, valor, categoria, dia_mes,
                   data_inicio, ativa, ultimo_mes_lancado, usuario_id
            FROM recorrencia
            WHERE usuario_id = :usuario_id
            ORDER BY dia_mes, descricao
        """)
        linhas = db.session.execute(sql, {"usuario_id": usuario_id}).mappings().all()
        return [RecorrenciaRepository._para_dict(linha) for linha in linhas]

    @staticmethod
    def listar_pendentes(usuario_id, mes_atual):
        """Recorrências ativas que ainda não foram lançadas no mês
        informado ('AAAA-MM') - candidatas a gerar movimentação."""
        sql = text("""
            SELECT id, descricao, tipo, valor, categoria, dia_mes,
                   data_inicio, ativa, ultimo_mes_lancado, usuario_id
            FROM recorrencia
            WHERE usuario_id = :usuario_id
              AND ativa = 1
              AND (ultimo_mes_lancado IS NULL OR ultimo_mes_lancado < :mes_atual)
        """)
        linhas = db.session.execute(sql, {
            "usuario_id": usuario_id, "mes_atual": mes_atual,
        }).mappings().all()
        return [RecorrenciaRepository._para_dict(linha) for linha in linhas]

    @staticmethod
    def marcar_mes_lancado(recorrencia_id, mes):
        """Reserva o mês ('AAAA-MM') para lançamento e diz se conseguiu.

        A condição no WHERE faz a checagem e a marcação num único comando:
        se duas requisições chegarem juntas, só uma altera a linha e a
        outra recebe False - sem isso a mesma conta entraria em dobro.

        Não faz commit: quem chama grava a movimentação na mesma
        transação, para a marca e o lançamento valerem juntos ou nenhum.
        """
        sql = text("""
            UPDATE recorrencia
            SET ultimo_mes_lancado = :mes
            WHERE id = :id
              AND (ultimo_mes_lancado IS NULL OR ultimo_mes_lancado < :mes)
        """)
        resultado = db.session.execute(sql, {"id": recorrencia_id, "mes": mes})
        if resultado.rowcount != 1:
            # Libera a trava de escrita em vez de segurá-la até o fim da
            # requisição.
            db.session.rollback()
            return False
        return True

    @staticmethod
    def _para_dict(linha):
        item = dict(linha)
        item["ativa"] = bool(item["ativa"])
        item["valor"] = float(item["valor"])
        return item
