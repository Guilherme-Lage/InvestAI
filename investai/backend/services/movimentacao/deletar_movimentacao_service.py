from models import Movimentacao


class DeletarMovimentacaoService:
    def executar(self, movimentacao_id):
        movimentacao = Movimentacao.buscar(movimentacao_id)
        if movimentacao is None:
            return False

        movimentacao.deletar()
        return True
