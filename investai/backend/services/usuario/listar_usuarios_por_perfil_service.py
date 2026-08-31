from repositories import UsuarioRepository


class ListarUsuariosPorPerfilService:
    def executar(self, perfil_risco):
        return UsuarioRepository.listar_por_perfil(perfil_risco)
