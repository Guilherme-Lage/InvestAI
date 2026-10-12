"""Termos de consentimento sobre o uso dos dados financeiros.

Ficam no backend e não no app para que a versão aceita por cada usuário
possa ser conferida no servidor - é isso que dá valor ao registro guardado
em `Usuario.consentimento_versao`.
"""

import os

VERSAO_ATUAL = "1.0"

TITULO = "Como usamos seus dados"

RESUMO = (
    "Para funcionar, o InvestAI precisa saber quanto você ganha e gasta. "
    "Esses dados ficam na sua conta e são usados só para gerar suas "
    "orientações."
)

ITENS = [
    {
        "titulo": "O que coletamos",
        "texto": "Nome, e-mail, renda mensal, despesas, metas e os "
                 "investimentos que você cadastrar. A senha é guardada "
                 "apenas como código embaralhado (hash) — nem nós "
                 "conseguimos lê-la.",
    },
    {
        "titulo": "Para que usamos",
        "texto": "Calcular seu saldo, sua reserva de emergência, seu score "
                 "e as orientações do guia financeiro. Nada é vendido nem "
                 "compartilhado com anunciantes.",
    },
    {
        "titulo": "O assistente de IA",
        "texto": "Quando você conversa com o assistente, enviamos junto da "
                 "sua pergunta um resumo da sua situação financeira (saldo, "
                 "reserva, perfil e gastos por categoria) para um serviço de "
                 "inteligência artificial externo. Sem isso a resposta seria "
                 "genérica. Seu nome vai junto; seu e-mail e sua senha não.",
    },
    {
        "titulo": "Orientação, não consultoria",
        "texto": "O InvestAI é um projeto acadêmico de educação financeira. "
                 "As sugestões são educativas e não substituem a orientação "
                 "de um profissional certificado. Não temos parceria com "
                 "nenhum banco ou corretora.",
    },
    {
        "titulo": "Seus dados são seus",
        "texto": "Você pode excluir sua conta a qualquer momento pelo "
                 "Perfil. Ao excluir, apagamos também suas movimentações, "
                 "metas e investimentos.",
    },
]


# O texto formal (LGPD) vive no repositório como documento, para poder ser
# entregue e versionado junto do projeto. O app lê daqui para mostrar o
# mesmo conteúdo - evita as duas versões saírem de sincronia.
_PASTA_PROJETO = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "..")
)
CAMINHO_TERMO_COMPLETO = os.path.join(
    _PASTA_PROJETO, "docs", "TERMO_DE_CONSENTIMENTO.md"
)


def termos_atuais():
    return {
        "versao": VERSAO_ATUAL,
        "titulo": TITULO,
        "resumo": RESUMO,
        "itens": ITENS,
    }


def termo_completo():
    """Texto integral do termo, em Markdown. Devolve None se o arquivo não
    estiver disponível - a tela então mostra só o resumo."""
    try:
        with open(CAMINHO_TERMO_COMPLETO, encoding="utf-8") as arquivo:
            return arquivo.read()
    except OSError:
        return None
