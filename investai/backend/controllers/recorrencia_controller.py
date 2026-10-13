from flask import Blueprint, g, request, jsonify

from services.recorrencia.listar_recorrencias_service import ListarRecorrenciasService
from services.recorrencia.criar_recorrencia_service import CriarRecorrenciaService
from services.recorrencia.atualizar_recorrencia_service import AtualizarRecorrenciaService
from services.recorrencia.deletar_recorrencia_service import DeletarRecorrenciaService
from .auth_decorators import token_obrigatorio

recorrencia_bp = Blueprint("recorrencia", __name__, url_prefix="/api/recorrencias")


class RecorrenciaController:
    """Controller do recurso Recorrencia: recebe a requisição HTTP, chama
    a Service correspondente e devolve a resposta. Nenhuma regra de
    negócio é implementada aqui."""

    @token_obrigatorio
    def listar(self):
        """Receitas e despesas recorrentes do usuário logado."""
        return jsonify(ListarRecorrenciasService().executar(g.usuario_id))

    @token_obrigatorio
    def criar(self):
        """Cadastra uma receita ou despesa que se repete todo mês."""
        dados = request.get_json() or request.form
        try:
            item = CriarRecorrenciaService().executar(g.usuario_id, dados)
        except ValueError as erro:
            return jsonify({"erro": str(erro)}), 400
        return jsonify(item), 201

    @token_obrigatorio
    def atualizar(self, id):
        """Edita, pausa (ativa=false) ou retoma (ativa=true)."""
        dados = request.get_json() or request.form
        try:
            item = AtualizarRecorrenciaService().executar(id, g.usuario_id, dados)
        except ValueError as erro:
            return jsonify({"erro": str(erro)}), 400
        if item is None:
            return jsonify({"erro": "Recorrência não encontrada"}), 404
        return jsonify(item)

    @token_obrigatorio
    def deletar(self, id):
        ok = DeletarRecorrenciaService().executar(id, g.usuario_id)
        if not ok:
            return jsonify({"erro": "Recorrência não encontrada"}), 404
        return jsonify({"mensagem": "Recorrência excluída"})


controller = RecorrenciaController()

recorrencia_bp.add_url_rule("", view_func=controller.listar, methods=["GET"])
recorrencia_bp.add_url_rule("", view_func=controller.criar, methods=["POST"])
recorrencia_bp.add_url_rule("/<int:id>", view_func=controller.atualizar, methods=["PUT"])
recorrencia_bp.add_url_rule("/<int:id>", view_func=controller.deletar, methods=["DELETE"])
