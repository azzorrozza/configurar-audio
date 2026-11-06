#!/usr/bin/env bash
# Instala Flatpak (se necessário) e EasyEffects estável pelo Flathub.
# Em uma instalação nova, prefere o escopo do sistema. Se o aplicativo já
# estiver instalado para o usuário, preserva essa instalação sem duplicá-la.

set -Eeuo pipefail

readonly EXPECTED_USER="alexsandrorozza"
readonly APP_ID="com.github.wwmm.easyeffects"
readonly APP_REF="$APP_ID//stable"
readonly APP_ARCH="x86_64"
readonly FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
readonly LOG_DIR="$HOME/Documentos"
readonly LOG_FILE="$LOG_DIR/instalar-easyeffects-flatpak.log"
readonly ERROR_LOG="$HOME/instalar-easyeffects-flatpak-erro.log"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"
rm -f "$ERROR_LOG"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '[%s] %s\n' "$(date '+%d/%m/%Y %H:%M:%S')" "$*"
}

finish() {
    local status=$?
    trap - EXIT

    if (( status == 0 )); then
        log "INSTALAÇÃO/VALIDAÇÃO DO EASYEFFECTS CONCLUÍDA."
        rm -f "$ERROR_LOG"
    else
        log "FALHA NA INSTALAÇÃO. Código de saída: $status"
        log "Consulte o log principal: $LOG_FILE"
        cp "$LOG_FILE" "$ERROR_LOG"
        log "Cópia do log de erro: $ERROR_LOG"
    fi
}
trap finish EXIT
trap 'status=$?; log "ERRO na linha $LINENO (código $status)."; exit "$status"' ERR

fail() {
    log "FALHA: $*"
    exit 1
}

log "Iniciando instalação/validação do EasyEffects via Flatpak/Flathub."

CURRENT_USER="$(id -un)"
[[ "$CURRENT_USER" == "$EXPECTED_USER" ]] || fail "usuário atual '$CURRENT_USER'; esperado '$EXPECTED_USER'."

command -v apt-get >/dev/null 2>&1 || fail "apt-get não foi encontrado. Este procedimento foi preparado para LMDE 7."
command -v sudo >/dev/null 2>&1 || fail "sudo não foi encontrado."

if ! command -v flatpak >/dev/null 2>&1; then
    log "Flatpak não encontrado. Instalando somente o suporte Flatpak pelo APT."
    sudo apt-get update
    sudo apt-get install -y flatpak
else
    log "Flatpak já está instalado."
fi

[[ -x /usr/bin/flatpak ]] || fail "o executável /usr/bin/flatpak não foi encontrado; esse é o caminho definido na entrada de inicialização do Cinnamon."
FLATPAK_BIN="/usr/bin/flatpak"
log "Executável Flatpak: $FLATPAK_BIN"

APP_SCOPE=""
HAS_SYSTEM=false
HAS_USER=false
"$FLATPAK_BIN" info --system "$APP_ID" >/dev/null 2>&1 && HAS_SYSTEM=true
"$FLATPAK_BIN" info --user "$APP_ID" >/dev/null 2>&1 && HAS_USER=true

if [[ "$HAS_SYSTEM" == true && "$HAS_USER" == true ]]; then
    fail "há duas instalações do EasyEffects (sistema e usuário). Remova uma delas para evitar ambiguidade no comando de inicialização e execute novamente."
elif [[ "$HAS_SYSTEM" == true ]]; then
    APP_SCOPE="system"
    log "EasyEffects já está instalado no escopo do sistema."
elif [[ "$HAS_USER" == true ]]; then
    APP_SCOPE="user"
    log "EasyEffects já está instalado no escopo do usuário; a instalação existente será preservada."
else
    log "EasyEffects não encontrado. Preparando Flathub no escopo do sistema."
    sudo "$FLATPAK_BIN" remote-add --system --if-not-exists flathub "$FLATHUB_URL"

    log "Instalando $APP_REF para arquitetura $APP_ARCH no escopo do sistema."
    sudo "$FLATPAK_BIN" install --system --noninteractive --arch="$APP_ARCH" flathub "$APP_REF"

    "$FLATPAK_BIN" info --system "$APP_ID" >/dev/null || fail "a instalação do EasyEffects no escopo do sistema não foi confirmada."
    APP_SCOPE="system"
fi

case "$APP_SCOPE" in
    system)
        "$FLATPAK_BIN" info --system "$APP_ID" >/dev/null || fail "EasyEffects não passou na validação do escopo do sistema."
        ;;
    user)
        "$FLATPAK_BIN" info --user "$APP_ID" >/dev/null || fail "EasyEffects não passou na validação do escopo do usuário."
        ;;
esac

log "Aplicativo validado: $APP_ID"
log "Escopo detectado: $APP_SCOPE"
log "Comando de inicialização utilizado pelo Cinnamon:"
log "/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=easyeffects $APP_ID --hide-window --service-mode"
log "Log: $LOG_FILE"
