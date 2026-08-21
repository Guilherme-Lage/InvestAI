from flask import Blueprint, g, request, jsonify

from services.erros import ErroAutenticacao
from services.usuario.criar_usuario_service import CriarUsuarioService
from services.usuario.autenticar_usuario_service import AutenticarUsuarioService
from services.usuario.logout_usuario_service import LogoutUsuarioService
from services.usuario.listar_usuarios_service import ListarUsuariosService
from services.usuario.buscar_usuario_por_id_service import BuscarUsuarioPorIdService
from services.usuario.atualizar_usuario_service import AtualizarUsuarioService
from services.usuario.deletar_usuario_service import DeletarUsuarioService
from services.usuario.buscar_usuarios_com_estatisticas_service import BuscarUsuariosComEstatisticasService
from services.usuario.listar_usuarios_por_perfil_service import ListarUsuariosPorPerfilService
from services.usuario.gerar_relatorio_financeiro_usuario_service import GerarRelatorioFinanceiroUsuarioService
from .auth_decorators import token_obrigatorio

usuario_bp = Blueprint("usuario", __name__, url_prefix="/api/usuarios")


class UsuarioController:
    """Controller do recurso Usuario: recebe a requisição HTTP, chama a
    Service correspondente e devolve a resposta. Nenhuma regra de negócio
    é implementada aqui."""

    def listar(self):
        usuarios = ListarUsuariosService().executar()
        return jsonify(usuarios)

    def buscar(self, id):
        usuario = BuscarUsuarioPorIdService().executar(id)
        if usuario is None:
            return jsonify({"erro": "Usuário não encontrado"}), 404
        return jsonify(usuario)

    def criar(self):
        """RF01 - Cadastro de conta (nome, e-mail e senha).

        Devolve o usuário criado junto com um token JWT, para que o app
        já entre autenticado logo após o cadastro.
        """
        dados = request.get_json() or request.form
        try:
            resultado = CriarUsuarioService().executar(dados)
        except ValueError as erro:
            return jsonify({"erro": str(erro)}), 400
        return jsonify(resultado), 201

    def login(self):
        """RF02 - Login seguro: valida e-mail + senha (hash) e emite um
        token JWT que o app deve enviar em 'Authorization: Bearer <token>'."""
        dados = request.get_json() or request.form
        try:
            resultado = AutenticarUsuarioService().executar(
                dados.get("email"), dados.get("senha")
            )
        except ValueError as erro:
            return jsonify({"erro": str(erro)}), 400
        except ErroAutenticacao as erro:
            return jsonify({"erro": str(erro)}), 401
        return jsonify(resultado)

    @token_obrigatorio
    def logout(self):
        """RF02 - Logout seguro: revoga o token atual (jti) para que ele
        não possa mais ser reutilizado, mesmo antes de expirar."""
        LogoutUsuarioService().executar(g.usuario_id, g.token_jti)
        return jsonify({"mensagem": "Logout realizado com sucesso."})

    @token_obrigatorio
    def eu(self):
        """Retorna os dados do usuário autenticado a partir do token
        (usado pelo app para validar a sessão salva localmente)."""
        usuario = BuscarUsuarioPorIdService().executar(g.usuario_id)
        if usuario is None:
            return jsonify({"erro": "Usuário não encontrado"}), 404
        return jsonify(usuario)

    def atualizar(self, id):
        dados = request.get_json() or request.form
        usuario = AtualizarUsuarioService().executar(id, dados)
        if usuario is None:
            return jsonify({"erro": "Usuário não encontrado"}), 404
        return jsonify(usuario)

    def deletar(self, id):
        ok = DeletarUsuarioService().executar(id)
        if not ok:
            return jsonify({"erro": "Usuário não encontrado"}), 404
        return jsonify({"mensagem": "Usuário excluído"})

    def busca(self):
        """Busca usuários por nome/e-mail e retorna estatísticas agregadas
        (quantidade de movimentações, investimentos, metas e total investido),
        obtidas por JOIN entre as tabelas na camada Repository."""
        termo = request.args.get("termo")
        resultado = BuscarUsuariosComEstatisticasService().executar(termo)
        return jsonify(resultado)

    def por_perfil(self, perfil_risco):
        usuarios = ListarUsuariosPorPerfilService().executar(perfil_risco)
        return jsonify(usuarios)

    def relatorio(self, id):
        """Relatório financeiro consolidado do usuário: saldo (rendas - gastos),
        total investido, rendimento total e progresso das metas."""
        dados = GerarRelatorioFinanceiroUsuarioService().executar(id)
        if not dados:
            return jsonify({"erro": "Usuário não encontrado"}), 404
        return jsonify(dados)


controller = UsuarioController()

usuario_bp.add_url_rule("", view_func=controller.listar, methods=["GET"])
usuario_bp.add_url_rule("", view_func=controller.criar, methods=["POST"])
usuario_bp.add_url_rule("/login", view_func=controller.login, methods=["POST"])
usuario_bp.add_url_rule("/logout", view_func=controller.logout, methods=["POST"])
usuario_bp.add_url_rule("/me", view_func=controller.eu, methods=["GET"])
usuario_bp.add_url_rule("/busca", view_func=controller.busca, methods=["GET"])
usuario_bp.add_url_rule("/perfil/<perfil_risco>", view_func=controller.por_perfil, methods=["GET"])
usuario_bp.add_url_rule("/<int:id>", view_func=controller.buscar, methods=["GET"])
usuario_bp.add_url_rule("/<int:id>", view_func=controller.atualizar, methods=["PUT"])
usuario_bp.add_url_rule("/<int:id>", view_func=controller.deletar, methods=["DELETE"])
usuario_bp.add_url_rule("/<int:id>/relatorio", view_func=controller.relatorio, methods=["GET"])
