from models import Movimentacao
from repositories import TransacaoImportadaRepository


class DeletarMovimentacaoService:
    """Apaga um lançamento. Se ele veio de um extrato importado, a linha do
    extrato volta a poder ser importada: apagar um lançamento errado não
    pode deixar aquela transação bloqueada para sempre."""

    def executar(self, movimentacao_id):
        movimentacao = Movimentacao.buscar_por_id(movimentacao_id)
        if movimentacao is None:
            return False

        TransacaoImportadaRepository.liberar_da_movimentacao(movimentacao_id)
        movimentacao.deletar()  # o commit vale para as duas exclusões
        return True
