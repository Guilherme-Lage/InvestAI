from models import Investimento


class CriarInvestimentoService:
    def executar(self, dados):
        investimento = Investimento(
            nome=dados.get("nome"),
            tipo=dados.get("tipo"),
            valor_aplicado=float(dados.get("valor_aplicado") or 0),
            rendimento_atual=float(dados.get("rendimento_atual") or 0),
            liquidez=dados.get("liquidez", "diaria"),
            usuario_id=int(dados.get("usuario_id")),
        )
        investimento.salvar()
        return investimento.to_dict()
