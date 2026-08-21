from models import Investimento


class DeletarInvestimentoService:
    def executar(self, investimento_id):
        investimento = Investimento.buscar(investimento_id)
        if investimento is None:
            return False

        investimento.deletar()
        return True
