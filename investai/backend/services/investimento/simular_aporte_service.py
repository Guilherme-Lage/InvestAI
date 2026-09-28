from services.mercado.buscar_taxas_mercado_service import BuscarTaxasMercadoService

PRAZOS_PADRAO_MESES = (12, 36, 60)
LIMITE_MESES = 600  # 50 anos - além disso a projeção não diz nada de útil

# Regra da poupança: rende 0,5% ao mês quando a Selic passa de 8,5% ao ano,
# e 70% da Selic quando fica abaixo disso. A TR entra somada, mas é ignorada
# aqui porque tem ficado perto de zero - e superestimar a poupança seria o
# erro mais grave desta comparação.
SELIC_LIMITE_POUPANCA = 8.5
POUPANCA_AO_MES = 0.5


class SimularAporteService:
    """Projeta quanto um valor inicial mais aportes mensais renderiam em
    cada aplicação, usando as taxas oficiais do dia (RF16/RF17).

    É comparação educativa, não promessa: as taxas de hoje são aplicadas
    como se fossem constantes no período, o que nenhuma aplicação garante.
    Quem informa isso ao usuário é a tela.
    """

    def executar(self, valor_inicial=0.0, aporte_mensal=0.0, prazos_meses=None):
        valor_inicial = self._validar_valor(valor_inicial, "valor inicial")
        aporte_mensal = self._validar_valor(aporte_mensal, "aporte mensal")
        if valor_inicial <= 0 and aporte_mensal <= 0:
            raise ValueError("Informe um valor inicial ou um aporte mensal.")

        prazos = self._validar_prazos(prazos_meses)
        taxas = BuscarTaxasMercadoService().executar()
        aplicacoes = self._montar_aplicacoes(taxas)

        resultados = []
        for aplicacao in aplicacoes:
            projecoes = [
                self._projetar(valor_inicial, aporte_mensal, meses, aplicacao["taxa_anual"])
                for meses in prazos
            ]
            resultados.append({**aplicacao, "projecoes": projecoes})

        # Maior patrimônio no prazo mais longo - é o que a tela destaca.
        resultados.sort(key=lambda r: r["projecoes"][-1]["valor_final"], reverse=True)

        return {
            "valor_inicial": round(valor_inicial, 2),
            "aporte_mensal": round(aporte_mensal, 2),
            "prazos_meses": list(prazos),
            "taxas_utilizadas": taxas,
            "aplicacoes": resultados,
        }

    def _montar_aplicacoes(self, taxas):
        selic = taxas["selic"]
        cdi = taxas["cdi"]
        ipca = taxas["ipca"]

        return [
            {
                "nome": "Poupança",
                "taxa_anual": round(self._taxa_poupanca(selic), 2),
                "descricao": "Rendimento definido por regra do Banco Central.",
            },
            {
                "nome": "Tesouro Selic",
                "taxa_anual": selic,
                "descricao": "Acompanha a Selic. Liquidez diária e risco baixo.",
            },
            {
                "nome": "CDB 100% do CDI",
                "taxa_anual": cdi,
                "descricao": "Acompanha o CDI, com garantia do FGC até R$ 250 mil.",
            },
            {
                "nome": "Tesouro IPCA+",
                # Prêmio real fixo somado à inflação: é assim que o título é
                # vendido (IPCA + juro real), então a projeção compõe os dois.
                "taxa_anual": round(((1 + ipca / 100) * (1 + 0.06) - 1) * 100, 2),
                "descricao": "Protege da inflação: rende IPCA mais um juro real.",
            },
        ]

    def _taxa_poupanca(self, selic):
        if selic > SELIC_LIMITE_POUPANCA:
            return (((1 + POUPANCA_AO_MES / 100) ** 12) - 1) * 100
        return selic * 0.7

    def _projetar(self, valor_inicial, aporte_mensal, meses, taxa_anual):
        taxa_mensal = (1 + taxa_anual / 100) ** (1 / 12) - 1

        if taxa_mensal == 0:
            valor_final = valor_inicial + aporte_mensal * meses
        else:
            fator = (1 + taxa_mensal) ** meses
            valor_final = valor_inicial * fator + aporte_mensal * (fator - 1) / taxa_mensal

        investido = valor_inicial + aporte_mensal * meses
        return {
            "meses": meses,
            "total_investido": round(investido, 2),
            "valor_final": round(valor_final, 2),
            "rendimento": round(valor_final - investido, 2),
        }

    def _validar_valor(self, valor, nome):
        try:
            valor = float(valor or 0)
        except (TypeError, ValueError):
            raise ValueError(f"Informe um {nome} válido.")
        if valor < 0:
            raise ValueError(f"O {nome} não pode ser negativo.")
        return valor

    def _validar_prazos(self, prazos_meses):
        if not prazos_meses:
            return PRAZOS_PADRAO_MESES

        try:
            prazos = sorted({int(p) for p in prazos_meses})
        except (TypeError, ValueError):
            raise ValueError("Prazos inválidos.")
        if not prazos or prazos[0] < 1 or prazos[-1] > LIMITE_MESES:
            raise ValueError(f"Use prazos entre 1 e {LIMITE_MESES} meses.")
        return tuple(prazos)
