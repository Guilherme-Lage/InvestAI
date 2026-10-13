from flask import Blueprint, g, jsonify, request

from services.usuario.gerar_guia_financeiro_service import GerarGuiaFinanceiroService
from services.usuario.calcular_score_financeiro_service import CalcularScoreFinanceiroService
from services.usuario.listar_historico_score_service import ListarHistoricoScoreService
from .auth_decorators import token_obrigatorio

orientacao_bp = Blueprint("orientacao", __name__, url_prefix="/api/orientacao")


class OrientacaoController:
    """Controller de orientação financeira do usuário: recebe a requisição
    HTTP, chama a Service correspondente e devolve a resposta. Nenhuma
    regra de negócio é implementada aqui."""

    @token_obrigatorio
    def guia(self):
        """RF16 - guia financeiro passo a passo adaptado à situação do
        usuário (saldo negativo, construindo reserva, ou pronto para
        investir), aplicando as regras de RF14/RF15."""
        return jsonify(GerarGuiaFinanceiroService().executar(g.usuario_id))

    @token_obrigatorio
    def score(self):
        """RF20 - score financeiro (0 a 1000) com base em saldo, reserva de
        emergência, cumprimento de metas e controle de gastos."""
        return jsonify(CalcularScoreFinanceiroService().executar(g.usuario_id))

    @token_obrigatorio
    def historico_score(self):
        """Evolução do score financeiro (RF20) nos últimos dias.

        Query param opcional: dias (padrão 90, máximo 365).
        """
        dias = request.args.get("dias", type=int)
        return jsonify(ListarHistoricoScoreService().executar(g.usuario_id, dias=dias))


controller = OrientacaoController()

orientacao_bp.add_url_rule("/guia", view_func=controller.guia, methods=["GET"])
orientacao_bp.add_url_rule("/score", view_func=controller.score, methods=["GET"])
orientacao_bp.add_url_rule("/score/historico", view_func=controller.historico_score, methods=["GET"])
