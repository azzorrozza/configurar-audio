#!/usr/bin/env bash
# Diagnóstico somente de leitura. Não altera placas, portas, volumes ou padrões.

set -Eeuo pipefail

readonly EXPECTED_USER="alexsandrorozza"
readonly APP_ID="com.github.wwmm.easyeffects"
readonly HDMI_CARD="alsa_card.pci-0000_03_00.1"
readonly ANALOG_CARD="alsa_card.pci-0000_03_00.6"
readonly ANALOG_PROFILE="output:analog-stereo+input:analog-stereo"
readonly ANALOG_SINK="alsa_output.pci-0000_03_00.6.analog-stereo"
readonly ANALOG_SOURCE="alsa_input.pci-0000_03_00.6.analog-stereo"
readonly HEADPHONE_PORT="analog-output-headphones"
readonly HEADSET_MIC_PORT="analog-input-headset-mic"
readonly EE_SINK="easyeffects_sink"
readonly EE_SOURCE="easyeffects_source"
readonly LOG_DIR="$HOME/Documentos"
readonly LOG_FILE="$LOG_DIR/diagnosticar-audio.log"
readonly ERROR_LOG="$HOME/diagnosticar-audio-erro.log"
readonly AUDIO_AUTOSTART="$HOME/.config/autostart/configurar-audio.desktop"
readonly EE_AUTOSTART="$HOME/.config/autostart/easyeffects.desktop"
readonly EE_EXEC='/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=easyeffects com.github.wwmm.easyeffects --hide-window --service-mode'

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"
rm -f "$ERROR_LOG"
exec > >(tee -a "$LOG_FILE") 2>&1

FAILURES=0

ok()   { printf '[OK]     %s\n' "$*"; }
fail() { printf '[FALHA]  %s\n' "$*"; FAILURES=$((FAILURES + 1)); }
info() { printf '[INFO]   %s\n' "$*"; }

has_exact_name() {
    local list_text="$1" expected="$2"
    awk -v expected="$expected" '$2 == expected { found=1 } END { exit !found }' <<< "$list_text"
}

get_active_port() {
    local object_type="$1" expected="$2"
    "$PACTL_BIN" list "$object_type" 2>/dev/null | awk -v expected="$expected" '
        /^(Sink|Source) #[0-9]+/ { in_target=0 }
        /^[[:space:]]*Name: / { if ($2 == expected) in_target=1 }
        in_target && /^[[:space:]]*Active Port: / {
            sub(/^[[:space:]]*Active Port: /, "")
            print
            exit
        }
    '
}

get_card_profile() {
    local expected="$1"
    "$PACTL_BIN" list cards 2>/dev/null | awk -v expected="$expected" '
        /^Card #[0-9]+/ { in_card=0 }
        /^[[:space:]]*Name: / { if ($2 == expected) in_card=1 }
        in_card && /^[[:space:]]*Active Profile: / {
            sub(/^[[:space:]]*Active Profile: /, "")
            print
            exit
        }
    '
}

printf '============================================================\n'
printf 'DIAGNÓSTICO DE ÁUDIO - LMDE 7\n'
printf 'Data: %s\n' "$(date '+%d/%m/%Y %H:%M:%S')"
printf 'Usuário: %s\n' "$(id -un)"
printf '============================================================\n'

if [[ "$(id -un)" == "$EXPECTED_USER" ]]; then
    ok "usuário correto: $EXPECTED_USER"
else
    fail "usuário atual diferente de '$EXPECTED_USER'."
fi

for required_command in pactl flatpak awk grep; do
    if command -v "$required_command" >/dev/null 2>&1; then
        ok "comando disponível: $required_command"
    else
        fail "comando ausente: $required_command"
    fi
done

