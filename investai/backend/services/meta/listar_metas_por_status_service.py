from repositories import MetaRepository


class ListarMetasPorStatusService:
    """Lista as metas do usuário filtradas por status (concluida |
    em_andamento), ordenadas por prazo."""

    def executar(self, usuario_id, status="em_andamento"):
        return MetaRepository.listar_por_status(usuario_id, status=status)
