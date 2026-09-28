from flask import Blueprint, g, jsonify, request

from services.ia.consultar_ia_service import (
    ConsultarIaService,
    IaIndisponivelError,
    IaNaoConfiguradaError,
)
from .auth_decorators import token_obrigatorio

ia_bp = Blueprint("ia", __name__, url_prefix="/api/ia")


class IaController:
    """Controller do assistente de IA: recebe a pergunta do usuário, chama
    a Service correspondente e devolve a resposta. Nenhuma regra de
    negócio é implementada aqui."""

    @token_obrigatorio
    def perguntar(self):
        """Envia a pergunta do usuário ao agente de IA (n8n), junto com o
        retrato financeiro dele, e devolve a resposta em texto."""
        dados = request.get_json() or {}
        try:
            resultado = ConsultarIaService().executar(g.usuario_id, dados.get("pergunta"))
        except ValueError as erro:
            return jsonify({"erro": str(erro)}), 400
        except (IaNaoConfiguradaError, IaIndisponivelError) as erro:
            return jsonify({"erro": str(erro)}), 503

        if resultado is None:
            return jsonify({"erro": "Usuário não encontrado."}), 404
        return jsonify(resultado)


controller = IaController()

ia_bp.add_url_rule("/perguntar", view_func=controller.perguntar, methods=["POST"])
