from flask import Blueprint, g, request, jsonify

from services.investimento.criar_investimento_service import CriarInvestimentoService
from services.investimento.listar_investimentos_service import ListarInvestimentosService
from services.investimento.buscar_investimento_por_id_service import BuscarInvestimentoPorIdService
from services.investimento.atualizar_investimento_service import AtualizarInvestimentoService
from services.investimento.deletar_investimento_service import DeletarInvestimentoService
from services.investimento.listar_ranking_investimentos_service import ListarRankingInvestimentosService
from .auth_decorators import token_obrigatorio

investimento_bp = Blueprint(
    "investimento", __name__, url_prefix="/api/investimentos"
)


def _pertence_ao_usuario(item):
    return item is not None and item["usuario_id"] == g.usuario_id


class InvestimentoController:
    """Controller do recurso Investimento: recebe a requisição HTTP, chama
    a Service correspondente e devolve a resposta. Nenhuma regra de
    negócio é implementada aqui."""

    @token_obrigatorio
    def listar(self):
        itens = ListarInvestimentosService().executar(g.usuario_id)
        return jsonify(itens)

    @token_obrigatorio
    def buscar(self, id):
        item = BuscarInvestimentoPorIdService().executar(id)
        if not _pertence_ao_usuario(item):
            return jsonify({"erro": "Investimento não encontrado"}), 404
        return jsonify(item)

    @token_obrigatorio
    def criar(self):
        dados = dict(request.get_json() or request.form)
        dados["usuario_id"] = g.usuario_id
        item = CriarInvestimentoService().executar(dados)
        return jsonify(item), 201

    @token_obrigatorio
    def atualizar(self, id):
        item = BuscarInvestimentoPorIdService().executar(id)
        if not _pertence_ao_usuario(item):
            return jsonify({"erro": "Investimento não encontrado"}), 404
        dados = dict(request.get_json() or request.form)
        dados.pop("usuario_id", None)
        item = AtualizarInvestimentoService().executar(id, dados)
        return jsonify(item)

    @token_obrigatorio
    def deletar(self, id):
        item = BuscarInvestimentoPorIdService().executar(id)
        if not _pertence_ao_usuario(item):
            return jsonify({"erro": "Investimento não encontrado"}), 404
        DeletarInvestimentoService().executar(id)
        return jsonify({"mensagem": "Investimento excluído"})

    @token_obrigatorio
    def ranking(self):
        """Ranking dos investimentos do usuário logado com maior rendimento
        atual. Query params opcionais: limite (padrão 5), tipo."""
        limite = request.args.get("limite", 5, type=int)
        tipo = request.args.get("tipo")
        itens = ListarRankingInvestimentosService().executar(g.usuario_id, limite=limite, tipo=tipo)
        return jsonify(itens)


controller = InvestimentoController()

investimento_bp.add_url_rule("", view_func=controller.listar, methods=["GET"])
investimento_bp.add_url_rule("", view_func=controller.criar, methods=["POST"])
investimento_bp.add_url_rule("/ranking", view_func=controller.ranking, methods=["GET"])
investimento_bp.add_url_rule("/<int:id>", view_func=controller.buscar, methods=["GET"])
investimento_bp.add_url_rule("/<int:id>", view_func=controller.atualizar, methods=["PUT"])
investimento_bp.add_url_rule("/<int:id>", view_func=controller.deletar, methods=["DELETE"])
