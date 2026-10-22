import html
import re
from datetime import date

from services.importacao.limpar_descricao import limpar_descricao

TAMANHO_MAXIMO_DESCRICAO = 120  # limite da coluna movimentacao.descricao


class LerExtratoOfxService:
    """Lê um extrato bancário no formato OFX e devolve as transações.

    OFX é o formato de exportação de extrato que praticamente todo banco
    brasileiro oferece. Por dentro é um texto com marcações parecidas com
    HTML; cada transação fica num bloco assim:

        <STMTTRN>
        <TRNTYPE>DEBIT
        <DTPOSTED>20261005120000[-3:BRT]
        <TRNAMT>-45.90
        <FITID>202610050001
        <MEMO>COMPRA CARTAO MERCADO BH
        </STMTTRN>

    Aqui só se lê o arquivo. Decidir o que é novo, repetido ou suspeito é
    trabalho do AnalisarExtratoService.
    """

    def executar(self, conteudo):
        texto = self._decodificar(conteudo)
        if not re.search(r"<OFX>", texto, re.IGNORECASE):
            raise ValueError("Este arquivo não parece ser um extrato OFX.")

        banco = self._campo(texto, "BANKID") or self._campo(texto, "ORG") or ""
        conta = self._campo(texto, "ACCTID") or ""

        transacoes = []
        repeticoes = {}  # para identificar transações que vieram sem código
        blocos = re.findall(r"<STMTTRN>(.*?)</STMTTRN>", texto, re.IGNORECASE | re.DOTALL)
        for bloco in blocos:
            transacao = self._ler_transacao(bloco, banco, conta, repeticoes)
            if transacao:
                transacoes.append(transacao)

        if not transacoes:
            raise ValueError("Nenhuma transação encontrada neste extrato.")

        transacoes.sort(key=lambda t: t["data"])
        return {
            "banco": banco,
            "conta": conta,
            "transacoes": transacoes,
        }

    def _decodificar(self, conteudo):
        """Extratos antigos vêm em Windows-1252 e os novos em UTF-8. O
        cabeçalho nem sempre diz a verdade, então tenta UTF-8 (que falha
        de forma detectável) e cai para o outro."""
        if isinstance(conteudo, str):
            return conteudo
        try:
            return conteudo.decode("utf-8")
        except UnicodeDecodeError:
            return conteudo.decode("cp1252", errors="replace")

    def _campo(self, texto, nome):
        """Valor de uma marcação. No OFX antigo os campos não têm
        fechamento (<MEMO>texto), então o valor vai até a próxima marcação
        ou o fim da linha."""
        achado = re.search(rf"<{nome}>([^<\r\n]*)", texto, re.IGNORECASE)
        if not achado:
            return None
        valor = html.unescape(achado.group(1)).strip()
        return valor or None

    def _ler_transacao(self, bloco, banco, conta, repeticoes):
        """Devolve None para linhas que não dá para aproveitar (sem data,
        sem valor ou com valor zero) em vez de derrubar o extrato todo."""
        data = self._data(self._campo(bloco, "DTPOSTED"))
        valor = self._valor(self._campo(bloco, "TRNAMT"))
        if data is None or not valor:
            return None

        bruta = self._campo(bloco, "MEMO") or self._campo(bloco, "NAME") or ""
        descricao = (limpar_descricao(bruta) or "Sem descrição")[:TAMANHO_MAXIMO_DESCRICAO]

        codigo = self._campo(bloco, "FITID")
        if not codigo:
            # Sem código do banco, monta um a partir do conteúdo. O contador
            # separa duas compras iguais no mesmo dia.
            chave = f"{data.isoformat()}|{valor:.2f}|{descricao}"
            repeticoes[chave] = repeticoes.get(chave, 0) + 1
            codigo = f"sem-codigo|{chave}|{repeticoes[chave]}"

        return {
            # Banco e conta entram porque o código só é único dentro da conta.
            "identificador": f"{banco}:{conta}:{codigo}"[:200],
            "data": data.isoformat(),
            "descricao": descricao,
            # No extrato, saída de dinheiro vem com valor negativo.
            "tipo": "gasto" if valor < 0 else "renda",
            "valor": round(abs(valor), 2),
        }

    def _data(self, texto):
        """DTPOSTED começa com AAAAMMDD; o resto (hora, fuso) é ignorado."""
        if not texto or not re.match(r"\d{8}", texto):
            return None
        try:
            return date(int(texto[0:4]), int(texto[4:6]), int(texto[6:8]))
        except ValueError:
            return None

    def _valor(self, texto):
        if not texto:
            return None
        try:
            # Alguns bancos brasileiros exportam com vírgula decimal.
            return float(texto.replace(",", "."))
        except ValueError:
            return None
