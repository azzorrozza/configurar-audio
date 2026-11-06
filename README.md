Configuração de áudio — LMDE 7
Fone e microfone P2 com EasyEffects

Este procedimento configura automaticamente o áudio do LMDE 7 para utilizar o fone de ouvido P2 e o microfone do headset conectado à entrada P2.

O objetivo é evitar a utilização acidental do áudio HDMI, dos alto-falantes internos e do microfone interno durante chamadas, reuniões e videoconferências.

A configuração foi preparada para reutilização após reinstalação do LMDE 7 na mesma máquina.

1. Hardware identificado

Configuração baseada no hardware desta máquina:

Componente	Identificação
Sistema operacional	LMDE 7
Servidor de áudio	PipeWire 1.4.2
Compatibilidade	PulseAudio via PipeWire
Placa HDMI	AMD/ATI — 03_00.1
Placa analógica	AMD Ryzen HD Audio — 03_00.6
Codec de áudio	Realtek ALC256
Saída desejada	Fone de ouvido P2
Entrada desejada	Microfone do headset P2
Processamento	EasyEffects
Identificadores das placas
text
alsa_card.pci-0000_03_00.1
alsa_card.pci-0000_03_00.6

Portas utilizadas
Dispositivo	Identificador
Microfone interno	analog-input-internal-mic
Microfone P2	analog-input-headset-mic
Alto-falantes internos	analog-output-speaker
Fone P2	analog-output-headphones
2. Objetivo da configuração
Dispositivo	Estado desejado
Áudio HDMI	Desativado
Alto-falantes internos	Não utilizados
Microfone interno	Não utilizado
Fone P2	Selecionado
Microfone P2	Selecionado
EasyEffects Sink	Saída padrão
EasyEffects Source	Entrada padrão

Importante: selecionar o microfone P2 não desativa fisicamente o microfone interno. O procedimento configura o headset como entrada padrão, mas aplicativos podem substituir essa seleção manualmente.

3. Criar os diretórios

Após reinstalar o LMDE 7, abrir o terminal e executar:

bash
mkdir -p ~/.local/bin
mkdir -p ~/.config/autostart
mkdir -p ~/Documentos

4. Verificar o servidor de áudio

Executar:

bash
pactl info


O servidor deverá apresentar algo semelhante a:

text
Server Name: PulseAudio (on PipeWire 1.4.2)


Conferir as placas:

bash
pactl list short cards


Resultado esperado:

text
alsa_card.pci-0000_03_00.1
alsa_card.pci-0000_03_00.6


Conferir também os dispositivos:

bash
pactl list short sinks
pactl list short sources


Importante: este procedimento utiliza os identificadores de hardware desta máquina. Se forem diferentes após a reinstalação, revisar o script antes de executá-lo.

5. Criar o script de configuração

Abrir:

bash
nano ~/.local/bin/configurar-audio.sh


Inserir o conteúdo completo:

bash
#!/bin/bash

# ==========================================
# CONFIGURAÇÃO DE ÁUDIO - LMDE 7
# PipeWire + PulseAudio + EasyEffects
# ==========================================

set -Eeuo pipefail

# ==========================================
# IDENTIFICADORES DE HARDWARE
# ==========================================

HDMI_CARD="alsa_card.pci-0000_03_00.1"

ANALOG_CARD="alsa_card.pci-0000_03_00.6"

ANALOG_SINK="alsa_output.pci-0000_03_00.6.analog-stereo"

ANALOG_SOURCE="alsa_input.pci-0000_03_00.6.analog-stereo"

HEADPHONE_PORT="analog-output-headphones"

HEADSET_MIC_PORT="analog-input-headset-mic"

# ==========================================
# CONFIGURAÇÃO DE LOG
# ==========================================

LOG_FILE="$HOME/Documentos/configurar-audio.log"

ERROR_LOG="$HOME/configurar-audio-erro.log"

mkdir -p "$HOME/Documentos"

: > "$LOG_FILE"

rm -f "$ERROR_LOG"

exec >> "$LOG_FILE" 2>&1

