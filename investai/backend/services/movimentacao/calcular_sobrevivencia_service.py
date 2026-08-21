from repositories import MovimentacaoRepository
from services.movimentacao.calcular_saldo_service import CalcularSaldoService


class CalcularSobrevivenciaService:
    """RF09 - tempo de sobrevivência financeira sem renda: saldo
    disponível dividido pela média de despesas mensais (últimos 3
    meses). Retorna None quando não há histórico de gastos."""

    def executar(self, usuario_id):
        saldo = CalcularSaldoService().executar(usuario_id)
        media_gastos = MovimentacaoRepository.media_gastos_mensais(usuario_id, meses=3)

        if media_gastos <= 0:
            return None

        return round(max(saldo, 0.0) / media_gastos, 1)
