from repositories import InvestimentoRepository
from services.mercado.buscar_taxas_mercado_service import BuscarTaxasMercadoService
from services.investimento.calcular_rendimento_service import (
    CalcularRendimentoInvestimentoService,
)

# Diferença anual a partir da qual vale a pena avisar. Abaixo disso o
# aviso seria ruído: não compensa trocar de aplicação por trocos.
DIFERENCA_MINIMA_REAIS = 20.0


class CompararCarteiraService:
    """Aponta, para cada investimento do usuário, quanto ele deixaria de
    ganhar por ano em relação à melhor alternativa de risco e liquidez
    equivalentes.

    A comparação usa o dinheiro que a pessoa realmente tem, e não um valor
    hipotético - é o que torna o número difícil de ignorar. Só compara
    aplicações de liquidez diária entre si, para não sugerir trocar algo
    resgatável por algo preso até o vencimento.
    """

    def executar(self, usuario_id):
        investimentos = InvestimentoRepository.listar_por_usuario(usuario_id)
        if not investimentos:
            return {"comparacoes": [], "ganho_anual_possivel": 0.0}

        taxas = BuscarTaxasMercadoService().executar()
        calculadora = CalcularRendimentoInvestimentoService()
        melhor = self._melhor_alternativa(taxas)

        comparacoes = []
        for item in investimentos:
            rendimento = calculadora.executar(item, taxas)
            taxa_atual = rendimento["taxa_anual"]

            # Sem indexador não dá para comparar taxa com taxa: o app não
            # sabe quanto aquele investimento realmente rende ao ano.
            if taxa_atual is None or taxa_atual >= melhor["taxa_anual"]:
                continue

            aplicado = float(item.get("valor_aplicado") or 0)
            diferenca = aplicado * (melhor["taxa_anual"] - taxa_atual) / 100
            if diferenca < DIFERENCA_MINIMA_REAIS:
                continue

            comparacoes.append({
                "investimento": item.get("nome"),
                "valor_aplicado": round(aplicado, 2),
                "taxa_atual": taxa_atual,
                "alternativa": melhor["nome"],
                "taxa_alternativa": melhor["taxa_anual"],
                "ganho_anual": round(diferenca, 2),
            })

        comparacoes.sort(key=lambda c: c["ganho_anual"], reverse=True)
        total = round(sum(c["ganho_anual"] for c in comparacoes), 2)

        return {
            "comparacoes": comparacoes,
            "ganho_anual_possivel": total,
            "atualizado_em": taxas["atualizado_em"],
        }

    def _melhor_alternativa(self, taxas):
        """Melhor taxa entre as opções de liquidez diária e risco baixo.

        Tesouro IPCA+ fica de fora de propósito, mesmo quando rende mais:
        ele tem vencimento e pode valer menos se resgatado antes, então
        não é substituto de uma aplicação que a pessoa saca quando quiser.
        """
        opcoes = [
            {"nome": "Tesouro Selic", "taxa_anual": taxas["selic"]},
            {"nome": "CDB 100% do CDI", "taxa_anual": taxas["cdi"]},
        ]
        return max(opcoes, key=lambda o: o["taxa_anual"])