# ==========================================
# FUNÇÕES
# ==========================================

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*"
}

finalizar() {

    STATUS=$?

    trap - EXIT

    if [ "$STATUS" -ne 0 ]; then

        log "=========================================="
        log "CONFIGURAÇÃO FINALIZADA COM ERROS."
        log "Código de saída: $STATUS"

        cp "$LOG_FILE" "$ERROR_LOG"

        if command -v notify-send >/dev/null 2>&1; then

            notify-send "Configuração de áudio" \
                "Falha na configuração. Consulte o log de erros."

        fi

    else

        log "=========================================="
        log "CONFIGURAÇÃO CONCLUÍDA COM SUCESSO."

        rm -f "$ERROR_LOG"

    fi
}

trap finalizar EXIT

trap '
    STATUS=$?
    log "ERRO: comando falhou na linha $LINENO (código $STATUS)"
    exit "$STATUS"
' ERR

# ==========================================
# INÍCIO
# ==========================================

log "=========================================="
log "INICIANDO CONFIGURAÇÃO DE ÁUDIO"
log "LMDE 7 - PipeWire - EasyEffects"

# ==========================================
# AGUARDAR INICIALIZAÇÃO DO SISTEMA
# ==========================================

sleep 5

log "Aguardando servidor de áudio..."

AUDIO_READY=false

for i in {1..15}; do

    if pactl info >/dev/null 2>&1; then

        AUDIO_READY=true
        break

    fi

    sleep 1

done

if [ "$AUDIO_READY" = false ]; then

    log "ERRO: servidor de áudio não disponível."
    exit 1

fi

log "Servidor de áudio disponível."

# ==========================================
# VERIFICAR PLACAS DE ÁUDIO
# ==========================================

log "Verificando placas de áudio..."

CARDS=$(pactl list short cards)

if ! grep -Fq "$HDMI_CARD" <<< "$CARDS"; then

    log "ERRO: placa HDMI não encontrada."
    exit 1

fi

if ! grep -Fq "$ANALOG_CARD" <<< "$CARDS"; then

    log "ERRO: placa analógica não encontrada."
    exit 1

fi

log "Placas de áudio identificadas."

# ==========================================
# DESABILITAR HDMI
# ==========================================

log "Desabilitando áudio HDMI..."

pactl set-card-profile "$HDMI_CARD" off

log "Perfil HDMI desativado."

# ==========================================
# ATIVAR ÁUDIO ANALÓGICO
# ==========================================

log "Ativando perfil analógico..."

pactl set-card-profile "$ANALOG_CARD" \
    output:analog-stereo+input:analog-stereo

log "Perfil analógico ativado."

# ==========================================
# SELECIONAR FONE P2
# ==========================================

log "Selecionando fone P2..."

pactl set-sink-port "$ANALOG_SINK" "$HEADPHONE_PORT"

log "Fone P2 selecionado."

# ==========================================
# SELECIONAR MICROFONE P2
# ==========================================

log "Selecionando microfone do headset..."

pactl set-source-port "$ANALOG_SOURCE" "$HEADSET_MIC_PORT"

log "Microfone P2 selecionado."

# ==========================================
# VALIDAR PORTAS FÍSICAS
# ==========================================

log "Validando portas selecionadas..."

