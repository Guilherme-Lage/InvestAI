from repositories import LimiteCategoriaRepository


class ListarLimitesCategoriaService:
    def executar(self, usuario_id):
        return LimiteCategoriaRepository.listar_por_usuario(usuario_id)
