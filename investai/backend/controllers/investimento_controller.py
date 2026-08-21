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


@investimento_bp.route("", methods=["GET"])
@token_obrigatorio
def listar():
    itens = ListarInvestimentosService().executar(g.usuario_id)
    return jsonify(itens)


@investimento_bp.route("/<int:id>", methods=["GET"])
@token_obrigatorio
def buscar(id):
    item = BuscarInvestimentoPorIdService().executar(id)
    if not _pertence_ao_usuario(item):
        return jsonify({"erro": "Investimento não encontrado"}), 404
    return jsonify(item)


@investimento_bp.route("", methods=["POST"])
@token_obrigatorio
def criar():
    dados = dict(request.get_json() or request.form)
    dados["usuario_id"] = g.usuario_id
    item = CriarInvestimentoService().executar(dados)
    return jsonify(item), 201


@investimento_bp.route("/<int:id>", methods=["PUT"])
@token_obrigatorio
def atualizar(id):
    item = BuscarInvestimentoPorIdService().executar(id)
    if not _pertence_ao_usuario(item):
        return jsonify({"erro": "Investimento não encontrado"}), 404
    dados = dict(request.get_json() or request.form)
    dados.pop("usuario_id", None)
    item = AtualizarInvestimentoService().executar(id, dados)
    return jsonify(item)


@investimento_bp.route("/<int:id>", methods=["DELETE"])
@token_obrigatorio
def deletar(id):
    item = BuscarInvestimentoPorIdService().executar(id)
    if not _pertence_ao_usuario(item):
        return jsonify({"erro": "Investimento não encontrado"}), 404
    DeletarInvestimentoService().executar(id)
    return jsonify({"mensagem": "Investimento excluído"})


@investimento_bp.route("/ranking", methods=["GET"])
@token_obrigatorio
def ranking():
    """Ranking dos investimentos do usuário logado com maior rendimento
    atual. Query params opcionais: limite (padrão 5), tipo."""
    limite = request.args.get("limite", 5, type=int)
    tipo = request.args.get("tipo")
    itens = ListarRankingInvestimentosService().executar(g.usuario_id, limite=limite, tipo=tipo)
    return jsonify(itens)
