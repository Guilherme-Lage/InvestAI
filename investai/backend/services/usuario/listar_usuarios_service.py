from models import Usuario


class ListarUsuariosService:
    def executar(self):
        usuarios = Usuario.listar()
        return [usuario.to_dict() for usuario in usuarios]
