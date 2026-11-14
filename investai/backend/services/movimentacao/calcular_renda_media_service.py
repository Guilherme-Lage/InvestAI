from models import Usuario
from repositories import MovimentacaoRepository


class CalcularRendaMediaService:
    """Renda mensal usada para calcular quanto sobra por mês no guia
    financeiro (RF16) e no contexto enviado à IA.

    Segue a mesma regra da despesa (CalcularDespesaMediaService): prioriza
    a renda real registrada nos últimos meses e só usa a renda informada no
    cadastro enquanto não houver receita registrada. Comparar a renda do
    cadastro com a despesa real dava resultados absurdos - quem atualizou o
    salário só nas movimentações aparecia gastando mais do que ganha.
    """

    def executar(self, usuario_id, meses=3):
        media_real = MovimentacaoRepository.media_rendas_mensais(usuario_id, meses=meses)
        if media_real > 0:
            return media_real

        usuario = Usuario.buscar_por_id(usuario_id)
        return (usuario.renda_mensal or 0.0) if usuario else 0.0
