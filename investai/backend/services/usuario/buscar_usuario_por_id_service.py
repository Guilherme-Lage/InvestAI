from models import Usuario


class BuscarUsuarioPorIdService:
    """Também usada para o RF02 (GET /api/usuarios/me), que busca os
    dados do usuário autenticado a partir do id extraído do token."""

    def executar(self, usuario_id):
        usuario = Usuario.buscar_por_id(usuario_id)

        if usuario is None:
            return None

        return usuario.to_dict()
