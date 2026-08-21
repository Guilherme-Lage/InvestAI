from repositories import InvestimentoRepository


class ListarInvestimentosService:
    def executar(self, usuario_id):
        investimentos = InvestimentoRepository.listar_por_usuario(usuario_id)
        return [investimento.to_dict() for investimento in investimentos]
