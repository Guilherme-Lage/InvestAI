from models import Investimento


class AtualizarInvestimentoService:
    def executar(self, investimento_id, dados):
        investimento = Investimento.buscar_por_id(investimento_id)
        if investimento is None:
            return None

        valor_aplicado = dados.get("valor_aplicado")
        rendimento_atual = dados.get("rendimento_atual")
        investimento.atualizar(
            nome=dados.get("nome"),
            tipo=dados.get("tipo"),
            valor_aplicado=float(valor_aplicado) if valor_aplicado is not None else None,
            rendimento_atual=float(rendimento_atual) if rendimento_atual is not None else None,
            liquidez=dados.get("liquidez"),
        )
        return investimento.to_dict()
