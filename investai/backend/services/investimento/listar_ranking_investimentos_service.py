from repositories import InvestimentoRepository


class ListarRankingInvestimentosService:
    """Ranking dos investimentos do usuário com maior rendimento atual,
    com filtro opcional por tipo de investimento."""

    def executar(self, usuario_id, limite=5, tipo=None):
        return InvestimentoRepository.ranking_por_rendimento(usuario_id, limite=limite, tipo=tipo)
