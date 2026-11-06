Configuração de áudio — LMDE 7
Fone e microfone P2 como únicos dispositivos de uso

Este procedimento configura automaticamente o áudio do LMDE 7 para utilizar o fone de ouvido P2 e o microfone do headset conectado à entrada P2.

O objetivo é evitar o uso acidental de outros dispositivos durante chamadas, reuniões e videoconferências.

1. Hardware identificado

Configuração baseada no hardware desta máquina:

Componente	Identificação
Sistema	LMDE 7
Servidor de áudio	PipeWire 1.4.2
Compatibilidade	PulseAudio via PipeWire
Placa HDMI	AMD/ATI — 03_00.1
Placa analógica	AMD Ryzen HD Audio — 03_00.6
Codec de áudio	Realtek ALC256
Saída desejada	Fone de ouvido P2
Entrada desejada	Microfone do headset P2
Processamento	EasyEffects

Identificadores de hardware:

text
alsa_card.pci-0000_03_00.1
alsa_card.pci-0000_03_00.6

2. Objetivo da configuração
Dispositivo	Configuração
Áudio HDMI	Desativado
Alto-falantes internos	Não utilizados
Microfone interno	Não utilizado
Fone P2	Selecionado
Microfone P2	Selecionado
EasyEffects	Entrada e saída padrão

Observação: a configuração seleciona as portas físicas desejadas e desativa o perfil HDMI. Ela não remove os drivers nem impede que um aplicativo altere manualmente o dispositivo selecionado.

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


Conferir também as placas:

bash
pactl list short cards


Saída esperada:

text
alsa_card.pci-0000_03_00.1
alsa_card.pci-0000_03_00.6


Importante: este procedimento foi preparado para a mesma máquina. Caso os identificadores sejam diferentes depois da reinstalação, revisar o script antes de executá-lo.

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

SINK_PORT=$(pactl get-sink-port "$ANALOG_SINK")

SOURCE_PORT=$(pactl get-source-port "$ANALOG_SOURCE")

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


Observação: o caminho do Exec utiliza o usuário atual desta máquina. Se o nome do usuário mudar em outra instalação, atualizar esse caminho.

O script também possui suas próprias esperas, portanto não depende exclusivamente do atraso configurado no arquivo .desktop.

8. Configurar o EasyEffects

O script configura os dispositivos virtuais do EasyEffects como dispositivos padrão, mas é necessário configurar o roteamento interno do programa.

Abrir o EasyEffects e verificar:

Saída (Output):

Dispositivo de saída: áudio analógico Realtek.
Saída física: fone P2.
Manter os efeitos de processamento desejados.

Entrada (Input):

Dispositivo de entrada: microfone do headset P2.
Confirmar que o microfone interno não está sendo utilizado.
Manter os efeitos de processamento desejados.

Importante: os dispositivos virtuais do EasyEffects não garantem, sozinhos, o roteamento correto. Essa configuração precisa ser conferida na interface do programa.

Também é necessário garantir que o EasyEffects seja iniciado automaticamente no ambiente gráfico.

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

10. Conferir os dispositivos após a configuração

Servidor de áudio:

bash
pactl info


Esperado:

text
Server Name: PulseAudio (on PipeWire 1.4.2)
Default Sink: easyeffects_sink
Default Source: easyeffects_source


Placas:

bash
pactl list short cards


Saídas:

bash
pactl list short sinks


Entradas:

bash
pactl list short sources


Porta física de saída:

bash
pactl get-sink-port \
alsa_output.pci-0000_03_00.6.analog-stereo


Esperado:

text
analog-output-headphones


Porta física de entrada:

bash
pactl get-source-port \
alsa_input.pci-0000_03_00.6.analog-stereo


Esperado:

text
analog-input-headset-mic


Perfil HDMI:

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

Microfone: EasyEffects Source.
Alto-falante: EasyEffects Sink.

Os nomes podem aparecer com pequenas variações conforme a versão e o idioma dos aplicativos.

12. Localização dos arquivos

Ao finalizar, a estrutura será:

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


O arquivo de erros só será mantido quando ocorrer uma falha na execução.

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

Ao concluir o procedimento, a configuração deverá permanecer:

Dispositivo	Estado esperado
HDMI	Desativado
Alto-falantes internos	Não utilizados
Microfone interno	Não utilizado
Fone P2	Saída selecionada
Microfone P2	Entrada selecionada
EasyEffects Sink	Saída padrão
EasyEffects Source	Entrada padrão

Observação final: este procedimento configura o roteamento padrão do áudio no LMDE 7. Aplicativos podem manter dispositivos próprios ou substituir a seleção padrão. Por isso, é importante conferir a entrada e a saída nas configurações dos programas de chamada.

Objetivo: manter o uso do headset P2 como padrão, evitando confusão entre o áudio HDMI, os alto-falantes internos e o microfone interno durante chamadas.
