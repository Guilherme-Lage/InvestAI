from models import Meta


class DeletarMetaService:
    def executar(self, meta_id):
        meta = Meta.buscar_por_id(meta_id)
        if meta is None:
            return False

        meta.deletar()
        return True
