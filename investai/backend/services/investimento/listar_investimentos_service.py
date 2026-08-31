from repositories import InvestimentoRepository


class ListarInvestimentosService:
    def executar(self, usuario_id):
        return InvestimentoRepository.listar_por_usuario(usuario_id)
