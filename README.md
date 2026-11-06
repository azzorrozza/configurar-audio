# Configuração de áudio — LMDE 7

**Fone P2 e microfone do headset P2 como dispositivos físicos padrão, com processamento de áudio pelo EasyEffects instalado via Flatpak.**

Este repositório documenta a reinstalação e a configuração de áudio do notebook. O procedimento foi preparado para o mesmo hardware, para o LMDE 7, para o ambiente Cinnamon e para o usuário `alexsandrorozza`.

> **Estado dos testes:** os scripts são revisados e submetidos a testes controlados com comandos simulados. Esses testes verificam sintaxe, fluxo lógico, validações, logs e tratamento de falhas. Eles não substituem um teste físico no notebook. Som, microfone e processamento real só podem ser aprovados depois de reproduzir áudio, gravar pelo headset e reiniciar o computador.

## 1. Ambiente e hardware registrados

| Item | Identificação registrada |
|---|---|
| Sistema operacional | LMDE 7 |
| Ambiente gráfico | Cinnamon |
| Servidor de áudio | PipeWire |
| Versão do PipeWire observada na instalação anterior | 1.4.2 |
| Interface de compatibilidade | PulseAudio via PipeWire (`pactl`) |
| Placa HDMI | AMD/ATI — `03_00.1` |
| Placa analógica | AMD Ryzen HD Audio — `03_00.6` |
| Codec | Realtek ALC256 |
| Saída desejada | Fone de ouvido P2 |
| Entrada desejada | Microfone do headset P2 |
| Processamento | EasyEffects via Flatpak/Flathub |
| Usuário | `alexsandrorozza` |

### Identificadores de hardware registrados

```text
alsa_card.pci-0000_03_00.1
alsa_card.pci-0000_03_00.6
```

### Identificadores de áudio registrados

```text
Saída analógica:       alsa_output.pci-0000_03_00.6.analog-stereo
Entrada analógica:     alsa_input.pci-0000_03_00.6.analog-stereo
Porta de saída P2:     analog-output-headphones
Porta de entrada P2:   analog-input-headset-mic
```

Esses identificadores foram observados na instalação anterior do notebook. Os scripts verificam se continuam presentes após a reinstalação. Se algum deles mudar ou não existir, a configuração é interrompida e o motivo é registrado no log. **Não substitua identificadores por tentativa ou suposição.**

## 2. Resultado desejado e arquitetura

| Componente | Estado desejado |
|---|---|
| Placa HDMI | Perfil `off` |
| Placa analógica | Perfil `output:analog-stereo+input:analog-stereo` |
| Saída padrão do sistema | Saída física analógica |
| Porta de saída | `analog-output-headphones` — fone P2 |
| Entrada padrão do sistema | Entrada física analógica |
| Porta de entrada | `analog-input-headset-mic` — microfone P2 |
| EasyEffects | Processamento dos fluxos de entrada e saída |
| Inicialização do áudio | Entrada própria no Aplicativos de inicialização do Cinnamon |
| Inicialização do EasyEffects | Segunda entrada própria no Aplicativos de inicialização do Cinnamon |

**Regra importante:** os dispositivos físicos permanecem como dispositivos padrão do sistema. Não definir `easyeffects_sink` nem `easyeffects_source` como padrões globais. O próprio projeto EasyEffects alerta que seus dispositivos virtuais não devem ser definidos como padrão de entrada/saída do sistema, pois o aplicativo espera que o hardware continue como padrão.

O perfil HDMI `off` desativa o perfil da placa de áudio HDMI; não desinstala driver nem remove a placa do sistema. Da mesma forma, selecionar as portas P2 não desativa fisicamente os alto-falantes ou o microfone interno: apenas define as portas desejadas para o uso normal.

### Inicialização automática: dois itens separados

O Cinnamon iniciará dois itens independentes:

1. **Configurar áudio P2:** executa `/home/alexsandrorozza/.local/bin/configurar-audio.sh`, que aguarda PipeWire, ajusta placas e portas e valida os dispositivos físicos.
2. **EasyEffects (Flatpak - modo de serviço):** executa diretamente o comando Flatpak que já foi testado nesta máquina:

```bash
/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=easyeffects com.github.wwmm.easyeffects --hide-window --service-mode
```

O segundo item **não será iniciado pelo script de áudio** e não será gerenciado por uma unidade `systemd --user`. Essa separação evita dois mecanismos tentando iniciar o EasyEffects e preserva o comando de inicialização que funcionou no notebook.

