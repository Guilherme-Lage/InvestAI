from repositories import RecorrenciaRepository


class ListarRecorrenciasService:
    def executar(self, usuario_id):
        return RecorrenciaRepository.listar_por_usuario(usuario_id)
