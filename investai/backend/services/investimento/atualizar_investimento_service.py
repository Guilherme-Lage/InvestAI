from models import Investimento


class AtualizarInvestimentoService:
    def executar(self, investimento_id, dados):
        investimento = Investimento.buscar(investimento_id)
        if investimento is None:
            return None

        investimento.nome = dados.get("nome", investimento.nome)
        investimento.tipo = dados.get("tipo", investimento.tipo)
        if dados.get("valor_aplicado") is not None:
            investimento.valor_aplicado = float(dados.get("valor_aplicado"))
        if dados.get("rendimento_atual") is not None:
            investimento.rendimento_atual = float(dados.get("rendimento_atual"))
        investimento.liquidez = dados.get("liquidez", investimento.liquidez)

        investimento.salvar()
        return investimento.to_dict()
