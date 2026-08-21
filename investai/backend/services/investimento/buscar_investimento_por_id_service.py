from models import Investimento


class BuscarInvestimentoPorIdService:
    def executar(self, investimento_id):
        investimento = Investimento.buscar_por_id(investimento_id)

        if investimento is None:
            return None

        return investimento.to_dict()
