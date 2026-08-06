// Configuração central da API do InvestAI.
// Ajuste aqui se o backend estiver em outro endereço ou porta.
const API_URL = "http://127.0.0.1:5000/api";

// Funções auxiliares para chamar as rotas CRUD da API.

async function apiListar(recurso) {
    const resp = await fetch(`${API_URL}/${recurso}`);
    return resp.json();
}

async function apiBuscar(recurso, id) {
    const resp = await fetch(`${API_URL}/${recurso}/${id}`);
    return resp.json();
}

async function apiCriar(recurso, dados) {
    const resp = await fetch(`${API_URL}/${recurso}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(dados),
    });
    return resp.json();
}

async function apiAtualizar(recurso, id, dados) {
    const resp = await fetch(`${API_URL}/${recurso}/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(dados),
    });
    return resp.json();
}

async function apiExcluir(recurso, id) {
    const resp = await fetch(`${API_URL}/${recurso}/${id}`, {
        method: "DELETE",
    });
    return resp.json();
}

// Lê o parâmetro "id" da URL (usado nas telas de edição).
function getIdDaUrl() {
    const params = new URLSearchParams(window.location.search);
    return params.get("id");
}

function formatarReal(valor) {
    return "R$ " + Number(valor).toFixed(2);
}
