import unittest
from datetime import date

from tests.base import TesteComBanco
from models import Movimentacao
from services.auth_service import AuthService
from services.movimentacao.exportar_relatorio_mensal_service import (
    ExportarRelatorioMensalService,
)


class TesteExportarRelatorio(TesteComBanco):
    """Exportação do relatório mensal (RF10) em CSV e PDF."""

    def setUp(self):
        super().setUp()
        self.usuario = self.criar_usuario(nome="Maria Teste")
        self.service = ExportarRelatorioMensalService()

    def _movimentacao(self, descricao, tipo, valor, data, categoria="outros"):
        Movimentacao(
            descricao=descricao, tipo=tipo, valor=valor, data=data,
            categoria=categoria, usuario_id=self.usuario.id,
        ).salvar()

    def _linhas_csv(self, **parametros):
        arquivo = self.service.executar(self.usuario.id, "csv", **parametros)
        texto = arquivo["conteudo"].decode("utf-8-sig")
        return [linha.split(";") for linha in texto.strip().split("\r\n")]

    def test_csv_traz_so_o_mes_pedido_em_ordem_de_data(self):
        self._movimentacao("Mercado", "gasto", 250.5, "2026-03-20", "alimentacao")
        self._movimentacao("Salário", "renda", 5000, "2026-03-05", "salario")
        self._movimentacao("Outro mês", "gasto", 99, "2026-04-01")

        linhas = self._linhas_csv(ano=2026, mes=3)

        self.assertEqual(linhas, [
            ["Data", "Descrição", "Categoria", "Tipo", "Valor"],
            ["05/03/2026", "Salário", "Salário", "Receita", "5000,00"],
            ["20/03/2026", "Mercado", "Alimentação", "Despesa", "-250,50"],
        ])

    def test_csv_tem_bom_para_o_excel_ler_os_acentos(self):
        arquivo = self.service.executar(self.usuario.id, "csv", ano=2026, mes=3)

        self.assertTrue(arquivo["conteudo"].startswith(b"\xef\xbb\xbf"))

    def test_csv_neutraliza_descricao_que_parece_formula(self):
        self._movimentacao("=SOMA(A1:A9)", "gasto", 10, "2026-03-01")

        linhas = self._linhas_csv(ano=2026, mes=3)

        self.assertEqual(linhas[1][1], "'=SOMA(A1:A9)")

    def test_pdf_e_gerado_mesmo_com_emoji_na_descricao(self):
        self._movimentacao("Pizza 🍕 com a galera", "gasto", 80, "2026-03-01", "lazer")

        arquivo = self.service.executar(self.usuario.id, "pdf", ano=2026, mes=3)

        self.assertTrue(arquivo["conteudo"].startswith(b"%PDF"))
        self.assertEqual(arquivo["mimetype"], "application/pdf")

    def test_pdf_de_mes_sem_movimentacao(self):
        arquivo = self.service.executar(self.usuario.id, "pdf", ano=2026, mes=3)

        self.assertTrue(arquivo["conteudo"].startswith(b"%PDF"))

    def test_pdf_com_muitas_movimentacoes_quebra_pagina(self):
        for dia in range(1, 29):
            for n in range(4):
                self._movimentacao(f"Compra {n}", "gasto", 10 + n, f"2026-03-{dia:02d}")

        arquivo = self.service.executar(self.usuario.id, "pdf", ano=2026, mes=3)

        self.assertGreater(arquivo["conteudo"].count(b"/Type /Page\n"), 1)

    def test_nome_do_arquivo_traz_o_periodo(self):
        arquivo = self.service.executar(self.usuario.id, "csv", ano=2026, mes=3)

        self.assertEqual(arquivo["nome_arquivo"], "relatorio-investai-2026-03.csv")

    def test_sem_periodo_usa_o_mes_atual(self):
        hoje = date.today()

        arquivo = self.service.executar(self.usuario.id, "csv")

        self.assertEqual(
            arquivo["nome_arquivo"], f"relatorio-investai-{hoje:%Y-%m}.csv"
        )

    def test_recusa_formato_ou_mes_invalido(self):
        with self.assertRaises(ValueError):
            self.service.executar(self.usuario.id, "xlsx", ano=2026, mes=3)
        with self.assertRaises(ValueError):
            self.service.executar(self.usuario.id, "csv", ano=2026, mes=13)

    def test_nao_inclui_movimentacao_de_outro_usuario(self):
        outro = self.criar_usuario()
        Movimentacao(
            descricao="Alheia", tipo="gasto", valor=1, data="2026-03-01",
            categoria="outros", usuario_id=outro.id,
        ).salvar()

        linhas = self._linhas_csv(ano=2026, mes=3)

        self.assertEqual(len(linhas), 1)  # só o cabeçalho

    def test_rota_devolve_o_arquivo_para_download(self):
        self._movimentacao("Mercado", "gasto", 50, "2026-03-20")
        token = AuthService.gerar_token(self.usuario.id)
        cliente = self.app.test_client()
        cabecalho = {"Authorization": f"Bearer {token}"}

        resposta = cliente.get(
            "/api/movimentacoes/relatorio-mensal/exportar?formato=csv&ano=2026&mes=3",
            headers=cabecalho,
        )
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("text/csv", resposta.headers["Content-Type"])
        self.assertIn("relatorio-investai-2026-03.csv", resposta.headers["Content-Disposition"])
        self.assertIn("Mercado", resposta.data.decode("utf-8-sig"))

        invalida = cliente.get(
            "/api/movimentacoes/relatorio-mensal/exportar?formato=doc", headers=cabecalho
        )
        self.assertEqual(invalida.status_code, 400)

        sem_token = cliente.get("/api/movimentacoes/relatorio-mensal/exportar?formato=csv")
        self.assertEqual(sem_token.status_code, 401)


if __name__ == "__main__":
    unittest.main()
