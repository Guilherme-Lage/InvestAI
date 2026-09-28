from services.movimentacao.calcular_saldo_service import CalcularSaldoService
from services.movimentacao.calcular_despesa_media_service import (
    CalcularDespesaMediaService,
)


class CalcularSobrevivenciaService:
    """RF09 - tempo de sobrevivência financeira sem renda: saldo
    disponível dividido pela média de despesas mensais (últimos 3
    meses, ou a estimativa do cadastro enquanto não há histórico).
    Retorna None quando não há nenhuma das duas."""

    def executar(self, usuario_id):
        saldo = CalcularSaldoService().executar(usuario_id)
        media_gastos = CalcularDespesaMediaService().executar(usuario_id)

        if media_gastos <= 0:
            return None

        return round(max(saldo, 0.0) / media_gastos, 1)
