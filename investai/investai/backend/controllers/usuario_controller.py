from flask import Blueprint, request, jsonify

from services import UsuarioService

usuario_bp = Blueprint("usuario", __name__, url_prefix="/api/usuarios")


@usuario_bp.route("", methods=["GET"])
def listar():
    usuarios = UsuarioService.listar_todos()
    return jsonify([u.to_dict() for u in usuarios])


@usuario_bp.route("/<int:id>", methods=["GET"])
def buscar(id):
    usuario = UsuarioService.buscar_por_id(id)
    if not usuario:
        return jsonify({"erro": "Usuário não encontrado"}), 404
    return jsonify(usuario.to_dict())


@usuario_bp.route("", methods=["POST"])
def criar():
    dados = request.get_json() or request.form
    usuario = UsuarioService.criar(dados)
    return jsonify(usuario.to_dict()), 201


@usuario_bp.route("/<int:id>", methods=["PUT"])
def atualizar(id):
    dados = request.get_json() or request.form
    usuario = UsuarioService.atualizar(id, dados)
    if not usuario:
        return jsonify({"erro": "Usuário não encontrado"}), 404
    return jsonify(usuario.to_dict())


@usuario_bp.route("/<int:id>", methods=["DELETE"])
def deletar(id):
    ok = UsuarioService.deletar(id)
    if not ok:
        return jsonify({"erro": "Usuário não encontrado"}), 404
    return jsonify({"mensagem": "Usuário excluído"})
