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


@usuario_bp.route("/busca", methods=["GET"])
def busca():
    """Busca usuários por nome/e-mail e retorna estatísticas agregadas
    (quantidade de movimentações, investimentos, metas e total investido),
    obtidas por JOIN entre as tabelas na camada Repository."""
    termo = request.args.get("termo")
    resultado = UsuarioService.buscar_com_estatisticas(termo)
    return jsonify(resultado)


@usuario_bp.route("/perfil/<perfil_risco>", methods=["GET"])
def por_perfil(perfil_risco):
    usuarios = UsuarioService.listar_por_perfil(perfil_risco)
    return jsonify([u.to_dict() for u in usuarios])


@usuario_bp.route("/<int:id>/relatorio", methods=["GET"])
def relatorio(id):
    """Relatório financeiro consolidado do usuário: saldo (rendas - gastos),
    total investido, rendimento total e progresso das metas."""
    dados = UsuarioService.relatorio_financeiro(id)
    if not dados:
        return jsonify({"erro": "Usuário não encontrado"}), 404
    return jsonify(dados)
