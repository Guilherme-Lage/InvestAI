from flask import Blueprint, request, jsonify

from services import MetaService

meta_bp = Blueprint("meta", __name__, url_prefix="/api/metas")


@meta_bp.route("", methods=["GET"])
def listar():
    itens = MetaService.listar_todos()
    return jsonify([i.to_dict() for i in itens])


@meta_bp.route("/<int:id>", methods=["GET"])
def buscar(id):
    item = MetaService.buscar_por_id(id)
    if not item:
        return jsonify({"erro": "Meta não encontrada"}), 404
    return jsonify(item.to_dict())


@meta_bp.route("", methods=["POST"])
def criar():
    dados = request.get_json() or request.form
    item = MetaService.criar(dados)
    return jsonify(item.to_dict()), 201


@meta_bp.route("/<int:id>", methods=["PUT"])
def atualizar(id):
    dados = request.get_json() or request.form
    item = MetaService.atualizar(id, dados)
    if not item:
        return jsonify({"erro": "Meta não encontrada"}), 404
    return jsonify(item.to_dict())


@meta_bp.route("/<int:id>", methods=["DELETE"])
def deletar(id):
    ok = MetaService.deletar(id)
    if not ok:
        return jsonify({"erro": "Meta não encontrada"}), 404
    return jsonify({"mensagem": "Meta excluída"})


@meta_bp.route("/status/<int:usuario_id>", methods=["GET"])
def por_status(usuario_id):
    """Lista as metas do usuário filtradas por status (concluida |
    em_andamento), ordenadas por prazo. Query param: status."""
    status = request.args.get("status", "em_andamento")
    itens = MetaService.listar_por_status(usuario_id, status=status)
    return jsonify([i.to_dict() for i in itens])
