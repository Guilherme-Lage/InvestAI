from models import Meta


class BuscarMetaPorIdService:
    def executar(self, meta_id):
        meta = Meta.buscar_por_id(meta_id)

        if meta is None:
            return None

        return meta.to_dict()
