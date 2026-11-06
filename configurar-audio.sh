#!/usr/bin/env bash
# Configura somente o áudio físico P2 no LMDE 7.
# O EasyEffects é iniciado separadamente pelo Cinnamon.
# Pode ser executado novamente: as mesmas configurações serão reaplicadas.

set -Eeuo pipefail

readonly EXPECTED_USER="alexsandrorozza"

# Identificadores registrados nesta máquina.
readonly HDMI_CARD="alsa_card.pci-0000_03_00.1"
readonly ANALOG_CARD="alsa_card.pci-0000_03_00.6"
readonly ANALOG_PROFILE="output:analog-stereo+input:analog-stereo"
readonly ANALOG_SINK="alsa_output.pci-0000_03_00.6.analog-stereo"
readonly ANALOG_SOURCE="alsa_input.pci-0000_03_00.6.analog-stereo"
readonly HEADPHONE_PORT="analog-output-headphones"
readonly HEADSET_MIC_PORT="analog-input-headset-mic"

readonly LOG_DIR="$HOME/Documentos"
readonly LOG_FILE="$LOG_DIR/configurar-audio.log"
readonly ERROR_LOG="$HOME/configurar-audio-erro.log"

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
        log "CONFIGURAÇÃO FÍSICA DE ÁUDIO CONCLUÍDA; VALIDAÇÕES AUTOMÁTICAS APROVADAS."
        rm -f "$ERROR_LOG"
    else
        log "CONFIGURAÇÃO INTERROMPIDA COM ERRO. Código de saída: $status"
        log "Consulte o log principal: $LOG_FILE"
        cp "$LOG_FILE" "$ERROR_LOG"
        log "Cópia do log de erro: $ERROR_LOG"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Configuração de áudio" \
                "Falha na configuração. Consulte ~/Documentos/configurar-audio.log" || true
        fi
    fi
}
trap finish EXIT
trap 'status=$?; log "ERRO na linha $LINENO (código $status)."; exit "$status"' ERR

fail() {
    log "FALHA: $*"
    exit 1
}

has_exact_name() {
    local list_text="$1"
    local expected="$2"
    awk -v expected="$expected" '$2 == expected { found=1 } END { exit !found }' <<< "$list_text"
}

wait_for_audio_object() {
    local object_type="$1"
    local expected="$2"
    local attempt

    for attempt in {1..30}; do
        if "$PACTL_BIN" list short "$object_type" 2>/dev/null | \
            awk -v expected="$expected" '$2 == expected { found=1 } END { exit !found }'; then
            return 0
        fi
        sleep 1
    done

    return 1
}

get_active_port() {
    local object_type="$1"
    local expected="$2"

    "$PACTL_BIN" list "$object_type" | awk -v expected="$expected" '
        /^(Sink|Source) #[0-9]+/ { in_target=0 }
        /^[[:space:]]*Name: / {
            if ($2 == expected) in_target=1
        }
        in_target && /^[[:space:]]*Active Port: / {
            sub(/^[[:space:]]*Active Port: /, "")
            print
            exit
        }
    '
}

get_card_profile() {
    local expected="$1"

    "$PACTL_BIN" list cards | awk -v expected="$expected" '
        /^Card #[0-9]+/ { in_card=0 }
        /^[[:space:]]*Name: / {
            if ($2 == expected) in_card=1
        }
        in_card && /^[[:space:]]*Active Profile: / {
            sub(/^[[:space:]]*Active Profile: /, "")
            print
            exit
        }
    '
}

log "============================================================"
log "INÍCIO DA CONFIGURAÇÃO FÍSICA DE ÁUDIO - LMDE 7"
log "Usuário: $(id -un)"
log "============================================================"

[[ "$(id -un)" == "$EXPECTED_USER" ]] || fail "usuário atual diferente de '$EXPECTED_USER'."

for required_command in pactl awk grep tee; do
    command -v "$required_command" >/dev/null 2>&1 || fail "comando obrigatório não encontrado: $required_command"
done

PACTL_BIN="$(command -v pactl)"

log "Aguardando o servidor de áudio (até 30 segundos)."
AUDIO_READY=false
for attempt in {1..30}; do
    if "$PACTL_BIN" info >/dev/null 2>&1; then
        AUDIO_READY=true
        break
    fi
    sleep 1
done
[[ "$AUDIO_READY" == true ]] || fail "servidor de áudio indisponível; pactl info não respondeu."

SERVER_INFO="$("$PACTL_BIN" info)"
SERVER_NAME="$(awk -F': ' '$1 == "Server Name" { print $2; exit }' <<< "$SERVER_INFO")"
log "Servidor informado por pactl: ${SERVER_NAME:-não identificado}"
grep -qi 'PipeWire' <<< "$SERVER_NAME" || fail "o servidor informado por pactl não parece ser PipeWire. Nenhuma configuração foi aplicada."

