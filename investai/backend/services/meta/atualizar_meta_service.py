from models import Meta


class AtualizarMetaService:
    """Também usada para registrar aportes: some ao valor_atual e chame
    com o novo total."""

    def executar(self, meta_id, dados):
        meta = Meta.buscar(meta_id)
        if meta is None:
            return None

        meta.titulo = dados.get("titulo", meta.titulo)
        if dados.get("valor_alvo") is not None:
            meta.valor_alvo = float(dados.get("valor_alvo"))
        if dados.get("valor_atual") is not None:
            meta.valor_atual = float(dados.get("valor_atual"))
        meta.prazo = dados.get("prazo", meta.prazo)
        meta.tipo = dados.get("tipo", meta.tipo)

        meta.salvar()
        return meta.to_dict()
