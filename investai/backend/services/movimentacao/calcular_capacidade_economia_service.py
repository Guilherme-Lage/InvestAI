from datetime import date

from repositories import MovimentacaoRepository


class CalcularCapacidadeEconomiaService:
    """RF08 - capacidade de economia mensal = receitas - despesas do mês
    (mês atual por padrão)."""

    def executar(self, usuario_id, ano=None, mes=None):
        hoje = date.today()
        ano = ano or hoje.year
        mes = mes or hoje.month

        resumo = MovimentacaoRepository.resumo_mensal(usuario_id, ano, mes)
        return resumo["total_entradas"] - resumo["total_saidas"]
