import csv
import io
from datetime import date

from fpdf import FPDF

from models import Usuario
from services.movimentacao.gerar_relatorio_mensal_service import GerarRelatorioMensalService

FORMATOS = {
    "csv": "text/csv; charset=utf-8",
    "pdf": "application/pdf",
}

MESES = [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
]

# Mesmos rótulos usados no app (lib/models/movimentacao.dart).
ROTULOS_CATEGORIA = {
    "alimentacao": "Alimentação",
    "lazer": "Lazer",
    "contas_fixas": "Contas fixas",
    "transporte": "Transporte",
    "saude": "Saúde",
    "educacao": "Educação",
    "salario": "Salário",
    "freelance": "Freelance",
    "investimentos": "Investimentos",
    "outros": "Outros",
}


class ExportarRelatorioMensalService:
    """Gera o relatório financeiro mensal (RF10) como arquivo, para o
    usuário guardar ou enviar: CSV para abrir em planilha, PDF para ler."""

    def executar(self, usuario_id, formato, ano=None, mes=None):
        formato = (formato or "").strip().lower()
        if formato not in FORMATOS:
            raise ValueError("Formato inválido. Use 'pdf' ou 'csv'.")
        if mes is not None and not 1 <= mes <= 12:
            raise ValueError("O mês deve ficar entre 1 e 12.")

        relatorio = GerarRelatorioMensalService().executar(usuario_id, ano=ano, mes=mes)
        # Em ordem cronológica, que é como se lê um extrato.
        itens = sorted(relatorio["itens"], key=lambda item: str(item["data"]))

        if formato == "csv":
            conteudo = self._gerar_csv(itens)
        else:
            usuario = Usuario.buscar_por_id(usuario_id)
            conteudo = self._gerar_pdf(relatorio, itens, usuario.nome if usuario else "")

        return {
            "conteudo": conteudo,
            "mimetype": FORMATOS[formato],
            "nome_arquivo": f"relatorio-investai-{relatorio['ano']:04d}-{relatorio['mes']:02d}.{formato}",
        }

    # ── CSV ───────────────────────────────────────────────────────────

    def _gerar_csv(self, itens):
        """Uma linha por movimentação. Segue o que o Excel em português
        espera: ponto e vírgula entre colunas, vírgula decimal e BOM para
        os acentos. Despesas saem negativas, de modo que somar a coluna
        Valor dá o saldo do mês."""
        saida = io.StringIO()
        escritor = csv.writer(saida, delimiter=";", lineterminator="\r\n")
        escritor.writerow(["Data", "Descrição", "Categoria", "Tipo", "Valor"])
        for item in itens:
            renda = item["tipo"] == "renda"
            valor = item["valor"] if renda else -item["valor"]
            escritor.writerow([
                self._data_br(item["data"]),
                self._texto_seguro_planilha(item["descricao"]),
                self._rotulo(item["categoria"]),
                "Receita" if renda else "Despesa",
                f"{valor:.2f}".replace(".", ","),
            ])
        return saida.getvalue().encode("utf-8-sig")

    def _texto_seguro_planilha(self, texto):
        """Planilhas executam como fórmula o texto que começa com estes
        caracteres; o apóstrofo na frente faz ser lido como texto."""
        texto = str(texto or "")
        return f"'{texto}" if texto[:1] in ("=", "+", "-", "@") else texto

    # ── PDF ───────────────────────────────────────────────────────────

    def _gerar_pdf(self, relatorio, itens, nome_usuario):
        pdf = FPDF()
        pdf.set_auto_page_break(auto=True, margin=15)
        pdf.add_page()

        pdf.set_font("Helvetica", "B", 16)
        pdf.cell(0, 9, "InvestAI - Relatório financeiro", new_x="LMARGIN", new_y="NEXT")
        pdf.set_font("Helvetica", "", 11)
        periodo = f"{MESES[relatorio['mes'] - 1]} de {relatorio['ano']}"
        pdf.cell(0, 6, self._latin1(f"{periodo} - {nome_usuario}"), new_x="LMARGIN", new_y="NEXT")
        pdf.set_text_color(120, 120, 120)
        pdf.set_font("Helvetica", "", 9)
        pdf.cell(0, 5, f"Gerado em {date.today().strftime('%d/%m/%Y')}", new_x="LMARGIN", new_y="NEXT")
        pdf.set_text_color(0, 0, 0)
        pdf.ln(4)

        self._titulo_secao(pdf, "Resumo do mês")
        pdf.set_font("Helvetica", "", 10)
        with pdf.table(col_widths=(1, 1, 1), text_align="RIGHT") as tabela:
            tabela.row(["Entradas", "Saídas", "Saldo do mês"])
            tabela.row([
                self._reais(relatorio["total_entradas"]),
                self._reais(relatorio["total_saidas"]),
                self._reais(relatorio["saldo_periodo"]),
            ])
        pdf.ln(6)

        gastos = self._gastos_por_categoria(itens)
        if gastos:
            total_gastos = sum(total for _, total in gastos)
            self._titulo_secao(pdf, "Gastos por categoria")
            pdf.set_font("Helvetica", "", 10)
            with pdf.table(col_widths=(3, 2, 1), text_align=("LEFT", "RIGHT", "RIGHT")) as tabela:
                tabela.row(["Categoria", "Total", "%"])
                for categoria, total in gastos:
                    tabela.row([
                        self._latin1(self._rotulo(categoria)),
                        self._reais(total),
                        f"{total / total_gastos * 100:.0f}%",
                    ])
            pdf.ln(6)

        self._titulo_secao(pdf, "Movimentações")
        pdf.set_font("Helvetica", "", 9)
        if not itens:
            pdf.cell(0, 6, "Nenhuma movimentação registrada neste mês.", new_x="LMARGIN", new_y="NEXT")
        else:
            with pdf.table(
                col_widths=(2, 6, 3, 3),
                text_align=("LEFT", "LEFT", "LEFT", "RIGHT"),
            ) as tabela:
                tabela.row(["Data", "Descrição", "Categoria", "Valor"])
                for item in itens:
                    sinal = "+" if item["tipo"] == "renda" else "-"
                    tabela.row([
                        self._data_br(item["data"]),
                        self._latin1(item["descricao"]),
                        self._latin1(self._rotulo(item["categoria"])),
                        f"{sinal} {self._reais(item['valor'])}",
                    ])

        return bytes(pdf.output())

    def _titulo_secao(self, pdf, texto):
        pdf.set_font("Helvetica", "B", 12)
        pdf.cell(0, 8, texto, new_x="LMARGIN", new_y="NEXT")

    def _gastos_por_categoria(self, itens):
        totais = {}
        for item in itens:
            if item["tipo"] == "gasto":
                totais[item["categoria"]] = totais.get(item["categoria"], 0.0) + item["valor"]
        return sorted(totais.items(), key=lambda par: par[1], reverse=True)

    def _latin1(self, texto):
        """As fontes embutidas do PDF só cobrem Latin-1: acentos passam,
        mas um emoji na descrição derrubaria a geração. Troca por '?'."""
        return str(texto or "").encode("latin-1", "replace").decode("latin-1")

    # ── Formatação ────────────────────────────────────────────────────

    def _rotulo(self, categoria):
        return ROTULOS_CATEGORIA.get(categoria, categoria)

    def _data_br(self, data):
        try:
            return date.fromisoformat(str(data)).strftime("%d/%m/%Y")
        except ValueError:
            return str(data)

    def _reais(self, valor):
        inteiro = f"{abs(valor):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
        return f"{'-' if valor < 0 else ''}R$ {inteiro}"
