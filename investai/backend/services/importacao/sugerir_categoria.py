import re
import unicodedata

# Palavras que costumam aparecer na descrição do extrato, por categoria.
# É uma lista simples e fácil de aumentar: a sugestão não precisa acertar
# sempre, porque o usuário confere e corrige na tela de revisão.
PALAVRAS_POR_CATEGORIA = {
    "alimentacao": [
        "MERCADO", "SUPERMERC", "ATACAD", "PADARIA", "ACOUGUE", "HORTIFRUTI",
        "RESTAURANTE", "LANCHONETE", "PIZZARIA", "IFOOD", "BURGER",
    ],
    "transporte": [
        "UBER", "99APP", "99 TAXI", "99POP", "99* POP", "99 POP", "POSTO", "COMBUSTIVEL",
        "ESTACIONAMENTO", "PEDAGIO", "METRO", "ONIBUS",
    ],
    "saude": [
        "FARMACIA", "DROGARIA", "DROGASIL", "RD SAUDE", "HOSPITAL", "CLINICA",
        "LABORATORIO", "UNIMED", "DENTISTA",
    ],
    "lazer": [
        "NETFLIX", "SPOTIFY", "CINEMA", "STEAM", "PRIME VIDEO", "DISNEY",
        "INGRESSO", "PLAYSTATION", "XBOX", "NINTENDO", "BAR",
    ],
    "contas_fixas": [
        "ALUGUEL", "CONDOMINIO", "ENERGIA", "CEMIG", "ENEL", "COPASA",
        "SABESP", "INTERNET", "VIVO", "CLARO", "TIM",
    ],
    "educacao": [
        "FACULDADE", "ESCOLA", "CURSO", "UDEMY", "LIVRARIA", "MENSALIDADE",
    ],
}

PALAVRAS_DE_SALARIO = ["SALARIO", "FOLHA", "PROVENTOS", "PAGAMENTO DE SALARIO"]

# Dinheiro que só mudou de lugar: não é gasto nem renda de verdade, e
# contaria errado no saldo e na reserva de emergência.
PALAVRAS_DE_MOVIMENTACAO_INTERNA = [
    "APLICACAO", "RESGATE", "FATURA", "MESMA TITULARIDADE", "ENTRE CONTAS",
]


def normalizar(texto):
    """Maiúsculas e sem acento, para 'Farmácia' e 'FARMACIA' baterem."""
    sem_acento = unicodedata.normalize("NFKD", texto or "")
    sem_acento = "".join(c for c in sem_acento if not unicodedata.combining(c))
    return sem_acento.upper()


def _contem(texto_normalizado, palavras):
    """Diz se alguma das palavras aparece no texto.

    Toda palavra precisa estar no começo de uma palavra do texto (o `\\b`),
    para "TIM" não casar com "ULTIMO". As curtas, de até 4 letras, precisam
    ser a palavra inteira, para "BAR" não casar com "BARBEARIA"; as longas
    podem ser só o começo, e assim "SUPERMERC" pega "SUPERMERCADO".
    """
    for palavra in palavras:
        fim = r"\b" if len(palavra) <= 4 else ""
        if re.search(rf"\b{re.escape(palavra)}{fim}", texto_normalizado):
            return True
    return False


def sugerir_categoria(descricao, tipo):
    """Categoria provável de uma linha do extrato. Quando nenhuma palavra
    conhecida aparece, devolve 'outros'."""
    texto = normalizar(descricao)

    if tipo == "renda":
        return "salario" if _contem(texto, PALAVRAS_DE_SALARIO) else "outros"

    for categoria, palavras in PALAVRAS_POR_CATEGORIA.items():
        if _contem(texto, palavras):
            return categoria
    return "outros"


def parece_movimentacao_interna(descricao):
    return _contem(normalizar(descricao), PALAVRAS_DE_MOVIMENTACAO_INTERNA)
