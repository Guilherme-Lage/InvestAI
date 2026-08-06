from models import Usuario, Movimentacao, Investimento, Meta, db


class UsuarioRepository:
    """Consultas específicas de Usuario que vão além do CRUD básico.

    As consultas aqui usam filtros (WHERE), buscas (LIKE), ordenações
    (ORDER BY), junções entre tabelas (JOIN) e agregações (SUM/COUNT),
    combinando dados de Usuario com Movimentacao, Investimento e Meta.
    """

    @staticmethod
    def buscar_por_email(email):
        return Usuario.query.filter_by(email=email).first()

    @staticmethod
    def listar_por_perfil(perfil_risco):
        return Usuario.query.filter_by(perfil_risco=perfil_risco).order_by(Usuario.nome).all()

    @staticmethod
    def buscar_com_estatisticas(termo=None):
        """Busca usuários por nome/e-mail (LIKE) e retorna, para cada um,
        estatísticas agregadas obtidas via JOIN com as demais tabelas:
        quantidade de movimentações, total investido e quantidade de metas.

        Retorna uma lista de dicionários prontos para a API/tela.
        """
        consulta = (
            db.session.query(
                Usuario,
                db.func.count(db.distinct(Movimentacao.id)).label("qtd_movimentacoes"),
                db.func.count(db.distinct(Investimento.id)).label("qtd_investimentos"),
                db.func.count(db.distinct(Meta.id)).label("qtd_metas"),
            )
            .outerjoin(Movimentacao, Movimentacao.usuario_id == Usuario.id)
            .outerjoin(Investimento, Investimento.usuario_id == Usuario.id)
            .outerjoin(Meta, Meta.usuario_id == Usuario.id)
            .group_by(Usuario.id)
            .order_by(Usuario.nome)
        )

        if termo:
            padrao = f"%{termo}%"
            consulta = consulta.filter(
                db.or_(Usuario.nome.ilike(padrao), Usuario.email.ilike(padrao))
            )

        resultados = consulta.all()

        # O JOIN combina três tabelas ao mesmo tempo, então o total investido
        # (que também é uma soma) é calculado à parte para evitar que o
        # produto cartesiano do JOIN infle o valor agregado.
        usuarios = []
        for usuario, qtd_movimentacoes, qtd_investimentos, qtd_metas in resultados:
            usuarios.append({
                **usuario.to_dict(),
                "qtd_movimentacoes": qtd_movimentacoes,
                "qtd_investimentos": qtd_investimentos,
                "qtd_metas": qtd_metas,
                "total_investido": UsuarioRepository._total_investido(usuario.id),
            })
        return usuarios

    @staticmethod
    def _total_investido(usuario_id):
        total = (
            db.session.query(db.func.coalesce(db.func.sum(Investimento.valor_aplicado), 0.0))
            .filter(Investimento.usuario_id == usuario_id)
            .scalar()
        )
        return float(total or 0.0)

    @staticmethod
    def relatorio_financeiro(usuario_id):
        """Relatório consolidado do usuário, combinando dados de
        Movimentacao (rendas/gastos), Investimento e Meta.
        """
        usuario = Usuario.buscar(usuario_id)
        if not usuario:
            return None

        total_rendas = (
            db.session.query(db.func.coalesce(db.func.sum(Movimentacao.valor), 0.0))
            .filter(Movimentacao.usuario_id == usuario_id, Movimentacao.tipo == "renda")
            .scalar()
        )
        total_gastos = (
            db.session.query(db.func.coalesce(db.func.sum(Movimentacao.valor), 0.0))
            .filter(Movimentacao.usuario_id == usuario_id, Movimentacao.tipo == "gasto")
            .scalar()
        )
        total_investido = UsuarioRepository._total_investido(usuario_id)
        total_rendimento = (
            db.session.query(db.func.coalesce(db.func.sum(Investimento.rendimento_atual), 0.0))
            .filter(Investimento.usuario_id == usuario_id)
            .scalar()
        )

        qtd_metas = db.session.query(db.func.count(Meta.id)).filter(Meta.usuario_id == usuario_id).scalar()
        qtd_metas_concluidas = (
            db.session.query(db.func.count(Meta.id))
            .filter(Meta.usuario_id == usuario_id, Meta.valor_atual >= Meta.valor_alvo)
            .scalar()
        )

        total_rendas = float(total_rendas or 0.0)
        total_gastos = float(total_gastos or 0.0)
        total_rendimento = float(total_rendimento or 0.0)

        return {
            "usuario": usuario.to_dict(),
            "total_rendas": total_rendas,
            "total_gastos": total_gastos,
            "saldo": total_rendas - total_gastos,
            "total_investido": total_investido,
            "total_rendimento": total_rendimento,
            "patrimonio_total": total_investido + total_rendimento,
            "qtd_metas": int(qtd_metas or 0),
            "qtd_metas_concluidas": int(qtd_metas_concluidas or 0),
        }
