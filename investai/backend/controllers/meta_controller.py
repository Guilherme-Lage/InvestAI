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


class MetaController:
    """Controller do recurso Meta: recebe a requisição HTTP, chama a
    Service correspondente e devolve a resposta. Nenhuma regra de negócio
    é implementada aqui."""

    @token_obrigatorio
    def listar(self):
        """RF06/RF07/RF17 - metas do usuário logado, já com o percentual de
        progresso e o aporte mensal sugerido."""
        return jsonify(ListarMetasService().executar(g.usuario_id))

    @token_obrigatorio
    def buscar(self, id):
        item = BuscarMetaPorIdService().executar(id)
        if not _pertence_ao_usuario(item):
            return jsonify({"erro": "Meta não encontrada"}), 404
        return jsonify(item)

    @token_obrigatorio
    def criar(self):
        """RF06 - cria uma meta financeira com título, valor-alvo e prazo."""
        dados = dict(request.get_json() or request.form)
        dados["usuario_id"] = g.usuario_id
        item = CriarMetaService().executar(dados)
        return jsonify(item), 201

    @token_obrigatorio
    def atualizar(self, id):
        item = BuscarMetaPorIdService().executar(id)
        if not _pertence_ao_usuario(item):
            return jsonify({"erro": "Meta não encontrada"}), 404
        dados = dict(request.get_json() or request.form)
        dados.pop("usuario_id", None)
        item = AtualizarMetaService().executar(id, dados)
        return jsonify(item)

    @token_obrigatorio
    def deletar(self, id):
        item = BuscarMetaPorIdService().executar(id)
        if not _pertence_ao_usuario(item):
            return jsonify({"erro": "Meta não encontrada"}), 404
        DeletarMetaService().executar(id)
        return jsonify({"mensagem": "Meta excluída"})

    @token_obrigatorio
    def por_status(self):
        """Lista as metas do usuário filtradas por status (concluida |
        em_andamento), ordenadas por prazo. Query param: status."""
        status = request.args.get("status", "em_andamento")
        itens = ListarMetasPorStatusService().executar(g.usuario_id, status=status)
        return jsonify(itens)

    @token_obrigatorio
    def reserva_emergencia(self):
        """RF14/RF15 - status da reserva de emergência: quanto já foi
        guardado, qual é o valor ideal (3x despesa média mensal) e se as
        sugestões de investimento já foram liberadas."""
        return jsonify(CalcularStatusReservaEmergenciaService().executar(g.usuario_id))


controller = MetaController()

meta_bp.add_url_rule("", view_func=controller.listar, methods=["GET"])
meta_bp.add_url_rule("", view_func=controller.criar, methods=["POST"])
meta_bp.add_url_rule("/status", view_func=controller.por_status, methods=["GET"])
meta_bp.add_url_rule("/reserva-emergencia", view_func=controller.reserva_emergencia, methods=["GET"])
meta_bp.add_url_rule("/<int:id>", view_func=controller.buscar, methods=["GET"])
meta_bp.add_url_rule("/<int:id>", view_func=controller.atualizar, methods=["PUT"])
meta_bp.add_url_rule("/<int:id>", view_func=controller.deletar, methods=["DELETE"])
