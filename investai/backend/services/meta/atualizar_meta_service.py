from models import Meta


class AtualizarMetaService:
    """Também usada para registrar aportes: some ao valor_atual e chame
    com o novo total."""

    def executar(self, meta_id, dados):
        meta = Meta.buscar_por_id(meta_id)
        if meta is None:
            return None

        valor_alvo = dados.get("valor_alvo")
        valor_atual = dados.get("valor_atual")
        meta.atualizar(
            titulo=dados.get("titulo"),
            valor_alvo=float(valor_alvo) if valor_alvo is not None else None,
            valor_atual=float(valor_atual) if valor_atual is not None else None,
            prazo=dados.get("prazo"),
            tipo=dados.get("tipo"),
        )
        return meta.to_dict()
