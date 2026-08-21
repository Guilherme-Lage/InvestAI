from datetime import date

from repositories import MovimentacaoRepository


class GerarRelatorioMensalService:
    """RF10 - relatório financeiro mensal: total de entradas, saídas e
    saldo do período."""

    def executar(self, usuario_id, ano=None, mes=None):
        hoje = date.today()
        ano = ano or hoje.year
        mes = mes or hoje.month

        resumo = MovimentacaoRepository.resumo_mensal(usuario_id, ano, mes)
        return {
            "ano": resumo["ano"],
            "mes": resumo["mes"],
            "total_entradas": resumo["total_entradas"],
            "total_saidas": resumo["total_saidas"],
            "saldo_periodo": resumo["saldo_periodo"],
            "itens": [item.to_dict() for item in resumo["itens"]],
        }