log "Verificando as placas de áudio esperadas."
CARDS="$("$PACTL_BIN" list short cards)"
has_exact_name "$CARDS" "$HDMI_CARD" || fail "placa HDMI não encontrada: $HDMI_CARD"
has_exact_name "$CARDS" "$ANALOG_CARD" || fail "placa analógica não encontrada: $ANALOG_CARD"
log "As duas placas esperadas foram encontradas."

log "Desativando o perfil da placa HDMI."
"$PACTL_BIN" set-card-profile "$HDMI_CARD" off

log "Ativando o perfil analógico duplex."
"$PACTL_BIN" set-card-profile "$ANALOG_CARD" "$ANALOG_PROFILE"

log "Aguardando a criação da saída e da entrada analógicas."
wait_for_audio_object sinks "$ANALOG_SINK" || fail "saída analógica não apareceu: $ANALOG_SINK"
wait_for_audio_object sources "$ANALOG_SOURCE" || fail "entrada analógica não apareceu: $ANALOG_SOURCE"

log "Selecionando a porta física do fone P2."
"$PACTL_BIN" set-sink-port "$ANALOG_SINK" "$HEADPHONE_PORT"
log "Selecionando a porta física do microfone P2."
"$PACTL_BIN" set-source-port "$ANALOG_SOURCE" "$HEADSET_MIC_PORT"

SINK_PORT="$(get_active_port sinks "$ANALOG_SINK")"
SOURCE_PORT="$(get_active_port sources "$ANALOG_SOURCE")"
log "Porta ativa de saída: ${SINK_PORT:-não identificada}"
log "Porta ativa de entrada: ${SOURCE_PORT:-não identificada}"
[[ "$SINK_PORT" == "$HEADPHONE_PORT" ]] || fail "a porta ativa de saída não é '$HEADPHONE_PORT'."
[[ "$SOURCE_PORT" == "$HEADSET_MIC_PORT" ]] || fail "a porta ativa de entrada não é '$HEADSET_MIC_PORT'."

HDMI_PROFILE="$(get_card_profile "$HDMI_CARD")"
ANALOG_ACTIVE_PROFILE="$(get_card_profile "$ANALOG_CARD")"
log "Perfil HDMI ativo: ${HDMI_PROFILE:-não identificado}"
log "Perfil analógico ativo: ${ANALOG_ACTIVE_PROFILE:-não identificado}"
[[ "$HDMI_PROFILE" == "off" ]] || fail "o perfil HDMI não ficou desativado."
[[ "$ANALOG_ACTIVE_PROFILE" == "$ANALOG_PROFILE" ]] || fail "o perfil analógico ativo não corresponde ao perfil solicitado."

log "Definindo os dispositivos físicos como padrão do sistema."
"$PACTL_BIN" set-default-sink "$ANALOG_SINK"
"$PACTL_BIN" set-default-source "$ANALOG_SOURCE"

CURRENT_INFO="$("$PACTL_BIN" info)"
DEFAULT_SINK="$(awk -F': ' '$1 == "Default Sink" { print $2; exit }' <<< "$CURRENT_INFO")"
DEFAULT_SOURCE="$(awk -F': ' '$1 == "Default Source" { print $2; exit }' <<< "$CURRENT_INFO")"
log "Saída padrão: ${DEFAULT_SINK:-não identificada}"
log "Entrada padrão: ${DEFAULT_SOURCE:-não identificada}"
[[ "$DEFAULT_SINK" == "$ANALOG_SINK" ]] || fail "a saída padrão não permaneceu na placa analógica."
[[ "$DEFAULT_SOURCE" == "$ANALOG_SOURCE" ]] || fail "a entrada padrão não permaneceu na placa analógica."

log "EasyEffects não é iniciado por este script."
log "A inicialização do EasyEffects é feita por uma segunda entrada do Cinnamon, separadamente."
log "============================================================"
log "VALIDAÇÕES AUTOMÁTICAS DA CONFIGURAÇÃO FÍSICA CONCLUÍDAS."
log "Saída padrão do sistema: $ANALOG_SINK"
log "Entrada padrão do sistema: $ANALOG_SOURCE"
log "Porta física de saída: $HEADPHONE_PORT"
log "Porta física de entrada: $HEADSET_MIC_PORT"
log "HDMI: perfil off"
log "Log: $LOG_FILE"
log "A validação física do som e do microfone ainda deve ser feita pelo usuário."
log "============================================================"
