from models import Movimentacao


class BuscarMovimentacaoPorIdService:
    def executar(self, movimentacao_id):
        movimentacao = Movimentacao.buscar_por_id(movimentacao_id)

        if movimentacao is None:
            return None

        return movimentacao.to_dict()
