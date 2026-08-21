from models import Movimentacao


class DeletarMovimentacaoService:
    def executar(self, movimentacao_id):
        movimentacao = Movimentacao.buscar_por_id(movimentacao_id)
        if movimentacao is None:
            return False

        movimentacao.deletar()
        return True
