from models import Usuario


class AtualizarUsuarioService:
    """RF18 - também usada para atualizar o perfil de investidor
    (conservador/moderado/arrojado) e a renda mensal do usuário."""

    def executar(self, usuario_id, dados):
        usuario = Usuario.buscar_por_id(usuario_id)
        if usuario is None:
            return None

        renda_mensal = dados.get("renda_mensal")
        usuario.atualizar(
            nome=dados.get("nome"),
            email=dados.get("email"),
            perfil_risco=dados.get("perfil_risco"),
            renda_mensal=float(renda_mensal) if renda_mensal is not None else None,
        )
        return usuario.to_dict()
