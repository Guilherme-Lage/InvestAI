from repositories import UsuarioRepository


class BuscarUsuariosComEstatisticasService:
    """Busca usuários por nome/e-mail e retorna estatísticas agregadas
    (quantidade de movimentações, investimentos, metas e total investido),
    obtidas por JOIN entre as tabelas na camada Repository."""

    def executar(self, termo=None):
        return UsuarioRepository.buscar_com_estatisticas(termo)
