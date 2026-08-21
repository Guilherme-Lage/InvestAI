from repositories import MovimentacaoRepository


class CalcularGastosPorCategoriaService:
    """RF11 - gastos agrupados por categoria, para exibir em gráfico."""

    def executar(self, usuario_id, data_inicio=None, data_fim=None):
        return MovimentacaoRepository.gastos_por_categoria(
            usuario_id, data_inicio=data_inicio, data_fim=data_fim
        )