SINK_PORT=$(pactl list sinks | awk \
    -v name="$ANALOG_SINK" '
    $1 == "Name:" {
        found = ($2 == name)
    }
    found && $1 == "Active" && $2 == "Port:" {
        print $3
        exit
    }
')

SOURCE_PORT=$(pactl list sources | awk \
    -v name="$ANALOG_SOURCE" '
    $1 == "Name:" {
        found = ($2 == name)
    }
    found && $1 == "Active" && $2 == "Port:" {
        print $3
        exit
    }
')

if [ -z "$SINK_PORT" ]; then

    log "ERRO: não foi possível identificar a porta de saída."
    exit 1

fi

if [ -z "$SOURCE_PORT" ]; then

    log "ERRO: não foi possível identificar a porta de entrada."
    exit 1

fi

log "Porta de saída: $SINK_PORT"

log "Porta de entrada: $SOURCE_PORT"

if [ "$SINK_PORT" != "$HEADPHONE_PORT" ]; then

    log "ERRO: fone P2 não está selecionado."
    exit 1

fi

if [ "$SOURCE_PORT" != "$HEADSET_MIC_PORT" ]; then

    log "ERRO: microfone P2 não está selecionado."
    exit 1

fi

log "Portas físicas validadas."

# ==========================================
# AGUARDAR EASY EFFECTS
# ==========================================

log "Aguardando dispositivos virtuais do EasyEffects..."

EASY_SINK=false

EASY_SOURCE=false

for i in {1..30}; do

    SINK_LIST=$(pactl list short sinks)

    SOURCE_LIST=$(pactl list short sources)

    if awk '$2 == "easyeffects_sink" { found=1 }
        END { exit !found }' <<< "$SINK_LIST"; then

        EASY_SINK=true

    fi

    if awk '$2 == "easyeffects_source" { found=1 }
        END { exit !found }' <<< "$SOURCE_LIST"; then

        EASY_SOURCE=true

    fi

    if [ "$EASY_SINK" = true ] && [ "$EASY_SOURCE" = true ]; then

        break

    fi

    sleep 1

done

# ==========================================
# VALIDAR EASY EFFECTS
# ==========================================

if [ "$EASY_SINK" = false ]; then

    log "ERRO: easyeffects_sink não encontrado."
    exit 1

fi

if [ "$EASY_SOURCE" = false ]; then

    log "ERRO: easyeffects_source não encontrado."
    exit 1

fi

log "Dispositivos virtuais EasyEffects encontrados."

# ==========================================
# DEFINIR DISPOSITIVOS PADRÃO
# ==========================================

log "Definindo saída padrão..."

pactl set-default-sink easyeffects_sink

log "Saída padrão definida: easyeffects_sink"

log "Definindo entrada padrão..."

pactl set-default-source easyeffects_source

log "Entrada padrão definida: easyeffects_source"

# ==========================================
# FINALIZAÇÃO
# ==========================================

log "=========================================="
log "CONFIGURAÇÃO DE ÁUDIO CONCLUÍDA."

exit 0


Salvar com CTRL + O, pressionar ENTER e sair com CTRL + X.

6. Dar permissão de execução

Executar:

bash
chmod +x ~/.local/bin/configurar-audio.sh

7. Configurar inicialização automática

Criar o arquivo:

bash
nano ~/.config/autostart/configurar-audio.desktop


Inserir:

ini
[Desktop Entry]
Type=Application
Name=Configurar áudio
Comment=Configuração automática de áudio e EasyEffects
Exec=/home/alexsandrorozza/.local/bin/configurar-audio.sh
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=10


Salvar e sair.

Dar permissão:

bash
chmod +x ~/.config/autostart/configurar-audio.desktop


Observação: o caminho do Exec utiliza o usuário alexsandrorozza. Se o nome do usuário mudar em outra instalação, atualizar esse caminho.

O atraso de inicialização é uma extensão do ambiente GNOME. O script possui suas próprias esperas e não depende exclusivamente desse parâmetro.

8. Configurar o EasyEffects

Abrir o EasyEffects e conferir as configurações internas.

Saída (Output)
Dispositivo físico de saída: áudio analógico Realtek.
Saída: fone de ouvido P2.
Manter os efeitos de processamento desejados.
Entrada (Input)
Dispositivo físico de entrada: microfone do headset P2.
Confirmar que o microfone interno não está sendo utilizado.
Manter os efeitos de processamento desejados.

Importante: o script define os dispositivos virtuais do EasyEffects como padrão, mas não configura automaticamente o roteamento interno do programa.

É necessário garantir que o EasyEffects esteja iniciado e configurado para utilizar os dispositivos físicos corretos.

Também é necessário habilitar sua inicialização automática, caso ainda não esteja configurada.

9. Testar manualmente

Antes de reiniciar, executar:

bash
~/.local/bin/configurar-audio.sh


Consultar o log:

bash
cat ~/Documentos/configurar-audio.log


Se houver erros:

bash
cat ~/configurar-audio-erro.log


O resultado esperado no final do log é:

text
CONFIGURAÇÃO DE ÁUDIO CONCLUÍDA.
CONFIGURAÇÃO CONCLUÍDA COM SUCESSO.

10. Conferir os dispositivos após a configuração
Servidor de áudio
bash
pactl info


Esperado:

text
Default Sink: easyeffects_sink
Default Source: easyeffects_source

Placas
bash
pactl list short cards

Saídas
bash
pactl list short sinks

Entradas
bash
pactl list short sources

Porta física de saída
bash
pactl list sinks


Localizar a saída:

text
Name: alsa_output.pci-0000_03_00.6.analog-stereo


Conferir:

text
Active Port: analog-output-headphones

Porta física de entrada
bash
pactl list sources


Localizar a entrada:

text
Name: alsa_input.pci-0000_03_00.6.analog-stereo


Conferir:

text
Active Port: analog-input-headset-mic

Perfil HDMI
bash
pactl list cards


Na placa HDMI, conferir:

text
Active Profile: off

11. Reiniciar e testar

Reiniciar o computador:

bash
sudo reboot


Depois de entrar no Cinnamon:

Aguardar a inicialização do PipeWire.
Aguardar o EasyEffects.
Conferir o log de configuração.
Testar a saída pelo fone P2.
Testar a captação pelo microfone do headset.
Fazer uma chamada de teste.
Conferir se os aplicativos estão utilizando os dispositivos virtuais do EasyEffects.

Nos aplicativos de chamada, selecionar explicitamente:

Configuração	Dispositivo
Microfone	EasyEffects Source
Alto-falante	EasyEffects Sink

Os nomes podem variar conforme a versão e o idioma dos aplicativos.

12. Localização dos arquivos

Após a instalação, a estrutura será:

text
/home/alexsandrorozza/
│
├── .local/
│   └── bin/
│       └── configurar-audio.sh
│
├── .config/
│   └── autostart/
│       └── configurar-audio.desktop
│
├── Documentos/
│   └── configurar-audio.log
│
└── configurar-audio-erro.log


O arquivo de erros será criado somente quando houver falha na execução.

13. Solução de problemas
EasyEffects não encontrado

Verificar:

bash
pactl list short sinks
pactl list short sources


Se os dispositivos virtuais não aparecerem, verificar se o EasyEffects está instalado e iniciado.

Fone P2 não selecionado

Executar:

bash
pactl set-sink-port \
alsa_output.pci-0000_03_00.6.analog-stereo \
analog-output-headphones

Microfone P2 não selecionado

Executar:

bash
pactl set-source-port \
alsa_input.pci-0000_03_00.6.analog-stereo \
analog-input-headset-mic

HDMI voltou a ficar ativo

Executar:

bash
pactl set-card-profile \
alsa_card.pci-0000_03_00.1 off

Consultar os logs
bash
cat ~/Documentos/configurar-audio.log

bash
cat ~/configurar-audio-erro.log

14. Resultado esperado

Ao concluir o procedimento:

Dispositivo	Estado
HDMI	Desativado
Alto-falantes internos	Não utilizados
Microfone interno	Não utilizado
Fone P2	Saída selecionada
Microfone P2	Entrada selecionada
EasyEffects Sink	Saída padrão
EasyEffects Source	Entrada padrão

Observação final: o procedimento configura o roteamento padrão de áudio no LMDE 7. Aplicativos podem manter dispositivos próprios ou substituir a seleção padrão. Por isso, é importante conferir a entrada e a saída nas configurações dos programas de chamada.

Objetivo final: manter o headset P2 como padrão, evitando confusão entre o áudio HDMI, os alto-falantes internos e o microfone interno durante chamadas e videoconferências.

Sistema documentado: LMDE 7
Servidor de áudio: PipeWire 1.4.2
Codec: Realtek ALC256
Processamento: EasyEffects
Configuração: Fone e microfone P2
