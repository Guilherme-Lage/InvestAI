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


@movimentacao_bp.route("/extrato/<int:usuario_id>", methods=["GET"])
def extrato(usuario_id):
    """Extrato de movimentações do usuário com filtros por tipo e por
    intervalo de datas, e ordenação configurável.

    Query params opcionais: tipo (renda|gasto), data_inicio, data_fim,
    ordenar (data_asc|data_desc|valor_asc|valor_desc).
    """
    tipo = request.args.get("tipo")
    data_inicio = request.args.get("data_inicio")
    data_fim = request.args.get("data_fim")
    ordenar = request.args.get("ordenar", "data_desc")

    itens = MovimentacaoService.extrato(
        usuario_id, tipo=tipo, data_inicio=data_inicio, data_fim=data_fim, ordenar=ordenar
    )
    saldo = MovimentacaoService.saldo_do_usuario(usuario_id)
    return jsonify({
        "itens": [i.to_dict() for i in itens],
        "saldo": saldo,
    })
