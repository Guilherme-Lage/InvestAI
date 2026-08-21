from models import Movimentacao


class BuscarMovimentacaoPorIdService:
    def executar(self, movimentacao_id):
        movimentacao = Movimentacao.buscar(movimentacao_id)

        if movimentacao is None:
            return None

        return movimentacao.to_dict()