if command -v pactl >/dev/null 2>&1; then
    PACTL_BIN="$(command -v pactl)"

    if SERVER_INFO="$("$PACTL_BIN" info 2>&1)"; then
        SERVER_NAME="$(awk -F': ' '$1 == "Server Name" { print $2; exit }' <<< "$SERVER_INFO")"
        if grep -qi PipeWire <<< "$SERVER_NAME"; then
            ok "servidor PipeWire: $SERVER_NAME"
        else
            fail "servidor não identificado como PipeWire: ${SERVER_NAME:-sem nome}"
        fi

        DEFAULT_SINK="$(awk -F': ' '$1 == "Default Sink" { print $2; exit }' <<< "$SERVER_INFO")"
        DEFAULT_SOURCE="$(awk -F': ' '$1 == "Default Source" { print $2; exit }' <<< "$SERVER_INFO")"
        [[ "$DEFAULT_SINK" == "$ANALOG_SINK" ]] && ok "saída padrão física correta" || fail "saída padrão incorreta: ${DEFAULT_SINK:-não identificada}"
        [[ "$DEFAULT_SOURCE" == "$ANALOG_SOURCE" ]] && ok "entrada padrão física correta" || fail "entrada padrão incorreta: ${DEFAULT_SOURCE:-não identificada}"
    else
        fail "pactl info falhou: $SERVER_INFO"
    fi

    if CARDS="$("$PACTL_BIN" list short cards 2>&1)"; then
        has_exact_name "$CARDS" "$HDMI_CARD" && ok "placa HDMI encontrada" || fail "placa HDMI ausente: $HDMI_CARD"
        has_exact_name "$CARDS" "$ANALOG_CARD" && ok "placa analógica encontrada" || fail "placa analógica ausente: $ANALOG_CARD"

        HDMI_PROFILE="$(get_card_profile "$HDMI_CARD")"
        ANALOG_ACTIVE_PROFILE="$(get_card_profile "$ANALOG_CARD")"
        [[ "$HDMI_PROFILE" == "off" ]] && ok "perfil HDMI desativado" || fail "perfil HDMI atual: ${HDMI_PROFILE:-não identificado}"
        [[ "$ANALOG_ACTIVE_PROFILE" == "$ANALOG_PROFILE" ]] && ok "perfil analógico duplex ativo" || fail "perfil analógico atual: ${ANALOG_ACTIVE_PROFILE:-não identificado}"
    else
        fail "não foi possível listar as placas: $CARDS"
    fi

    if SINKS="$("$PACTL_BIN" list short sinks 2>&1)"; then
        has_exact_name "$SINKS" "$ANALOG_SINK" && ok "saída analógica presente" || fail "saída analógica ausente"
        SINK_PORT="$(get_active_port sinks "$ANALOG_SINK")"
        [[ "$SINK_PORT" == "$HEADPHONE_PORT" ]] && ok "porta do fone P2 ativa" || fail "porta de saída ativa: ${SINK_PORT:-não identificada}"
        has_exact_name "$SINKS" "$EE_SINK" && ok "EasyEffects Sink presente" || fail "EasyEffects Sink não encontrado"
    else
        fail "não foi possível listar as saídas: $SINKS"
    fi

    if SOURCES="$("$PACTL_BIN" list short sources 2>&1)"; then
        has_exact_name "$SOURCES" "$ANALOG_SOURCE" && ok "entrada analógica presente" || fail "entrada analógica ausente"
        SOURCE_PORT="$(get_active_port sources "$ANALOG_SOURCE")"
        [[ "$SOURCE_PORT" == "$HEADSET_MIC_PORT" ]] && ok "porta do microfone P2 ativa" || fail "porta de entrada ativa: ${SOURCE_PORT:-não identificada}"
        has_exact_name "$SOURCES" "$EE_SOURCE" && ok "EasyEffects Source presente" || fail "EasyEffects Source não encontrado"
    else
        fail "não foi possível listar as entradas: $SOURCES"
    fi
fi

if command -v flatpak >/dev/null 2>&1; then
    FLATPAK_BIN="$(command -v flatpak)"
    HAS_SYSTEM=false
    HAS_USER=false
    "$FLATPAK_BIN" info --system "$APP_ID" >/dev/null 2>&1 && HAS_SYSTEM=true
    "$FLATPAK_BIN" info --user "$APP_ID" >/dev/null 2>&1 && HAS_USER=true

    if [[ "$HAS_SYSTEM" == true && "$HAS_USER" == true ]]; then
        fail "EasyEffects está duplicado nas instalações Flatpak do sistema e do usuário"
    elif [[ "$HAS_SYSTEM" == true ]]; then
        ok "EasyEffects instalado via Flatpak (sistema)"
    elif [[ "$HAS_USER" == true ]]; then
        ok "EasyEffects instalado via Flatpak (usuário)"
    else
        fail "EasyEffects não encontrado nas instalações Flatpak do sistema ou usuário"
    fi

    if FLATPAK_RUNNING="$("$FLATPAK_BIN" ps --columns=application:full 2>&1)"; then
        if grep -Fxq "$APP_ID" <<< "$FLATPAK_RUNNING"; then
            ok "processo Flatpak do EasyEffects em execução"
        else
            fail "EasyEffects instalado, mas não aparece como processo Flatpak em execução"
        fi
    else
        fail "não foi possível consultar os processos Flatpak: $FLATPAK_RUNNING"
    fi
fi

if [[ -f "$AUDIO_AUTOSTART" ]] && grep -Fxq 'Exec=/home/alexsandrorozza/.local/bin/configurar-audio.sh' "$AUDIO_AUTOSTART"; then
    ok "entrada Cinnamon para configurar-audio.sh instalada"
else
    fail "entrada Cinnamon do script de configuração ausente ou com Exec diferente: $AUDIO_AUTOSTART"
fi

if [[ -f "$EE_AUTOSTART" ]] && grep -Fxq "Exec=$EE_EXEC" "$EE_AUTOSTART"; then
    ok "entrada Cinnamon do EasyEffects contém o comando aprovado"
else
    fail "entrada Cinnamon do EasyEffects ausente ou com comando diferente: $EE_AUTOSTART"
fi

if [[ -e "$HOME/.config/systemd/user/easyeffects.service" ]]; then
    fail "foi encontrado um serviço antigo easyeffects.service; remova-o conforme a seção de migração do README"
else
    ok "nenhum serviço systemd antigo do EasyEffects encontrado"
fi

printf '%s\n' '------------------------------------------------------------'
if (( FAILURES == 0 )); then
    ok "todas as verificações automáticas passaram."
    info "Ainda é necessário testar fisicamente a reprodução e a captação do microfone."
    rm -f "$ERROR_LOG"
else
    fail "total de verificações com falha: $FAILURES"
    info "Cópia do diagnóstico: $ERROR_LOG"
    cp "$LOG_FILE" "$ERROR_LOG"
    exit 1
fi
info "Log completo: $LOG_FILE"