Os arquivos de autostart usam atrasos diferentes: 10 segundos para o script de áudio e 20 segundos para o EasyEffects. O script também espera o servidor de áudio por até 30 segundos. Os atrasos ajudam a espaçar a inicialização, mas não representam uma dependência rígida entre os dois aplicativos; a validação após o login confirma o resultado real.

## 3. Arquivos do repositório

| Arquivo | Função |
|---|---|
| `README.md` | Documentação deste procedimento |
| `instalar-easyeffects-flatpak.sh` | Instala ou valida o EasyEffects via Flatpak/Flathub |
| `configurar-audio.sh` | Configura placas, portas P2 e dispositivos físicos padrão |
| `diagnosticar-audio.sh` | Verifica a configuração sem alterar o áudio |
| `configurar-audio.desktop` | Inicializa o script de configuração no Cinnamon |
| `easyeffects.desktop` | Inicializa o EasyEffects com o comando Flatpak aprovado |
| `SHA256SUMS.txt` | Checksums SHA-256 dos arquivos distribuídos |

## 4. Reinstalar o LMDE 7 e preparar o ambiente

Depois de instalar o LMDE 7 e criar o usuário `alexsandrorozza`:

1. Entre no Cinnamon com esse usuário.
2. Conecte o headset à entrada P2 usada normalmente.
3. Conecte o notebook à internet.
4. Baixe ou clone este repositório.
5. Abra um terminal na pasta do repositório.

Confira a integridade dos arquivos distribuídos:

```bash
sha256sum -c SHA256SUMS.txt
```

Cada arquivo listado deve apresentar `OK`. Se algum item falhar, não execute os scripts: baixe novamente os arquivos do repositório.

Confirme o usuário:

```bash
whoami
```

Resultado esperado:

```text
alexsandrorozza
```

Se o resultado for diferente, não execute os scripts. Eles foram preparados para o usuário e os caminhos registrados neste documento.

## 5. Instalar o EasyEffects pelo Flatpak

O EasyEffects será instalado pelo Flathub, pois essa foi a modalidade que funcionou corretamente com os efeitos no notebook. O APT será usado apenas para instalar o suporte `flatpak`, se necessário. **Não instalar o pacote `easyeffects` pelo APT neste procedimento.**

Execute na pasta do repositório:

```bash
chmod +x instalar-easyeffects-flatpak.sh
./instalar-easyeffects-flatpak.sh
```

O instalador:

1. Confirma o usuário `alexsandrorozza`.
2. Verifica se o Flatpak está instalado; caso não esteja, instala somente o pacote `flatpak` pelo APT.
3. Verifica se o EasyEffects já está instalado para o sistema ou para o usuário, evitando reinstalar uma cópia que já exista.
4. Se o aplicativo ainda não existir, adiciona o Flathub no escopo do sistema e instala a versão `stable` para arquitetura `x86_64`.
5. Confirma que o aplicativo está instalado.
6. Registra cada etapa em log e cria uma cópia de erro se alguma etapa falhar.

Na instalação nova, o script prefere o escopo do sistema. Se encontrar uma instalação existente no escopo do usuário, ele a preserva para não criar uma segunda cópia desnecessária.

Para consultar a instalação:

```bash
flatpak info com.github.wwmm.easyeffects
```

Para abrir a interface manualmente:

```bash
flatpak run com.github.wwmm.easyeffects
```

O comando de autostart da seção 2 é mais específico: fixa a branch `stable`, a arquitetura `x86_64`, o comando interno `easyeffects` e as opções `--hide-window --service-mode`.

## 6. Instalar os scripts e as entradas de inicialização

Ainda na pasta do repositório, execute:

```bash
mkdir -p ~/.local/bin ~/.config/autostart ~/Documentos

install -Dm755 configurar-audio.sh \
  ~/.local/bin/configurar-audio.sh

install -Dm755 diagnosticar-audio.sh \
  ~/.local/bin/diagnosticar-audio.sh

install -Dm644 configurar-audio.desktop \
  ~/.config/autostart/configurar-audio.desktop

install -Dm644 easyeffects.desktop \
  ~/.config/autostart/easyeffects.desktop
```

Os dois arquivos `.desktop` são as duas entradas de inicialização automática do Cinnamon. Eles ficam em `~/.config/autostart/` e podem ser conferidos em **Menu → Preferências → Aplicativos de inicialização**.

Nessa tela, confirme que existem e estão habilitadas as entradas:

- `Configurar áudio P2`
- `EasyEffects (Flatpak - modo de serviço)`

