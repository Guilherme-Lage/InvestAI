from models import Movimentacao


class AtualizarMovimentacaoService:
    def executar(self, movimentacao_id, dados):
        movimentacao = Movimentacao.buscar(movimentacao_id)
        if movimentacao is None:
            return None

        movimentacao.descricao = dados.get("descricao", movimentacao.descricao)
        movimentacao.tipo = dados.get("tipo", movimentacao.tipo)
        if dados.get("valor") is not None:
            movimentacao.valor = float(dados.get("valor"))
        movimentacao.data = dados.get("data", movimentacao.data)
        movimentacao.categoria = dados.get("categoria", movimentacao.categoria)

        movimentacao.salvar()
        return movimentacao.to_dict()
