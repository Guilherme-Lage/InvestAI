from flask import Blueprint, request, jsonify

from services import InvestimentoService

investimento_bp = Blueprint(
    "investimento", __name__, url_prefix="/api/investimentos"
)


@investimento_bp.route("", methods=["GET"])
def listar():
    itens = InvestimentoService.listar_todos()
    return jsonify([i.to_dict() for i in itens])


@investimento_bp.route("/<int:id>", methods=["GET"])
def buscar(id):
    item = InvestimentoService.buscar_por_id(id)
    if not item:
        return jsonify({"erro": "Investimento não encontrado"}), 404
    return jsonify(item.to_dict())


@investimento_bp.route("", methods=["POST"])
def criar():
    dados = request.get_json() or request.form
    item = InvestimentoService.criar(dados)
    return jsonify(item.to_dict()), 201


@investimento_bp.route("/<int:id>", methods=["PUT"])
def atualizar(id):
    dados = request.get_json() or request.form
    item = InvestimentoService.atualizar(id, dados)
    if not item:
        return jsonify({"erro": "Investimento não encontrado"}), 404
    return jsonify(item.to_dict())


@investimento_bp.route("/<int:id>", methods=["DELETE"])
def deletar(id):
    ok = InvestimentoService.deletar(id)
    if not ok:
        return jsonify({"erro": "Investimento não encontrado"}), 404
    return jsonify({"mensagem": "Investimento excluído"})


@investimento_bp.route("/ranking/<int:usuario_id>", methods=["GET"])
def ranking(usuario_id):
    """Ranking dos investimentos do usuário com maior rendimento atual.

    Query params opcionais: limite (padrão 5), tipo (filtra por tipo de
    investimento, ex.: 'CDB').
    """
    limite = request.args.get("limite", 5, type=int)
    tipo = request.args.get("tipo")
    itens = InvestimentoService.ranking_por_rendimento(usuario_id, limite=limite, tipo=tipo)
    return jsonify([i.to_dict() for i in itens])
