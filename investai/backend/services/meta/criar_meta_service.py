from models import Meta


class CriarMetaService:
    """RF06 - cria uma meta financeira com título, valor-alvo e prazo."""

    def executar(self, dados):
        meta = Meta(
            titulo=dados.get("titulo"),
            valor_alvo=float(dados.get("valor_alvo") or 0),
            valor_atual=float(dados.get("valor_atual") or 0),
            prazo=dados.get("prazo"),
            tipo=dados.get("tipo") or "geral",
            usuario_id=int(dados.get("usuario_id")),
        )
        meta.salvar()
        return meta.to_dict()
