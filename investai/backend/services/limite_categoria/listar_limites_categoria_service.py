from repositories import LimiteCategoriaRepository


class ListarLimitesCategoriaService:
    def executar(self, usuario_id):
        limites = LimiteCategoriaRepository.listar_por_usuario(usuario_id)
        return [limite.to_dict() for limite in limites]
