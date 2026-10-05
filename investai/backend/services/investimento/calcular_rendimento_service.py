from datetime import date

from services.mercado.buscar_taxas_mercado_service import BuscarTaxasMercadoService

DIAS_NO_ANO = 365.0

# Prêmio real embutido nos títulos IPCA+. Fica explícito aqui porque é uma
# simplificação: o prêmio real varia por título e por data de compra.
PREMIO_REAL_IPCA = 0.06

SELIC_LIMITE_POUPANCA = 8.5
POUPANCA_AO_MES = 0.5

INDEXADORES = ("selic", "cdi", "ipca", "poupanca")


class CalcularRendimentoInvestimentoService:
    """Valor atual de um investimento a partir do indexador, do percentual
    contratado e da data de aplicação.

    Antes o usuário precisava digitar o rendimento na mão e mantê-lo
    atualizado, o que na prática não acontece - o número envelhecia e o
    ranking por rendimento deixava de significar algo.

    É estimativa: aplica a taxa de hoje sobre todo o período decorrido,
    quando na verdade ela variou. Serve para acompanhar, não para
    conferir extrato.
    """

    def executar(self, investimento, taxas=None):
        aplicado = float(investimento.get("valor_aplicado") or 0)
        indexador = (investimento.get("indexador") or "").lower().strip()

        # Sem indexador o app não tem como calcular: vale o que foi digitado.
        if indexador not in INDEXADORES:
            rendimento = float(investimento.get("rendimento_atual") or 0)
            return self._resultado(aplicado, rendimento, taxa_anual=None, calculado=False)

        taxas = taxas or BuscarTaxasMercadoService().executar()
        taxa_anual = self._taxa_do_indexador(
            indexador, taxas, float(investimento.get("percentual_indexador") or 100)
        )

        dias = self._dias_aplicados(investimento.get("data_aplicacao"))
        valor_atual = aplicado * (1 + taxa_anual / 100) ** (dias / DIAS_NO_ANO)

        return self._resultado(
            aplicado, valor_atual - aplicado, taxa_anual=taxa_anual,
            calculado=True, dias=dias,
        )

    def _taxa_do_indexador(self, indexador, taxas, percentual):
        if indexador == "selic":
            return taxas["selic"] * percentual / 100
        if indexador == "cdi":
            return taxas["cdi"] * percentual / 100
        if indexador == "poupanca":
            return self._taxa_poupanca(taxas["selic"])
        # IPCA+: inflação e prêmio real se compõem, não se somam.
        return ((1 + taxas["ipca"] / 100) * (1 + PREMIO_REAL_IPCA) - 1) * 100

    def _taxa_poupanca(self, selic):
        if selic > SELIC_LIMITE_POUPANCA:
            return (((1 + POUPANCA_AO_MES / 100) ** 12) - 1) * 100
        return selic * 0.7

    def _dias_aplicados(self, data_aplicacao):
        if not data_aplicacao:
            return 0
        if isinstance(data_aplicacao, str):
            try:
                data_aplicacao = date.fromisoformat(data_aplicacao)
            except ValueError:
                return 0
        return max((date.today() - data_aplicacao).days, 0)

    def _resultado(self, aplicado, rendimento, taxa_anual, calculado, dias=None):
        valor_atual = aplicado + rendimento
        percentual = (rendimento / aplicado * 100) if aplicado > 0 else 0.0
        return {
            "valor_atual": round(valor_atual, 2),
            "rendimento": round(rendimento, 2),
            "rendimento_percentual": round(percentual, 2),
            "taxa_anual": round(taxa_anual, 2) if taxa_anual is not None else None,
            "calculado_automaticamente": calculado,
            "dias_aplicados": dias,
        }
