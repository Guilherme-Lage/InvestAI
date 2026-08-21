from repositories import MetaRepository


class ListarMetasPorStatusService:
    """Lista as metas do usuário filtradas por status (concluida |
    em_andamento), ordenadas por prazo."""

    def executar(self, usuario_id, status="em_andamento"):
        metas = MetaRepository.listar_por_status(usuario_id, status=status)
        return [meta.to_dict() for meta in metas]
