from datetime import date, timedelta

from repositories import MovimentacaoRepository, TransacaoImportadaRepository
from services.importacao.ler_extrato_ofx_service import LerExtratoOfxService
from services.importacao.sugerir_categoria import (
    parece_movimentacao_interna,
    sugerir_categoria,
)

# Uma compra no cartão pode aparecer no extrato um ou dois dias depois de
# o usuário tê-la registrado à mão; a recorrência é lançada no dia marcado
# e o débito real pode cair no dia útil seguinte.
DIAS_DE_TOLERANCIA = 3


class AnalisarExtratoService:
    """Primeiro passo da importação: lê o extrato e prepara a revisão.

    Nada é gravado aqui. Cada transação volta com uma `situacao`, que a
    tela usa para decidir o que já vem marcado para importar:

    - nova: entra marcada;
    - ja_importada: veio em uma importação anterior, não entra de novo;
    - possivel_duplicata: há uma movimentação de mesmo valor em data
      próxima (lançada por recorrência ou digitada). Entra desmarcada;
    - movimentacao_interna: aplicação, resgate ou pagamento de fatura.
      Entra desmarcada.

    A decisão final é sempre do usuário; quem grava é o
    ConfirmarImportacaoService.
    """

    def executar(self, usuario_id, conteudo):
        extrato = LerExtratoOfxService().executar(conteudo)
        transacoes = extrato["transacoes"]

        ja_importadas = TransacaoImportadaRepository.identificadores_do_usuario(usuario_id)
        existentes = self._movimentacoes_do_periodo(usuario_id, transacoes)

        for transacao in transacoes:
            transacao["categoria"] = sugerir_categoria(transacao["descricao"], transacao["tipo"])
            transacao["aviso"] = None

            if transacao["identificador"] in ja_importadas:
                transacao["situacao"] = "ja_importada"
                continue

            parecida = self._retirar_parecida(transacao, existentes)
            if parecida:
                transacao["situacao"] = "possivel_duplicata"
                transacao["aviso"] = (
                    f"Parece ser \"{parecida['descricao']}\", que já está no seu "
                    f"histórico em {self._data_br(parecida['data'])}."
                )
            elif parece_movimentacao_interna(transacao["descricao"]):
                transacao["situacao"] = "movimentacao_interna"
                transacao["aviso"] = (
                    "Parece dinheiro mudando de lugar (aplicação, resgate ou "
                    "fatura), não um gasto ou uma renda."
                )
            else:
                transacao["situacao"] = "nova"

        return {
            "banco": extrato["banco"],
            "conta": extrato["conta"],
            "data_inicio": transacoes[0]["data"],
            "data_fim": transacoes[-1]["data"],
            "transacoes": transacoes,
        }

    def _movimentacoes_do_periodo(self, usuario_id, transacoes):
        """O que o usuário já tem registrado em torno das datas do extrato
        - é contra isso que se procuram duplicatas."""
        inicio = date.fromisoformat(transacoes[0]["data"]) - timedelta(days=DIAS_DE_TOLERANCIA)
        fim = date.fromisoformat(transacoes[-1]["data"]) + timedelta(days=DIAS_DE_TOLERANCIA)
        return MovimentacaoRepository.extrato(
            usuario_id, data_inicio=inicio.isoformat(), data_fim=fim.isoformat()
        )

    def _retirar_parecida(self, transacao, existentes):
        """Procura uma movimentação de mesmo tipo e valor em data próxima.

        A que for encontrada sai da lista: se o extrato traz duas compras
        iguais e o usuário só tinha registrado uma, só a primeira é
        tratada como repetida.
        """
        data = date.fromisoformat(transacao["data"])
        for movimentacao in existentes:
            try:
                distancia = abs((date.fromisoformat(str(movimentacao["data"])) - data).days)
            except ValueError:
                continue
            if (
                movimentacao["tipo"] == transacao["tipo"]
                and abs(movimentacao["valor"] - transacao["valor"]) < 0.005
                and distancia <= DIAS_DE_TOLERANCIA
            ):
                existentes.remove(movimentacao)
                return movimentacao
        return None

    def _data_br(self, data):
        try:
            return date.fromisoformat(str(data)).strftime("%d/%m")
        except ValueError:
            return str(data)
