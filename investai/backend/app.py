import os
import threading
import time

from flask import Flask, jsonify
from flask_cors import CORS

from models import db
from models.migracoes import acrescentar_colunas_faltantes
from controllers import (
    usuario_bp,
    movimentacao_bp,
    investimento_bp,
    meta_bp,
    limite_bp,
    orientacao_bp,
    mercado_bp,
    ia_bp,
    recorrencia_bp,
    importacao_bp,
)
from services.mercado.buscar_cotacao_dolar_service import BuscarCotacaoDolarService
from services.mercado.buscar_taxas_mercado_service import BuscarTaxasMercadoService
from services.mercado.buscar_titulos_tesouro_service import BuscarTitulosTesouroService

MINUTOS_ENTRE_ATUALIZACOES_MERCADO = 50


def _aquecer_cache_mercado():
    """Busca os dados de mercado (dólar, taxas, Tesouro Direto) uma vez e
    depois periodicamente, em segundo plano. O arquivo do Tesouro Direto é
    grande e o servidor de origem é lento (dezenas de segundos) - sem isso,
    o primeiro usuário a abrir a aba Investir pagaria essa espera."""

    def loop():
        while True:
            for service in (
                BuscarCotacaoDolarService,
                BuscarTaxasMercadoService,
                BuscarTitulosTesouroService,
            ):
                try:
                    service().executar()
                except Exception:
                    pass  # Tenta de novo no próximo ciclo; API externa pode estar fora do ar.
            time.sleep(MINUTOS_ENTRE_ATUALIZACOES_MERCADO * 60)

    threading.Thread(target=loop, daemon=True).start()


def criar_app(config=None):
    """`config` sobrescreve a configuração padrão - usado pelos testes, que
    rodam com banco em memória e sem aquecer o cache de mercado (para não
    depender de internet nem da API do Banco Central)."""
    app = Flask(__name__)
    app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///investai.db"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    # Em produção, defina a variável de ambiente SECRET_KEY com um valor
    # forte e secreto. Esta é usada para assinar os tokens JWT (RF02).
    app.config["SECRET_KEY"] = os.environ.get(
        "SECRET_KEY", "chave-de-desenvolvimento-troque-em-producao"
    )
    if config:
        app.config.update(config)

    db.init_app(app)
    CORS(app)

    app.register_blueprint(usuario_bp)
    app.register_blueprint(movimentacao_bp)
    app.register_blueprint(investimento_bp)
    app.register_blueprint(meta_bp)
    app.register_blueprint(limite_bp)
    app.register_blueprint(orientacao_bp)
    app.register_blueprint(mercado_bp)
    app.register_blueprint(ia_bp)
    app.register_blueprint(recorrencia_bp)
    app.register_blueprint(importacao_bp)

    with app.app_context():
        db.create_all()
        acrescentar_colunas_faltantes(db)

    # Evita rodar em duplicidade: o reloader do Flask (debug=True) sobe um
    # processo "monitor" e um processo "worker" - só o worker de fato serve
    # requisições, então só ele precisa aquecer o cache.
    if app.config.get("AQUECER_CACHE_MERCADO", True) and (
        not app.debug or os.environ.get("WERKZEUG_RUN_MAIN") == "true"
    ):
        _aquecer_cache_mercado()

    @app.route("/")
    def home():
        return jsonify({
            "app": "InvestAI API",
            "status": "online",
            "recursos": ["/api/usuarios", "/api/movimentacoes",
                         "/api/investimentos", "/api/metas",
                         "/api/limites", "/api/orientacao",
                         "/api/mercado", "/api/ia",
                         "/api/recorrencias", "/api/importacao"]
        })

    return app


if __name__ == "__main__":
    app = criar_app()
    # Por padrão só o próprio computador acessa a API. Para testar pelo
    # celular na mesma rede Wi-Fi, suba com INVESTAI_HOST=0.0.0.0.
    host = os.environ.get("INVESTAI_HOST", "127.0.0.1")
    # O modo debug abre um console que executa código Python pelo
    # navegador: fica restrito a quando só esta máquina alcança o servidor.
    app.run(host=host, debug=host in ("127.0.0.1", "localhost"))