Não crie uma segunda entrada manual para o mesmo comando. Se já existir outra entrada antiga do EasyEffects, desative ou remova a duplicada depois de confirmar qual delas está sendo usada.

## 7. Executar a configuração de áudio manualmente

Execute como usuário normal, **sem `sudo`**:

```bash
~/.local/bin/configurar-audio.sh
```

O script executa as etapas abaixo:

1. Confirma que o usuário é `alexsandrorozza`.
2. Verifica os comandos necessários.
3. Aguarda o servidor de áudio ficar disponível por até 30 segundos.
4. Confirma que `pactl` está conectado ao PipeWire.
5. Confere se as placas HDMI e analógica registradas estão presentes.
6. Desativa o perfil da placa HDMI.
7. Ativa o perfil analógico duplex.
8. Aguarda a criação da saída e da entrada analógicas.
9. Seleciona a porta de fone P2.
10. Seleciona a porta de microfone P2.
11. Consulta `pactl list sinks` e `pactl list sources` para validar as portas ativas.
12. Consulta os perfis ativos das placas.
13. Define a saída e a entrada físicas como padrões do sistema.
14. Consulta novamente `pactl info` para validar os dispositivos padrão.

Se uma verificação obrigatória falhar, o script interrompe a execução. Ele não tenta adivinhar identificadores nem continua como se a configuração tivesse sido concluída.

**O script de áudio não inicia o EasyEffects.** Essa função pertence à segunda entrada de inicialização do Cinnamon.

## 8. Configurar o EasyEffects pela interface gráfica

Abra o EasyEffects pelo menu do Cinnamon ou execute:

```bash
flatpak run com.github.wwmm.easyeffects
```

Nas preferências do EasyEffects, confira:

### Processamento de áudio

- **Process All Output Streams:** habilitado.
- **Process All Input Streams:** habilitado.

Essas opções fazem o EasyEffects processar os fluxos de saída e entrada, respeitando as listas de aplicativos/dispositivos excluídos.

### Inicialização

A inicialização automática é controlada pela entrada `easyeffects.desktop` do Cinnamon. Não habilite também a opção interna **Launch Service at System Startup** do EasyEffects, para evitar dois mecanismos independentes tentando iniciar o mesmo aplicativo.

### Efeitos e presets

Adicione ou ajuste os efeitos desejados nas abas de saída e entrada. Este procedimento não escolhe equalizador, compressor, redução de ruído ou outros efeitos, nem inventa valores de processamento. Os efeitos e presets devem ser configurados conforme o resultado que você deseja ouvir.

Confira também se o EasyEffects não colocou o aplicativo de chamada ou o dispositivo desejado em uma lista de exclusão.

### Aplicativos de chamada e gravação

- Para reprodução, comece usando **Padrão do sistema** como dispositivo de saída.
- Com **Process All Input Streams** habilitado, confira na aba de entrada do EasyEffects se o fluxo do microfone está sendo processado.
- Se um aplicativo específico não receber o microfone processado, teste selecionar **EasyEffects Source** como entrada naquele aplicativo. Isso é uma configuração específica do aplicativo e não altera o padrão global do sistema.
- Não defina `EasyEffects Sink` nem `EasyEffects Source` como dispositivos padrão globais.

A seleção feita dentro de um aplicativo pode substituir o padrão do sistema. Por isso, a chamada de teste deve conferir o microfone e o alto-falante selecionados no próprio aplicativo.

## 9. Diagnóstico automatizado

Depois de instalar os arquivos e iniciar a sessão do Cinnamon, execute:

```bash
~/.local/bin/diagnosticar-audio.sh
```

O diagnóstico é somente de leitura: não altera perfil, porta, volume ou dispositivo padrão. Ele verifica:

- usuário e comandos necessários;
- servidor PipeWire;
- placas HDMI e analógica;
- perfil HDMI `off`;
- perfil analógico duplex;
- presença da saída e da entrada analógicas;
- porta P2 ativa na saída;
- porta P2 ativa na entrada;
- saída e entrada físicas como padrões do sistema;
- instalação Flatpak do EasyEffects;
- processo Flatpak do EasyEffects em execução;
- presença dos dispositivos virtuais `easyeffects_sink` e `easyeffects_source`;
- existência das duas entradas de inicialização do Cinnamon e o comando esperado do EasyEffects;
- ausência do arquivo antigo `easyeffects.service` em `systemd --user`.

O resultado usa os indicadores `[OK]` e `[FALHA]`. O script retorna código `0` quando as verificações automáticas passam e código `1` se encontrar alguma falha. A aprovação automática não substitui o teste físico.

