from models import Movimentacao


class AtualizarMovimentacaoService:
    def executar(self, movimentacao_id, dados):
        movimentacao = Movimentacao.buscar_por_id(movimentacao_id)
        if movimentacao is None:
            return None

        valor = dados.get("valor")
        movimentacao.atualizar(
            descricao=dados.get("descricao"),
            tipo=dados.get("tipo"),
            valor=float(valor) if valor is not None else None,
            data=dados.get("data"),
            categoria=dados.get("categoria"),
        )
        return movimentacao.to_dict()
