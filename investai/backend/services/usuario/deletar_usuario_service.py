from models import Usuario


class DeletarUsuarioService:
    def executar(self, usuario_id):
        usuario = Usuario.buscar(usuario_id)
        if usuario is None:
            return False

        usuario.deletar()
        return True
