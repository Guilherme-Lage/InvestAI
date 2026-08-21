from flask import Blueprint, g, jsonify

from services.usuario.gerar_guia_financeiro_service import GerarGuiaFinanceiroService
from services.usuario.calcular_score_financeiro_service import CalcularScoreFinanceiroService
from .auth_decorators import token_obrigatorio

orientacao_bp = Blueprint("orientacao", __name__, url_prefix="/api/orientacao")


@orientacao_bp.route("/guia", methods=["GET"])
@token_obrigatorio
def guia():
    """RF16 - guia financeiro passo a passo adaptado à situação do
    usuário (saldo negativo, construindo reserva, ou pronto para
    investir), aplicando as regras de RF14/RF15."""
    return jsonify(GerarGuiaFinanceiroService().executar(g.usuario_id))


@orientacao_bp.route("/score", methods=["GET"])
@token_obrigatorio
def score():
    """RF20 - score financeiro (0 a 1000) com base em saldo, reserva de
    emergência, cumprimento de metas e controle de gastos."""
    return jsonify(CalcularScoreFinanceiroService().executar(g.usuario_id))
