from repositories import MovimentacaoRepository


class ListarMovimentacoesService:
    """RF19 - histórico completo de transações do usuário, com filtros
    opcionais por tipo, categoria e período."""

    def executar(self, usuario_id, tipo=None, categoria=None, data_inicio=None, data_fim=None, ordenar="data_desc"):
        movimentacoes = MovimentacaoRepository.extrato(
            usuario_id,
            tipo=tipo,
            categoria=categoria,
            data_inicio=data_inicio,
            data_fim=data_fim,
            ordenar=ordenar,
        )
        return [movimentacao.to_dict() for movimentacao in movimentacoes]
