from datetime import date

from repositories import MovimentacaoRepository


class GerarRelatorioMensalService:
    """RF10 - relatório financeiro mensal: total de entradas, saídas e
    saldo do período."""

    def executar(self, usuario_id, ano=None, mes=None):
        hoje = date.today()
        ano = ano or hoje.year
        mes = mes or hoje.month

        return MovimentacaoRepository.resumo_mensal(usuario_id, ano, mes)
