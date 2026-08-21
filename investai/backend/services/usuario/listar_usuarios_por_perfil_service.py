from repositories import UsuarioRepository


class ListarUsuariosPorPerfilService:
    def executar(self, perfil_risco):
        usuarios = UsuarioRepository.listar_por_perfil(perfil_risco)
        return [usuario.to_dict() for usuario in usuarios]
