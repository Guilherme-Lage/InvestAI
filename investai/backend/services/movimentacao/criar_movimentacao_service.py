from models import Movimentacao


class CriarMovimentacaoService:
    """RF03/RF04 - registra uma receita (tipo=renda) ou despesa
    (tipo=gasto) com valor, data, descrição e categoria."""

    def executar(self, dados):
        movimentacao = Movimentacao(
            descricao=dados.get("descricao"),
            tipo=dados.get("tipo"),
            valor=float(dados.get("valor") or 0),
            data=dados.get("data"),
            categoria=dados.get("categoria") or "outros",
            usuario_id=int(dados.get("usuario_id")),
        )
        movimentacao.salvar()
        return movimentacao.to_dict()
