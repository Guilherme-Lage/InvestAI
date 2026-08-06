from flask import Blueprint, request, jsonify

from services import MovimentacaoService

movimentacao_bp = Blueprint(
    "movimentacao", __name__, url_prefix="/api/movimentacoes"
)


@movimentacao_bp.route("", methods=["GET"])
def listar():
    itens = MovimentacaoService.listar_todos()
    return jsonify([i.to_dict() for i in itens])


@movimentacao_bp.route("/<int:id>", methods=["GET"])
def buscar(id):
    item = MovimentacaoService.buscar_por_id(id)
    if not item:
        return jsonify({"erro": "Movimentação não encontrada"}), 404
    return jsonify(item.to_dict())


@movimentacao_bp.route("", methods=["POST"])
def criar():
    dados = request.get_json() or request.form
    item = MovimentacaoService.criar(dados)
    return jsonify(item.to_dict()), 201


@movimentacao_bp.route("/<int:id>", methods=["PUT"])
def atualizar(id):
    dados = request.get_json() or request.form
    item = MovimentacaoService.atualizar(id, dados)
    if not item:
        return jsonify({"erro": "Movimentação não encontrada"}), 404
    return jsonify(item.to_dict())


@movimentacao_bp.route("/<int:id>", methods=["DELETE"])
def deletar(id):
    ok = MovimentacaoService.deletar(id)
    if not ok:
        return jsonify({"erro": "Movimentação não encontrada"}), 404
    return jsonify({"mensagem": "Movimentação excluída"})
