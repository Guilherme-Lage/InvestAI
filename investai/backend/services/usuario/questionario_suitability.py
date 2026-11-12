"""Questionário de suitability (análise do perfil de investidor - RF18).

O perfil deixa de ser escolhido livremente: a pessoa responde perguntas
sobre objetivo, prazo, reação a perdas e experiência, e o perfil sai da
soma dos pontos. As perguntas e a pontuação ficam no backend (e não no
app) para que o cálculo seja um só e o perfil gravado não possa ser
escolhido direto pelo cliente.
"""

VERSAO_ATUAL = "1.0"

# Cada opção vale de 1 (mais cautelosa) a 4 (mais disposta a risco).
PERGUNTAS = [
    {
        "id": "objetivo",
        "texto": "Qual é o seu principal objetivo ao investir?",
        "opcoes": [
            {"texto": "Proteger o que já tenho, sem correr riscos", "pontos": 1},
            {"texto": "Ganhar um pouco acima da poupança, com segurança", "pontos": 2},
            {"texto": "Fazer o dinheiro crescer, aceitando alguma oscilação", "pontos": 3},
            {"texto": "Buscar o maior retorno possível, mesmo com risco alto", "pontos": 4},
        ],
    },
    {
        "id": "prazo",
        "texto": "Por quanto tempo você pretende deixar o dinheiro investido?",
        "opcoes": [
            {"texto": "Menos de 1 ano", "pontos": 1},
            {"texto": "De 1 a 3 anos", "pontos": 2},
            {"texto": "De 3 a 5 anos", "pontos": 3},
            {"texto": "Mais de 5 anos", "pontos": 4},
        ],
    },
    {
        "id": "reacao_queda",
        "texto": "Se seus investimentos caíssem 15% em um mês, o que você faria?",
        "opcoes": [
            {"texto": "Resgataria tudo na hora", "pontos": 1},
            {"texto": "Resgataria uma parte para não perder mais", "pontos": 2},
            {"texto": "Manteria e esperaria recuperar", "pontos": 3},
            {"texto": "Aproveitaria para investir mais", "pontos": 4},
        ],
    },
    {
        "id": "conhecimento",
        "texto": "Como você descreve seu conhecimento sobre investimentos?",
        "opcoes": [
            {"texto": "Nenhum: nunca investi", "pontos": 1},
            {"texto": "Básico: conheço poupança, CDB e Tesouro", "pontos": 2},
            {"texto": "Intermediário: já investi em fundos ou ações", "pontos": 3},
            {"texto": "Avançado: acompanho o mercado com frequência", "pontos": 4},
        ],
    },
    {
        "id": "experiencia",
        "texto": "Em quais destes você já investiu?",
        "opcoes": [
            {"texto": "Só poupança, ou nunca investi", "pontos": 1},
            {"texto": "Renda fixa (CDB, Tesouro, LCI/LCA)", "pontos": 2},
            {"texto": "Fundos multimercado ou fundos imobiliários", "pontos": 3},
            {"texto": "Ações, ETFs, criptomoedas ou derivativos", "pontos": 4},
        ],
    },
    {
        "id": "parcela_patrimonio",
        "texto": "Quanto do seu patrimônio você pensa em aplicar em investimentos de maior risco?",
        "opcoes": [
            {"texto": "Nada", "pontos": 1},
            {"texto": "Até 10%", "pontos": 2},
            {"texto": "De 10% a 30%", "pontos": 3},
            {"texto": "Mais de 30%", "pontos": 4},
        ],
    },
    {
        "id": "necessidade_resgate",
        "texto": "Qual a chance de você precisar desse dinheiro de repente?",
        "opcoes": [
            {"texto": "Alta: posso precisar a qualquer momento", "pontos": 1},
            {"texto": "Média: talvez precise em alguns meses", "pontos": 2},
            {"texto": "Baixa: tenho reserva para imprevistos", "pontos": 3},
            {"texto": "Muito baixa: é um dinheiro que não vou usar tão cedo", "pontos": 4},
        ],
    },
]

PONTUACAO_MINIMA = len(PERGUNTAS)
PONTUACAO_MAXIMA = 4 * len(PERGUNTAS)

# Faixas da soma dos pontos (7 a 28). Até 13: conservador; 14 a 21:
# moderado; 22 ou mais: arrojado.
LIMITE_CONSERVADOR = 13
LIMITE_MODERADO = 21

DESCRICOES_PERFIL = {
    "conservador": "Você prioriza segurança e liquidez. O foco é renda fixa, "
                   "com o dinheiro disponível quando precisar.",
    "moderado": "Você busca equilíbrio: a maior parte em renda fixa, com uma "
                "parcela em investimentos que oscilam mais para crescer.",
    "arrojado": "Você aceita oscilações no caminho em busca de retorno maior "
                "no longo prazo, inclusive em renda variável.",
}


def questionario_atual():
    """O que o app precisa para mostrar o questionário. Os pontos de cada
    opção não vão junto: o cálculo é feito aqui, ao receber as respostas."""
    return {
        "versao": VERSAO_ATUAL,
        "perguntas": [
            {
                "id": p["id"],
                "texto": p["texto"],
                "opcoes": [o["texto"] for o in p["opcoes"]],
            }
            for p in PERGUNTAS
        ],
    }


def perfil_pela_pontuacao(pontuacao):
    if pontuacao <= LIMITE_CONSERVADOR:
        return "conservador"
    if pontuacao <= LIMITE_MODERADO:
        return "moderado"
    return "arrojado"


def avaliar_respostas(respostas):
    """Recebe {id_da_pergunta: índice_da_opção} com todas as perguntas
    respondidas e devolve {"perfil", "pontuacao", "descricao"}.

    Levanta ValueError se faltar resposta ou se alguma for inválida: um
    perfil calculado com metade do questionário não diz nada."""
    if not isinstance(respostas, dict):
        raise ValueError("Respostas do questionário inválidas.")

    pontuacao = 0
    for pergunta in PERGUNTAS:
        escolha = respostas.get(pergunta["id"])
        # bool é subclasse de int em Python; True não é uma opção válida.
        if isinstance(escolha, bool) or not isinstance(escolha, int):
            raise ValueError("Responda todas as perguntas do questionário.")
        if not 0 <= escolha < len(pergunta["opcoes"]):
            raise ValueError("Resposta inválida no questionário.")
        pontuacao += pergunta["opcoes"][escolha]["pontos"]

    perfil = perfil_pela_pontuacao(pontuacao)
    return {
        "perfil": perfil,
        "pontuacao": pontuacao,
        "descricao": DESCRICOES_PERFIL[perfil],
    }
