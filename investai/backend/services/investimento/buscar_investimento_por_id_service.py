from models import Investimento


class BuscarInvestimentoPorIdService:
    def executar(self, investimento_id):
        investimento = Investimento.buscar(investimento_id)

        if investimento is None:
            return None

        return investimento.to_dict()
