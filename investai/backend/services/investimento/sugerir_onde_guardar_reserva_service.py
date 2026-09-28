from services.mercado.buscar_taxas_mercado_service import BuscarTaxasMercadoService

# Reserva de emergência tem uma exigência que investimento comum não tem:
# precisa estar disponível no dia em que o problema acontece. Por isso só
# entram aqui aplicações de liquidez diária e risco baixo - nada com
# carência, vencimento ou oscilação de preço.
LIQUIDEZ_EXIGIDA = "diaria"


class SugerirOndeGuardarReservaService:
    """Onde deixar a reserva de emergência enquanto ela é construída.

    Não conflita com RF14/RF15: aquela regra impede investir *para
    crescer* antes da reserva formada. A reserva em si precisa ficar em
    algum lugar, e deixá-la parada na conta perde para a inflação todo
    mês - o que também é prejuízo, só que silencioso.
    """

    def executar(self, valor_guardado=0.0):
        try:
            valor_guardado = max(float(valor_guardado or 0), 0.0)
        except (TypeError, ValueError):
            valor_guardado = 0.0

        taxas = BuscarTaxasMercadoService().executar()
        opcoes = self._montar_opcoes(taxas)

        for opcao in opcoes:
            opcao["rendimento_ano"] = round(
                valor_guardado * opcao["taxa_anual"] / 100, 2
            )

        # Quanto a inflação come do dinheiro parado em um ano: é o custo
        # de não fazer nada, que costuma passar despercebido.
        perda_parado = round(valor_guardado * taxas["ipca"] / 100, 2)

        return {
            "valor_considerado": round(valor_guardado, 2),
            "opcoes": opcoes,
            "ipca": taxas["ipca"],
            "perda_anual_se_parado": perda_parado,
            "atualizado_em": taxas["atualizado_em"],
        }

    def _montar_opcoes(self, taxas):
        return [
            {
                "nome": "Tesouro Selic",
                "taxa_anual": taxas["selic"],
                "liquidez": LIQUIDEZ_EXIGIDA,
                "protecao": "Garantido pelo Tesouro Nacional",
                "descricao": "Resgate em qualquer dia útil, sem perder o que "
                             "já rendeu. É o mais usado para reserva.",
            },
            {
                "nome": "CDB de liquidez diária",
                "taxa_anual": taxas["cdi"],
                "liquidez": LIQUIDEZ_EXIGIDA,
                "protecao": "FGC até R$ 250 mil por banco",
                "descricao": "Procure os que pagam perto de 100% do CDI e "
                             "permitem resgatar quando quiser, sem carência.",
            },
            {
                "nome": "Fundo DI simples",
                # Taxa de administração costuma comer parte do CDI; usar o CDI
                # cheio aqui prometeria mais do que a pessoa receberia.
                "taxa_anual": round(taxas["cdi"] * 0.9, 2),
                "liquidez": LIQUIDEZ_EXIGIDA,
                "protecao": "Baixo risco, mas sem FGC",
                "descricao": "Prático, porém a taxa de administração reduz o "
                             "rendimento - compare antes de escolher.",
            },
        ]
