from flask import Blueprint, g, request, jsonify

from services.meta.criar_meta_service import CriarMetaService
from services.meta.listar_metas_service import ListarMetasService
from services.meta.buscar_meta_por_id_service import BuscarMetaPorIdService
from services.meta.atualizar_meta_service import AtualizarMetaService
from services.meta.deletar_meta_service import DeletarMetaService
from services.meta.listar_metas_por_status_service import ListarMetasPorStatusService
from services.meta.calcular_status_reserva_emergencia_service import CalcularStatusReservaEmergenciaService
from .auth_decorators import token_obrigatorio

meta_bp = Blueprint("meta", __name__, url_prefix="/api/metas")


def _pertence_ao_usuario(item):
    return item is not None and item["usuario_id"] == g.usuario_id


@meta_bp.route("", methods=["GET"])
@token_obrigatorio
def listar():
    """RF06/RF07/RF17 - metas do usuário logado, já com o percentual de
    progresso e o aporte mensal sugerido."""
    return jsonify(ListarMetasService().executar(g.usuario_id))


@meta_bp.route("/<int:id>", methods=["GET"])
@token_obrigatorio
def buscar(id):
    item = BuscarMetaPorIdService().executar(id)
    if not _pertence_ao_usuario(item):
        return jsonify({"erro": "Meta não encontrada"}), 404
    return jsonify(item)


@meta_bp.route("", methods=["POST"])
@token_obrigatorio
def criar():
    """RF06 - cria uma meta financeira com título, valor-alvo e prazo."""
    dados = dict(request.get_json() or request.form)
    dados["usuario_id"] = g.usuario_id
    item = CriarMetaService().executar(dados)
    return jsonify(item), 201


@meta_bp.route("/<int:id>", methods=["PUT"])
@token_obrigatorio
def atualizar(id):
    item = BuscarMetaPorIdService().executar(id)
    if not _pertence_ao_usuario(item):
        return jsonify({"erro": "Meta não encontrada"}), 404
    dados = dict(request.get_json() or request.form)
    dados.pop("usuario_id", None)
    item = AtualizarMetaService().executar(id, dados)
    return jsonify(item)


@meta_bp.route("/<int:id>", methods=["DELETE"])
@token_obrigatorio
def deletar(id):
    item = BuscarMetaPorIdService().executar(id)
    if not _pertence_ao_usuario(item):
        return jsonify({"erro": "Meta não encontrada"}), 404
    DeletarMetaService().executar(id)
    return jsonify({"mensagem": "Meta excluída"})


@meta_bp.route("/status", methods=["GET"])
@token_obrigatorio
def por_status():
    """Lista as metas do usuário filtradas por status (concluida |
    em_andamento), ordenadas por prazo. Query param: status."""
    status = request.args.get("status", "em_andamento")
    itens = ListarMetasPorStatusService().executar(g.usuario_id, status=status)
    return jsonify(itens)


@meta_bp.route("/reserva-emergencia", methods=["GET"])
@token_obrigatorio
def reserva_emergencia():
    """RF14/RF15 - status da reserva de emergência: quanto já foi
    guardado, qual é o valor ideal (3x despesa média mensal) e se as
    sugestões de investimento já foram liberadas."""
    return jsonify(CalcularStatusReservaEmergenciaService().executar(g.usuario_id))
