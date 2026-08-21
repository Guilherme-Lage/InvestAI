from flask import Blueprint, g, jsonify

from services.usuario.gerar_guia_financeiro_service import GerarGuiaFinanceiroService
from services.usuario.calcular_score_financeiro_service import CalcularScoreFinanceiroService
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


controller = OrientacaoController()

orientacao_bp.add_url_rule("/guia", view_func=controller.guia, methods=["GET"])
orientacao_bp.add_url_rule("/score", view_func=controller.score, methods=["GET"])
