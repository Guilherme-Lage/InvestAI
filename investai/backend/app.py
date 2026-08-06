from flask import Flask, jsonify
from flask_cors import CORS

from models import db
from controllers import usuario_bp, movimentacao_bp, investimento_bp, meta_bp


def criar_app():
    app = Flask(__name__)
    app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///investai.db"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

    db.init_app(app)
    CORS(app)

    app.register_blueprint(usuario_bp)
    app.register_blueprint(movimentacao_bp)
    app.register_blueprint(investimento_bp)
    app.register_blueprint(meta_bp)

    with app.app_context():
        db.create_all()

    @app.route("/")
    def home():
        return jsonify({
            "app": "InvestAI API",
            "status": "online",
            "recursos": ["/api/usuarios", "/api/movimentacoes",
                         "/api/investimentos", "/api/metas"]
        })

    return app


if __name__ == "__main__":
    app = criar_app()
    app.run(debug=True)
