{{flutter_js}}
{{flutter_build_config}}

// Sem service worker: com ele, o navegador continuava abrindo uma cópia
// antiga do app mesmo depois de uma versão nova ser publicada.
_flutter.loader.load();
