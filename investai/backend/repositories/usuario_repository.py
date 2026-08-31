from sqlalchemy import text

from models import db


class UsuarioRepository:
    """Consultas específicas de Usuario que vão além do CRUD básico da
    Model. Todo acesso a dados aqui é feito com SQL puro (via `text()` do
    SQLAlchemy), sem usar o ORM (`.query()`/`.filter()`) nem chamar
    métodos da Model — a Repository só executa a consulta e devolve
    dicionários prontos."""

    @staticmethod
    def buscar_por_email(email):
        """Inclui o senha_hash de propósito: quem decide o que é seguro
        expor na API é a Service (AutenticarUsuarioService), não a
        Repository."""
        sql = text("""
            SELECT id, nome, email, senha_hash, perfil_risco, renda_mensal
            FROM usuario
            WHERE email = :email
        """)
        linha = db.session.execute(sql, {"email": email}).mappings().first()
        return dict(linha) if linha else None

    @staticmethod
    def listar_por_perfil(perfil_risco):
        sql = text("""
            SELECT id, nome, email, perfil_risco, renda_mensal
            FROM usuario
            WHERE perfil_risco = :perfil_risco
            ORDER BY nome
        """)
        linhas = db.session.execute(sql, {"perfil_risco": perfil_risco}).mappings().all()
        return [dict(linha) for linha in linhas]

    @staticmethod
    def buscar_com_estatisticas(termo=None):
        """Busca usuários por nome/e-mail (LIKE) e retorna, para cada um,
        estatísticas agregadas obtidas via JOIN com as demais tabelas:
        quantidade de movimentações, investimentos, metas e total investido.
        """
        sql = text("""
            SELECT
                u.id, u.nome, u.email, u.perfil_risco, u.renda_mensal,
                COUNT(DISTINCT m.id) AS qtd_movimentacoes,
                COUNT(DISTINCT i.id) AS qtd_investimentos,
                COUNT(DISTINCT me.id) AS qtd_metas,
                COALESCE((
                    SELECT SUM(i2.valor_aplicado) FROM investimento i2 WHERE i2.usuario_id = u.id
                ), 0.0) AS total_investido
            FROM usuario u
            LEFT JOIN movimentacao m ON m.usuario_id = u.id
            LEFT JOIN investimento i ON i.usuario_id = u.id
            LEFT JOIN meta me ON me.usuario_id = u.id
            WHERE (:termo IS NULL OR u.nome LIKE :padrao OR u.email LIKE :padrao)
            GROUP BY u.id
            ORDER BY u.nome
        """)
        linhas = db.session.execute(sql, {
            "termo": termo,
            "padrao": f"%{termo}%" if termo else None,
        }).mappings().all()
        return [dict(linha) for linha in linhas]

    @staticmethod
    def relatorio_financeiro(usuario_id):
        """Relatório consolidado do usuário, combinando dados de
        Movimentacao (rendas/gastos), Investimento e Meta."""
        usuario_sql = text("""
            SELECT id, nome, email, perfil_risco, renda_mensal
            FROM usuario WHERE id = :usuario_id
        """)
        usuario = db.session.execute(usuario_sql, {"usuario_id": usuario_id}).mappings().first()
        if not usuario:
            return None

        agregados_sql = text("""
            SELECT
                COALESCE((SELECT SUM(valor) FROM movimentacao WHERE usuario_id = :uid AND tipo = 'renda'), 0.0) AS total_rendas,
                COALESCE((SELECT SUM(valor) FROM movimentacao WHERE usuario_id = :uid AND tipo = 'gasto'), 0.0) AS total_gastos,
                COALESCE((SELECT SUM(valor_aplicado) FROM investimento WHERE usuario_id = :uid), 0.0) AS total_investido,
                COALESCE((SELECT SUM(rendimento_atual) FROM investimento WHERE usuario_id = :uid), 0.0) AS total_rendimento,
                (SELECT COUNT(*) FROM meta WHERE usuario_id = :uid) AS qtd_metas,
                (SELECT COUNT(*) FROM meta WHERE usuario_id = :uid AND valor_atual >= valor_alvo) AS qtd_metas_concluidas
        """)
        agregados = db.session.execute(agregados_sql, {"uid": usuario_id}).mappings().first()

        total_rendas = float(agregados["total_rendas"])
        total_gastos = float(agregados["total_gastos"])
        total_investido = float(agregados["total_investido"])
        total_rendimento = float(agregados["total_rendimento"])

        return {
            "usuario": dict(usuario),
            "total_rendas": total_rendas,
            "total_gastos": total_gastos,
            "saldo": total_rendas - total_gastos,
            "total_investido": total_investido,
            "total_rendimento": total_rendimento,
            "patrimonio_total": total_investido + total_rendimento,
            "qtd_metas": int(agregados["qtd_metas"] or 0),
            "qtd_metas_concluidas": int(agregados["qtd_metas_concluidas"] or 0),
        }
