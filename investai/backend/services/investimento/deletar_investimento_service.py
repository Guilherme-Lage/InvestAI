from models import Investimento


class DeletarInvestimentoService:
    def executar(self, investimento_id):
        investimento = Investimento.buscar_por_id(investimento_id)
        if investimento is None:
            return False

        investimento.deletar()
        return True