## 10. Conferência manual pelo terminal

### Servidor e dispositivos padrão

```bash
pactl info
```

Confira especialmente:

```text
Server Name: PulseAudio (on PipeWire ...)
Default Sink: alsa_output.pci-0000_03_00.6.analog-stereo
Default Source: alsa_input.pci-0000_03_00.6.analog-stereo
```

A versão do PipeWire pode ser diferente da registrada anteriormente. O essencial é que o nome do servidor indique PipeWire e que os padrões sejam os dispositivos físicos esperados.

### Placas

```bash
pactl list short cards
```

### Saídas e entradas

```bash
pactl list short sinks
pactl list short sources
```

### Portas ativas

```bash
pactl list sinks
pactl list sources
```

Procure `Active Port` no bloco de cada dispositivo analógico. Os valores desejados são:

```text
analog-output-headphones
analog-input-headset-mic
```

### Perfis ativos

```bash
pactl list cards
```

Na placa HDMI, o perfil ativo esperado é `off`. Na placa analógica, o perfil esperado é `output:analog-stereo+input:analog-stereo`.

### Processo EasyEffects

```bash
flatpak ps --columns=application:full
pactl list short sinks
pactl list short sources
```

A primeira saída deve incluir `com.github.wwmm.easyeffects`. As listas de áudio devem incluir `easyeffects_sink` e `easyeffects_source` quando o EasyEffects estiver iniciado e integrado ao PipeWire.

## 11. Teste físico obrigatório

A configuração só deve ser considerada aprovada depois destes testes:

1. Confirme que o headset está conectado à entrada P2 correta.
2. Reproduza música ou outro áudio e confirme que o som sai pelo fone P2.
3. Faça uma gravação curta ou use o medidor de entrada para confirmar que o microfone do headset capta a voz.
4. Abra o EasyEffects e confirme que o fluxo de saída aparece na aba de saída e que os efeitos habilitados atuam.
5. Confirme que o fluxo do microfone aparece na aba de entrada e que os efeitos habilitados atuam.
6. Faça uma chamada de teste e confira a entrada e a saída escolhidas pelo aplicativo.
7. Reinicie o notebook, entre novamente no Cinnamon e repita os testes de som e microfone.
8. Execute novamente `~/.local/bin/diagnosticar-audio.sh`.

## 12. Logs e localização dos arquivos

| Arquivo | Conteúdo |
|---|---|
| `~/Documentos/instalar-easyeffects-flatpak.log` | Instalação e validação do Flatpak/EasyEffects |
| `~/instalar-easyeffects-flatpak-erro.log` | Cópia do log do instalador quando ocorre falha |
| `~/Documentos/configurar-audio.log` | Etapas e validações da configuração física de áudio |
| `~/configurar-audio-erro.log` | Cópia do log de configuração quando ocorre falha |
| `~/Documentos/diagnosticar-audio.log` | Resultado do diagnóstico somente de leitura |
| `~/diagnosticar-audio-erro.log` | Cópia do diagnóstico quando há falhas |

Consultar os logs:

```bash
cat ~/Documentos/instalar-easyeffects-flatpak.log
cat ~/Documentos/configurar-audio.log
cat ~/Documentos/diagnosticar-audio.log
```

Os arquivos `*-erro.log` só são mantidos quando a execução correspondente termina com falha.

O comando do EasyEffects é iniciado diretamente pelo Cinnamon para preservar o funcionamento que já foi testado. Não há um serviço `systemd --user` criado por este conjunto e, portanto, não existe um `journalctl -u easyeffects.service` associado a esta arquitetura. Para visualizar mensagens de inicialização do EasyEffects, feche o aplicativo e execute o comando abaixo em um terminal:

```bash
/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=easyeffects com.github.wwmm.easyeffects --hide-window --service-mode
```

As mensagens serão exibidas no próprio terminal enquanto o processo estiver em execução.

## 13. Solução de problemas

### O servidor PipeWire não foi encontrado

```bash
pactl info
systemctl --user status pipewire pipewire-pulse wireplumber
```

Não altere os identificadores de hardware enquanto o servidor de áudio não estiver funcionando. Primeiro resolva a inicialização do PipeWire/WirePlumber.

### Uma das placas não foi encontrada

```bash
pactl list short cards
```

Compare os identificadores com os registrados na seção 1. Se forem diferentes, salve a saída desses comandos e revise os identificadores antes de alterar o script.

### O fone P2 não ficou selecionado

