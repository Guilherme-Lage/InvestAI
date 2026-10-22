from datetime import date, timedelta

from models import Usuario
from repositories import MovimentacaoRepository, TransacaoImportadaRepository
from services.importacao.ler_extrato_ofx_service import LerExtratoOfxService
from services.importacao.limpar_descricao import limpar_descricao
from services.importacao.sugerir_categoria import (
    normalizar,
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
    - movimentacao_interna: aplicação, resgate, pagamento de fatura ou
      transferência entre contas do próprio usuário. Entra desmarcada.

    A categoria sugerida vem, nesta ordem, do que o próprio usuário já
    escolheu para uma transação de mesmo nome e, se não houver, das
    palavras-chave de `sugerir_categoria`.

    A decisão final é sempre do usuário; quem grava é o
    ConfirmarImportacaoService.
    """

    def executar(self, usuario_id, conteudo):
        extrato = LerExtratoOfxService().executar(conteudo)
        transacoes = extrato["transacoes"]

        ja_importadas = TransacaoImportadaRepository.identificadores_do_usuario(usuario_id)
        existentes = self._movimentacoes_do_periodo(usuario_id, transacoes)
        aprendidas = self._categorias_aprendidas(usuario_id)
        nome_do_usuario = self._nome_do_usuario(usuario_id)

        for transacao in transacoes:
            chave = self._chave(transacao["descricao"], transacao["tipo"])
            transacao["categoria"] = aprendidas.get(chave) or sugerir_categoria(
                transacao["descricao"], transacao["tipo"]
            )
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
            elif nome_do_usuario and nome_do_usuario in normalizar(transacao["descricao"]):
                transacao["situacao"] = "movimentacao_interna"
                transacao["aviso"] = (
                    "Tem o seu nome: parece transferência entre contas suas, "
                    "não um gasto ou uma renda."
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

    def _chave(self, descricao, tipo):
        """Como duas transações são reconhecidas como "de mesmo nome": pela
        descrição limpa, sem acento nem diferença de maiúscula, e pelo tipo
        (um Pix recebido de alguém não é o mesmo que um enviado a ele)."""
        return (normalizar(limpar_descricao(descricao)), tipo)

    def _categorias_aprendidas(self, usuario_id):
        """Categoria que o usuário já deu a cada nome. Nome de pessoa num
        Pix não diz se foi mercado ou lazer - só o dono da conta sabe. Por
        isso, depois que ele categoriza uma vez, a escolha é reaproveitada
        nas importações seguintes. Vale a escolha mais recente."""
        aprendidas = {}
        for movimentacao in MovimentacaoRepository.descricoes_categorizadas(usuario_id):
            chave = self._chave(movimentacao["descricao"], movimentacao["tipo"])
            aprendidas[chave] = movimentacao["categoria"]
        return aprendidas

    def _nome_do_usuario(self, usuario_id):
        """Nome completo, normalizado, para reconhecer transferências
        entre contas da própria pessoa. Com um nome só ("Maria") a chance de
        coincidir com outra pessoa é grande, então não é usado."""
        usuario = Usuario.buscar_por_id(usuario_id)
        nome = normalizar(usuario.nome).strip() if usuario else ""
        return nome if len(nome.split()) >= 2 else None

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
