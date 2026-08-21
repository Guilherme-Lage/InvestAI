from flask import Blueprint, g, request, jsonify

from services.limite_categoria.listar_limites_categoria_service import ListarLimitesCategoriaService
from services.limite_categoria.definir_limite_categoria_service import DefinirLimiteCategoriaService
from services.limite_categoria.deletar_limite_categoria_service import DeletarLimiteCategoriaService
from .auth_decorators import token_obrigatorio

limite_bp = Blueprint("limite_categoria", __name__, url_prefix="/api/limites")


@limite_bp.route("", methods=["GET"])
@token_obrigatorio
def listar():
    """RF13 - lista os limites de gasto mensal por categoria do usuário."""
    itens = ListarLimitesCategoriaService().executar(g.usuario_id)
    return jsonify(itens)


@limite_bp.route("", methods=["POST"])
@token_obrigatorio
def definir():
    """RF13 - define (cria ou atualiza) o limite de uma categoria."""
    dados = request.get_json() or request.form
    try:
        item = DefinirLimiteCategoriaService().executar(g.usuario_id, dados)
    except ValueError as erro:
        return jsonify({"erro": str(erro)}), 400
    return jsonify(item), 201


@limite_bp.route("/<int:id>", methods=["DELETE"])
@token_obrigatorio
def deletar(id):
    ok = DeletarLimiteCategoriaService().executar(id, g.usuario_id)
    if not ok:
        return jsonify({"erro": "Limite não encontrado"}), 404
    return jsonify({"mensagem": "Limite excluído"})