```bash
pactl set-sink-port \
  alsa_output.pci-0000_03_00.6.analog-stereo \
  analog-output-headphones

pactl list sinks
```

Confira `Active Port` no bloco da saída analógica.

### O microfone P2 não ficou selecionado

```bash
pactl set-source-port \
  alsa_input.pci-0000_03_00.6.analog-stereo \
  analog-input-headset-mic

pactl list sources
```

Confira `Active Port` no bloco da entrada analógica.

### A placa HDMI voltou a ficar ativa

```bash
pactl set-card-profile \
  alsa_card.pci-0000_03_00.1 off
```

Depois confira o perfil ativo com `pactl list cards`.

### O EasyEffects não iniciou automaticamente

1. Abra **Menu → Preferências → Aplicativos de inicialização**.
2. Confirme que `EasyEffects (Flatpak - modo de serviço)` está habilitado.
3. Confira se o comando da entrada é exatamente:

```bash
/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=easyeffects com.github.wwmm.easyeffects --hide-window --service-mode
```

4. Confira se o aplicativo está instalado:

```bash
flatpak info com.github.wwmm.easyeffects
```

5. Execute o comando em um terminal para visualizar eventuais mensagens de erro.

### Os dispositivos virtuais do EasyEffects não aparecem

```bash
flatpak ps --columns=application:full
pactl list short sinks
pactl list short sources
```

Confirme na interface do EasyEffects se **Process All Output Streams** e **Process All Input Streams** estão habilitados. Verifique também se o processo está em execução e se não existem erros ao iniciar pelo terminal.

### O aplicativo de chamada não recebe o microfone processado

Confira a entrada escolhida dentro do próprio aplicativo. Teste `EasyEffects Source` como entrada específica do aplicativo, sem torná-lo o padrão global do sistema. Verifique também se o aplicativo não está na lista de exclusões do EasyEffects.

## 14. Migração da documentação anterior

Esta versão substitui a inicialização do EasyEffects por `systemd --user` por duas entradas independentes no Cinnamon. Se você chegou a aplicar a versão anterior desta documentação **nesta mesma instalação**, remova a unidade antiga para evitar duplicidade:

```bash
systemctl --user disable --now easyeffects.service 2>/dev/null || true
rm -f ~/.config/systemd/user/easyeffects.service
systemctl --user daemon-reload
```

Esse bloco é apenas para remover a unidade criada pela versão anterior deste procedimento. Em uma instalação limpa do LMDE 7, se a unidade nunca foi criada, não é necessário executá-lo.

Depois, instale os dois arquivos `.desktop` conforme a seção 6 e deixe habilitada somente uma entrada para iniciar o EasyEffects.

## 15. Critérios de aprovação

| Verificação | Resultado exigido |
|---|---|
| Usuário | `alexsandrorozza` |
| PipeWire | Disponível e identificado por `pactl` |
| Placa HDMI | Encontrada; perfil `off` |
| Placa analógica | Encontrada; perfil duplex ativo |
| Saída analógica | Presente |
| Porta de saída | `analog-output-headphones` |
| Entrada analógica | Presente |
| Porta de entrada | `analog-input-headset-mic` |
| Saída padrão global | `alsa_output.pci-0000_03_00.6.analog-stereo` |
| Entrada padrão global | `alsa_input.pci-0000_03_00.6.analog-stereo` |
| EasyEffects Flatpak | Instalado e executando |
| Inicialização Cinnamon | Duas entradas habilitadas, sem duplicidade |
| Dispositivos virtuais | `easyeffects_sink` e `easyeffects_source` presentes |
| Processamento | Process All Output Streams e Process All Input Streams habilitados |
| Teste físico | Som no fone e captação pelo microfone P2 aprovados |
| Reinicialização | Configuração e processamento preservados após novo login |

**Marque a configuração como aprovada somente depois de confirmar os itens automáticos, os ajustes da interface gráfica e os testes físicos após reiniciar.**

## 16. Referências

- [EasyEffects — repositório oficial e recomendação sobre dispositivos padrão](https://github.com/wwmm/easyeffects)
- [EasyEffects — documentação das preferências de áudio](https://github.com/wwmm/easyeffects/tree/master/docs)
- [EasyEffects — instalação pelo Flathub](https://flathub.org/apps/com.github.wwmm.easyeffects)
- [Flatpak — documentação de uso](https://docs.flatpak.org/en/latest/using-flatpak.html)
- [Cinnamon Session — suporte às opções de autostart](https://github.com/linuxmint/cinnamon-session)
