from repositories import InvestimentoRepository
from services.investimento.calcular_rendimento_service import (
    CalcularRendimentoInvestimentoService,
)


class ListarInvestimentosService:
    """Lista os investimentos já com o valor atual calculado a partir das
    taxas do dia, para o usuário não precisar atualizar o rendimento na
    mão. Se as taxas não estiverem disponíveis, devolve o que está salvo."""

    def executar(self, usuario_id):
        itens = InvestimentoRepository.listar_por_usuario(usuario_id)
        if not itens:
            return itens

        calculadora = CalcularRendimentoInvestimentoService()
        try:
            taxas = None  # busca sob demanda; o cache do service evita repetição
            for item in itens:
                item.update(calculadora.executar(item, taxas))
        except Exception:
            pass  # API de taxas fora do ar: mantém os valores salvos

        return itens
