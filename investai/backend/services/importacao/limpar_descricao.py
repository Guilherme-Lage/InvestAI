import re

# Cada banco escreve a descrição do seu jeito, quase sempre com códigos
# internos que não interessam a quem lê. As regras abaixo tiram o que é
# ruído nos extratos já testados (Inter); onde o padrão não aparece, o
# texto passa intacto.
REGRAS = [
    # Aspas em volta do detalhe:  Pix enviado: "..."  ->  Pix enviado: ...
    (r'"', ""),
    # Código do comprovante de Pix:  Cp :14796606-RD SAUDE  ->  RD SAUDE
    (r"\bCp\s*:\s*\d+-", ""),
    # Banco e agência antes do nome:  : 00019 16897471 FULANO  ->  : FULANO
    (r"(?<=: )(?:\d+ )+", ""),
    # Compra no cartão:  No estabelecimento LOJA  ->  LOJA
    (r"\b(?:Estorno no|No) estabelecimento\s+", ""),
    # Data e hora no fim da compra:  99* POP 26Set 10h15min  ->  99* POP
    (r"\s+\d{1,2}[A-Za-z]{3} \d{1,2}h\d{2}min$", ""),
]


def limpar_descricao(texto):
    """Deixa a descrição do extrato legível.

        Pix enviado: "Cp :14796606-RD SAUDE"       ->  Pix enviado: RD SAUDE
        Pix enviado: "00019 16897471 FULANO"       ->  Pix enviado: FULANO
        Compra no debito: "No estabelecimento
            99* POP 26Set 10h15min"                ->  Compra no debito: 99* POP
    """
    texto = texto or ""
    for padrao, troca in REGRAS:
        texto = re.sub(padrao, troca, texto, flags=re.IGNORECASE)
    texto = re.sub(r"\s+", " ", texto).strip()
    return texto.rstrip(":").strip()
