"""Gera um extrato bancário fictício em OFX, para testar a importação
sem usar o extrato de ninguém.

Uso, a partir da pasta backend:

    python gerar_extrato_exemplo.py

O arquivo sai em backend/instance/extrato_exemplo.ofx (pasta que não vai
para o Git) e cobre o mês passado inteiro. As contas fixas batem com as da
conta de demonstração (criar_conta_demo.py): importando o arquivo nela, dá
para ver o app apontando o que já estava lançado.
"""
import calendar
import os
from datetime import date

# (dia, valor, descrição). Valor negativo é saída, como no extrato real.
LINHAS = [
    (3, -212.47, "COMPRA CARTAO - SUPERMERCADO BH"),
    (5, 5200.00, "PAGAMENTO DE SALARIO - EMPRESA LTDA"),   # já lançado pela recorrência
    (6, -38.90, "UBER *TRIP"),
    (8, -57.30, "DROGARIA ARAUJO"),
    (10, -1500.00, "PIX ENVIADO - IMOBILIARIA CENTRAL"),   # o aluguel da recorrência
    (11, -64.90, "IFOOD *RESTAURANTE"),
    (12, -800.00, "APLICACAO RDB"),                        # dinheiro mudando de lugar
    (15, -120.00, "DEB AUT - INTERNET FIBRA"),             # já lançado pela recorrência
    (17, -89.00, "PIX ENVIADO - JOAO PEDRO SILVA"),
    (20, -39.90, "NETFLIX.COM"),                           # o streaming da recorrência
    (22, -143.18, "POSTO IPIRANGA"),
    (25, -35.00, "PADARIA PÃO QUENTE"),
    (27, 250.00, "PIX RECEBIDO - MARIA SOUZA"),
]


def gerar_extrato_exemplo(hoje=None):
    """Devolve o texto do extrato, com as datas no mês anterior a `hoje`."""
    hoje = hoje or date.today()
    ano, mes = (hoje.year - 1, 12) if hoje.month == 1 else (hoje.year, hoje.month - 1)
    ultimo_dia = calendar.monthrange(ano, mes)[1]

    transacoes = []
    for numero, (dia, valor, descricao) in enumerate(LINHAS, start=1):
        data = f"{ano:04d}{mes:02d}{min(dia, ultimo_dia):02d}"
        transacoes.append(
            "<STMTTRN>\n"
            f"<TRNTYPE>{'CREDIT' if valor > 0 else 'DEBIT'}\n"
            f"<DTPOSTED>{data}120000[-3:BRT]\n"
            f"<TRNAMT>{valor:.2f}\n"
            # O código não muda entre uma geração e outra do mesmo mês: é o
            # que permite testar que importar de novo não duplica.
            f"<FITID>{data}{numero:04d}\n"
            f"<MEMO>{descricao}\n"
            "</STMTTRN>\n"
        )

    return (
        "OFXHEADER:100\n"
        "DATA:OFXSGML\n"
        "VERSION:102\n"
        "ENCODING:USASCII\n"
        "CHARSET:1252\n"
        "\n"
        "<OFX>\n"
        "<BANKMSGSRSV1><STMTTRNRS><STMTRS>\n"
        "<CURDEF>BRL\n"
        "<BANKACCTFROM>\n"
        "<BANKID>0999\n"
        "<ACCTID>12345-6\n"
        "<ACCTTYPE>CHECKING\n"
        "</BANKACCTFROM>\n"
        "<BANKTRANLIST>\n"
        f"<DTSTART>{ano:04d}{mes:02d}01\n"
        f"<DTEND>{ano:04d}{mes:02d}{ultimo_dia:02d}\n"
        + "".join(transacoes) +
        "</BANKTRANLIST>\n"
        "</STMTRS></STMTTRNRS></BANKMSGSRSV1>\n"
        "</OFX>\n"
    )


if __name__ == "__main__":
    pasta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "instance")
    os.makedirs(pasta, exist_ok=True)
    caminho = os.path.join(pasta, "extrato_exemplo.ofx")
    # Windows-1252, como a maioria dos bancos brasileiros exporta.
    with open(caminho, "w", encoding="cp1252", newline="\r\n") as arquivo:
        arquivo.write(gerar_extrato_exemplo())
    print(f"Extrato de exemplo gravado em {caminho}")
