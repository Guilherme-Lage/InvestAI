from models import LimiteCategoria


class DeletarLimiteCategoriaService:
    def executar(self, limite_id, usuario_id):
        limite = LimiteCategoria.buscar(limite_id)
        if not limite or limite.usuario_id != usuario_id:
            return False

        limite.deletar()
        return True
