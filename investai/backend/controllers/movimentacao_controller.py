from flask import Blueprint, g, request, jsonify

from services.movimentacao.criar_movimentacao_service import CriarMovimentacaoService
from services.movimentacao.listar_movimentacoes_service import ListarMovimentacoesService
from services.movimentacao.buscar_movimentacao_por_id_service import BuscarMovimentacaoPorIdService
from services.movimentacao.atualizar_movimentacao_service import AtualizarMovimentacaoService
from services.movimentacao.deletar_movimentacao_service import DeletarMovimentacaoService
from services.movimentacao.calcular_saldo_service import CalcularSaldoService
from services.movimentacao.calcular_capacidade_economia_service import CalcularCapacidadeEconomiaService
from services.movimentacao.calcular_sobrevivencia_service import CalcularSobrevivenciaService
from services.movimentacao.gerar_relatorio_mensal_service import GerarRelatorioMensalService
from services.movimentacao.calcular_gastos_por_categoria_service import CalcularGastosPorCategoriaService
from services.movimentacao.gerar_alertas_service import GerarAlertasService
from .auth_decorators import token_obrigatorio

movimentacao_bp = Blueprint(
    "movimentacao", __name__, url_prefix="/api/movimentacoes"
)


def _pertence_ao_usuario(item):
    return item is not None and item["usuario_id"] == g.usuario_id


@movimentacao_bp.route("", methods=["GET"])
@token_obrigatorio
def listar():
    """RF19 - histórico completo de transações do usuário logado, com
    filtros opcionais por tipo, categoria e período.

    Query params opcionais: tipo (renda|gasto), categoria, data_inicio,
    data_fim, ordenar (data_asc|data_desc|valor_asc|valor_desc).
    """
    itens = ListarMovimentacoesService().executar(
        g.usuario_id,
        tipo=request.args.get("tipo"),
        categoria=request.args.get("categoria"),
        data_inicio=request.args.get("data_inicio"),
        data_fim=request.args.get("data_fim"),
        ordenar=request.args.get("ordenar", "data_desc"),
    )
    return jsonify(itens)


@movimentacao_bp.route("/<int:id>", methods=["GET"])
@token_obrigatorio
def buscar(id):
    item = BuscarMovimentacaoPorIdService().executar(id)
    if not _pertence_ao_usuario(item):
        return jsonify({"erro": "Movimentação não encontrada"}), 404
    return jsonify(item)


@movimentacao_bp.route("", methods=["POST"])
@token_obrigatorio
def criar():
    """RF03/RF04 - registra uma receita (tipo=renda) ou despesa
    (tipo=gasto) com valor, data, descrição e categoria."""
    dados = dict(request.get_json() or request.form)
    dados["usuario_id"] = g.usuario_id
    item = CriarMovimentacaoService().executar(dados)
    return jsonify(item), 201


@movimentacao_bp.route("/<int:id>", methods=["PUT"])
@token_obrigatorio
def atualizar(id):
    item = BuscarMovimentacaoPorIdService().executar(id)
    if not _pertence_ao_usuario(item):
        return jsonify({"erro": "Movimentação não encontrada"}), 404
    dados = dict(request.get_json() or request.form)
    dados.pop("usuario_id", None)
    item = AtualizarMovimentacaoService().executar(id, dados)
    return jsonify(item)


@movimentacao_bp.route("/<int:id>", methods=["DELETE"])
@token_obrigatorio
def deletar(id):
    item = BuscarMovimentacaoPorIdService().executar(id)
    if not _pertence_ao_usuario(item):
        return jsonify({"erro": "Movimentação não encontrada"}), 404
    DeletarMovimentacaoService().executar(id)
    return jsonify({"mensagem": "Movimentação excluída"})


@movimentacao_bp.route("/saldo", methods=["GET"])
@token_obrigatorio
def saldo():
    """RF05 - saldo disponível do usuário, calculado em tempo real."""
    return jsonify({"saldo": CalcularSaldoService().executar(g.usuario_id)})


@movimentacao_bp.route("/capacidade-economia", methods=["GET"])
@token_obrigatorio
def capacidade_economia():
    """RF08 - capacidade de economia mensal (receitas - despesas do mês).

    Query params opcionais: ano, mes (padrão: mês atual).
    """
    ano = request.args.get("ano", type=int)
    mes = request.args.get("mes", type=int)
    capacidade = CalcularCapacidadeEconomiaService().executar(g.usuario_id, ano=ano, mes=mes)
    return jsonify({"capacidade_economia_mensal": capacidade})


@movimentacao_bp.route("/sobrevivencia", methods=["GET"])
@token_obrigatorio
def sobrevivencia():
    """RF09 - tempo de sobrevivência financeira sem renda, em meses."""
    meses = CalcularSobrevivenciaService().executar(g.usuario_id)
    return jsonify({"meses_sobrevivencia": meses})


@movimentacao_bp.route("/relatorio-mensal", methods=["GET"])
@token_obrigatorio
def relatorio_mensal():
    """RF10 - relatório financeiro mensal: total de entradas, saídas e
    saldo do período. Query params opcionais: ano, mes."""
    ano = request.args.get("ano", type=int)
    mes = request.args.get("mes", type=int)
    return jsonify(GerarRelatorioMensalService().executar(g.usuario_id, ano=ano, mes=mes))


@movimentacao_bp.route("/gastos-por-categoria", methods=["GET"])
@token_obrigatorio
def gastos_por_categoria():
    """RF11 - total de gastos agrupado por categoria, para o gráfico.

    Query params opcionais: data_inicio, data_fim.
    """
    dados = CalcularGastosPorCategoriaService().executar(
        g.usuario_id,
        data_inicio=request.args.get("data_inicio"),
        data_fim=request.args.get("data_fim"),
    )
    return jsonify(dados)


@movimentacao_bp.route("/alertas", methods=["GET"])
@token_obrigatorio
def alertas():
    """RF12 - alerta de inatividade (3+ dias sem registrar gastos) e
    RF13 - alerta de categorias que ultrapassaram o limite definido."""
    return jsonify(GerarAlertasService().executar(g.usuario_id))
