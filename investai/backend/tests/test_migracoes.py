import os
import sqlite3
import tempfile
import unittest

from sqlalchemy import inspect

from app import criar_app
from models import db
from models.migracoes import acrescentar_colunas_faltantes


class TesteColunasAcrescentadas(unittest.TestCase):
    """Banco criado antes de uma coluna nova existir: o backend precisa
    subir mesmo assim, acrescentando a coluna sem perder os dados."""

    def setUp(self):
        self.pasta = tempfile.TemporaryDirectory()
        self.caminho = os.path.join(self.pasta.name, "antigo.db")
        # Tabela como ela era antes de ganhar a coluna movimentacao_id.
        conexao = sqlite3.connect(self.caminho)
        conexao.execute(
            "CREATE TABLE transacao_importada (id INTEGER PRIMARY KEY, identificador VARCHAR(200) "
            "NOT NULL, usuario_id INTEGER NOT NULL, data_criacao DATETIME NOT NULL, "
            "data_atualizacao DATETIME NOT NULL)"
        )
        conexao.execute(
            "INSERT INTO transacao_importada VALUES (1, 'banco:conta:1', 7, '2026-10-01', '2026-10-01')"
        )
        conexao.commit()
        conexao.close()

    def tearDown(self):
        self.pasta.cleanup()

    def test_backend_sobe_num_banco_antigo_e_acrescenta_a_coluna(self):
        app = criar_app({
            "SQLALCHEMY_DATABASE_URI": "sqlite:///" + self.caminho.replace("\\", "/"),
            "AQUECER_CACHE_MERCADO": False,
        })
        with app.app_context():
            colunas = {c["name"] for c in inspect(db.engine).get_columns("transacao_importada")}
            self.assertIn("movimentacao_id", colunas)

            # Os dados antigos continuam lá, com a coluna nova vazia.
            linha = db.session.execute(
                db.text("SELECT identificador, movimentacao_id FROM transacao_importada")
            ).one()
            self.assertEqual(tuple(linha), ("banco:conta:1", None))

            # Rodar de novo não faz nada.
            self.assertEqual(acrescentar_colunas_faltantes(db), [])
            db.session.remove()
            db.engine.dispose()


if __name__ == "__main__":
    unittest.main()
