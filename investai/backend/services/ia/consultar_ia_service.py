import os

import requests

from models import Usuario
from services.meta.calcular_status_reserva_emergencia_service import (
    CalcularStatusReservaEmergenciaService,
)
from services.movimentacao.calcular_capacidade_economia_service import (
    CalcularCapacidadeEconomiaService,
)
from services.movimentacao.calcular_gastos_por_categoria_service import (
    CalcularGastosPorCategoriaService,
)
from services.movimentacao.calcular_saldo_service import CalcularSaldoService
from services.usuario.calcular_score_financeiro_service import (
    CalcularScoreFinanceiroService,
)

SEGUNDOS_TIMEOUT = 45


class IaNaoConfiguradaError(Exception):
    """O webhook da IA (n8n) ainda não foi informado nas variáveis de
    ambiente. Retorna HTTP 503."""


class IaIndisponivelError(Exception):
    """O webhook da IA existe mas não respondeu (fora do ar, timeout ou
    resposta inválida). Retorna HTTP 503."""


class ConsultarIaService:
    """Envia a pergunta do usuário para o agente de IA construído no n8n,
    junto com um retrato da situação financeira dele, e devolve a resposta.

    O contexto financeiro vai junto de propósito: sem ele a IA responderia
    de forma genérica, que foi justamente a queixa levantada na pesquisa
    com usuários do relatório. A regra de RF14/RF15 (só investir depois da
    reserva formada) também é enviada, para a IA não sugerir investimento
    a quem ainda não pode.
    """

    def executar(self, usuario_id, pergunta):
        pergunta = (pergunta or "").strip()
        if not pergunta:
            raise ValueError("Escreva sua pergunta.")

        usuario = Usuario.buscar_por_id(usuario_id)
        if not usuario:
            return None

        url = os.environ.get("N8N_WEBHOOK_URL", "").strip()
        if not url:
            raise IaNaoConfiguradaError(
                "A IA ainda não foi configurada neste servidor."
            )

        cabecalhos = {"Content-Type": "application/json"}
        chave = os.environ.get("N8N_API_KEY", "").strip()
        if chave:
            cabecalhos["X-API-Key"] = chave

        corpo = {
            # usuario_id identifica a conversa na memória do agente, para o
            # histórico de um usuário não vazar para outro.
            "usuario_id": usuario_id,
            "pergunta": pergunta,
            "contexto": self._montar_contexto(usuario_id, usuario),
        }

        try:
            resposta = requests.post(
                url, json=corpo, headers=cabecalhos, timeout=SEGUNDOS_TIMEOUT
            )
            resposta.raise_for_status()
            dados = resposta.json()
        except (requests.RequestException, ValueError):
            raise IaIndisponivelError("A IA está indisponível no momento.")

        texto = self._extrair_resposta(dados)
        if not texto:
            raise IaIndisponivelError("A IA não conseguiu responder agora.")

        return {"resposta": texto}

    def _montar_contexto(self, usuario_id, usuario):
        reserva = CalcularStatusReservaEmergenciaService().executar(usuario_id)
        score = CalcularScoreFinanceiroService().executar(usuario_id)

        return {
            "nome": usuario.nome,
            "perfil_risco": usuario.perfil_risco,
            "renda_mensal": usuario.renda_mensal,
            "saldo": CalcularSaldoService().executar(usuario_id),
            "capacidade_economia_mensal": CalcularCapacidadeEconomiaService().executar(usuario_id),
            "gastos_por_categoria": CalcularGastosPorCategoriaService().executar(usuario_id),
            "reserva_emergencia": reserva,
            "pode_investir": reserva["sugestoes_investimento_liberadas"],
            "score": score,
        }

    def _extrair_resposta(self, dados):
        """O formato exato depende de como o workflow do n8n foi montado.
        Aceitamos as formas mais comuns para não travar a integração por
        causa do nome de um campo."""
        if isinstance(dados, list):
            dados = dados[0] if dados else {}
        if isinstance(dados, str):
            return dados.strip()
        if not isinstance(dados, dict):
            return ""

        for chave in ("resposta", "output", "text", "message", "answer"):
            valor = dados.get(chave)
            if isinstance(valor, str) and valor.strip():
                return valor.strip()
        return ""
