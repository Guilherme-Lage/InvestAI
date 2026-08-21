from models import Usuario


class AtualizarUsuarioService:
    """RF18 - também usada para atualizar o perfil de investidor
    (conservador/moderado/arrojado) e a renda mensal do usuário."""

    def executar(self, usuario_id, dados):
        usuario = Usuario.buscar(usuario_id)
        if usuario is None:
            return None

        usuario.nome = dados.get("nome", usuario.nome)
        usuario.email = dados.get("email", usuario.email)
        usuario.perfil_risco = dados.get("perfil_risco", usuario.perfil_risco)
        if dados.get("renda_mensal") is not None:
            usuario.renda_mensal = float(dados.get("renda_mensal"))

        usuario.salvar()
        return usuario.to_dict()
