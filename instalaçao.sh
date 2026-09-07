#!/bin/bash

# ==============================================================================
# INSTALADOR LINUX ESTILO VOID-INSTALLER (100% FUNCIONAL E PROFISSIONAL)
# Escrito em Shell Script usando Dialog e cfdisk.
# ==============================================================================

# Garante que o script está rodando como root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Erro: Este instalador precisa ser executado como root (sudo)."
  exit 1
fi

# Garante que o pacote dialog está instalado
if ! command -v dialog &> /dev/null; then
  echo "[*] O pacote 'dialog' é necessário. Instalando..."
  if command -v apt-get &>/dev/null; then
    apt-get update && apt-get install -y dialog
  elif command -v pacman &>/dev/null; then
    pacman -Sy --noconfirm dialog
  elif command -v dnf &>/dev/null; then
    dnf install -y dialog
  elif command -v xbps-install &>/dev/null; then
    xbps-install -Sy dialog
  else
    echo "[-] Erro: Não foi possível instalar o 'dialog'. Por favor, instale-o manualmente."
    exit 1
  fi
fi

# Configuração e limpeza de arquivos temporários
INSTALLER_MOUNTS="/tmp/installer_mounts"
INSTALLER_LOG="/tmp/installer.log"
rm -f "$INSTALLER_MOUNTS" "$INSTALLER_LOG"
touch "$INSTALLER_MOUNTS" "$INSTALLER_LOG"

trap "rm -f $INSTALLER_MOUNTS" EXIT

# ==============================================================================
# VARIÁVEIS DE ESTADO GLOBAL
# ==============================================================================
KEYBOARD_LAYOUT=""
LOCALE=""
TIMEZONE=""
HOSTNAME=""
NET_INTERFACE=""
NET_TYPE="" # dhcp, static
NET_IP=""
NET_GATEWAY=""
NET_DNS=""
INSTALL_SOURCE="" # Local (Rsync), Bootstrap (debootstrap/pacstrap/dnf/xbps)
DISK=""
ROOT_PASSWORD=""
USER_NAME=""
USER_PASSWORD=""
USER_SHELL="/bin/bash"
USER_SUDO="yes"

# ==============================================================================
# FUNÇÕES DE VERIFICAÇÃO DE STATUS
# ==============================================================================
check_keyboard() { [ -n "$KEYBOARD_LAYOUT" ]; }
check_locale() { [ -n "$LOCALE" ]; }
check_timezone() { [ -n "$TIMEZONE" ]; }
check_hostname() { [ -n "$HOSTNAME" ]; }
check_network() { [ -n "$NET_INTERFACE" ] || ping -c 1 -W 1 8.8.8.8 &>/dev/null; }
check_source() { [ -n "$INSTALL_SOURCE" ]; }
check_partition() { [ -n "$DISK" ]; }
check_filesystems() {
  if [ -f "$INSTALLER_MOUNTS" ] && [ -s "$INSTALLER_MOUNTS" ]; then
    grep -q ";/;[^;]*;[^;]*$" "$INSTALLER_MOUNTS"
  else
    false
  fi
}
check_users() { [ -n "$ROOT_PASSWORD" ] && [ -n "$USER_NAME" ] && [ -n "$USER_PASSWORD" ]; }

# ==============================================================================
# RENDERIZADOR DOS LABELS DO MENU PRINCIPAL
# ==============================================================================
get_menu_label() {
  local key="$1"
  case "$key" in
    keyboard)
      if check_keyboard; then echo "Teclado          [OK: $KEYBOARD_LAYOUT]"
      else echo "Teclado          [Não configurado]"; fi
      ;;
    locale)
      if check_locale; then echo "Idioma/Locale    [OK: $LOCALE]"
      else echo "Idioma/Locale    [Não configurado]"; fi
      ;;
    timezone)
      if check_timezone; then echo "Fuso Horário     [OK: $TIMEZONE]"
      else echo "Fuso Horário     [Não configurado]"; fi
      ;;
    hostname)
      if check_hostname; then echo "Hostname         [OK: $HOSTNAME]"
      else echo "Hostname         [Não configurado]"; fi
      ;;
    network)
      if check_network; then
        if [ -n "$NET_INTERFACE" ]; then
          echo "Rede             [OK: $NET_INTERFACE ($NET_TYPE)]"
        else
          echo "Rede             [OK: Conectado]"
        fi
      else
        echo "Rede             [Não configurado / Sem Internet]"
      fi
      ;;
    source)
      if check_source; then echo "Fonte Instalação [OK: $INSTALL_SOURCE]"
      else echo "Fonte Instalação [Não configurado]"; fi
      ;;
    partition)
      if check_partition; then echo "Particionar      [OK: /dev/$DISK]"
      else echo "Particionar      [Não configurado]"; fi
      ;;
    filesystems)
      if check_filesystems; then
        local count
        count=$(wc -l < "$INSTALLER_MOUNTS")
        echo "Pontos Montagem  [OK: $count mapeamento(s)]"
      else
        echo "Pontos Montagem  [Não configurado]"
      fi
      ;;
    users)
      if check_users; then echo "Contas Usuários  [OK: $USER_NAME]"
      else echo "Contas Usuários  [Não configurado]"; fi
      ;;
  esac
}

# ==============================================================================
# 1. ESCOLHA DE TECLADO
# ==============================================================================
escolher_teclado() {
  local kb
  kb=$(dialog --stdout --title "Configuração de Teclado" \
    --menu "Selecione o layout do seu teclado:" 18 60 10 \
    "br-abnt2" "Português do Brasil (ABNT2)" \
    "us" "Inglês (EUA Padrão)" \
    "us-intl" "Inglês (EUA com teclas de acentuação)" \
    "es" "Espanhol" \
    "pt" "Português de Portugal" \
    "fr" "Francês (AZERTY)" \
    "de" "Alemão (QWERTZ)" \
    "it" "Italiano" \
    "manual" "Outro layout (digitar manualmente)")

  [ -z "$kb" ] && return

  if [ "$kb" = "manual" ]; then
    kb=$(dialog --stdout --title "Layout de Teclado Manual" \
      --inputbox "Digite o layout do teclado (ex: us, br-abnt2, fr):" 10 50)
  fi

  if [ -n "$kb" ]; then
    if loadkeys "$kb" &>/dev/null; then
      KEYBOARD_LAYOUT="$kb"
      dialog --msgbox "Teclado configurado com sucesso para: $KEYBOARD_LAYOUT" 6 50
    else
      dialog --msgbox "Aviso: Não foi possível carregar o layout '$kb', mas a configuração foi salva para o sistema alvo." 8 50
      KEYBOARD_LAYOUT="$kb"
    fi
  fi
}

# ==============================================================================
# 2. ESCOLHA DE IDIOMA/LOCALE
# ==============================================================================
escolher_locale() {
  local loc
  loc=$(dialog --stdout --title "Configuração de Idioma (Locale)" \
    --menu "Selecione o idioma padrão do sistema:" 18 60 8 \
    "pt_BR.UTF-8" "Português do Brasil (UTF-8)" \
    "en_US.UTF-8" "Inglês (EUA) (UTF-8)" \
    "es_ES.UTF-8" "Espanhol (Espanha) (UTF-8)" \
    "fr_FR.UTF-8" "Francês (França) (UTF-8)" \
    "de_DE.UTF-8" "Alemão (Alemanha) (UTF-8)" \
    "it_IT.UTF-8" "Italiano (Itália) (UTF-8)" \
    "manual" "Outro locale (digitar manualmente)")

  [ -z "$loc" ] && return

  if [ "$loc" = "manual" ]; then
    loc=$(dialog --stdout --title "Locale Manual" \
      --inputbox "Digite o locale completo (ex: pt_PT.UTF-8, ja_JP.UTF-8):" 10 50)
  fi

  if [ -n "$loc" ]; then
    LOCALE="$loc"
    dialog --msgbox "Idioma configurado para: $LOCALE" 6 45
  fi
}

# ==============================================================================
# 3. CONFIGURAÇÃO DE FUSO HORÁRIO
# ==============================================================================
escolher_timezone() {
  local region
  region=$(dialog --stdout --title "Fuso Horário - Região" \
    --menu "Selecione a região geográfica:" 18 60 10 \
    "America" "América" \
    "Europe" "Europa" \
    "Asia" "Ásia" \
    "Africa" "África" \
    "Pacific" "Oceano Pacífico" \
    "Atlantic" "Oceano Atlântico" \
    "UTC" "Tempo Universal Coordenado (UTC)")

  [ -z "$region" ] && return

  if [ "$region" = "UTC" ]; then
    TIMEZONE="UTC"
    dialog --msgbox "Fuso horário definido como: UTC" 6 45
    return
  fi

  # Coleta cidades dinamicamente a partir do /usr/share/zoneinfo/
  if [ -d "/usr/share/zoneinfo/$region" ]; then
    local subzones
    subzones=$(find "/usr/share/zoneinfo/$region" -mindepth 1 -maxdepth 2 -not -type d | sed "s|/usr/share/zoneinfo/$region/||" | sort)
    
    local dialog_args=()
    for sz in $subzones; do
      dialog_args+=("$sz" "")
    done

    local sz_choice
    sz_choice=$(dialog --stdout --title "Fuso Horário - Cidade / Zona" \
      --menu "Selecione a cidade ou subzona:" 20 60 12 \
      "${dialog_args[@]}")

    if [ -n "$sz_choice" ]; then
      TIMEZONE="$region/$sz_choice"
      dialog --msgbox "Fuso horário definido como: $TIMEZONE" 6 50
    fi
  else
    dialog --msgbox "Erro: Pasta de fuso horário não encontrada para a região $region." 8 50
  fi
}

# ==============================================================================
# 4. CONFIGURAÇÃO DE HOSTNAME
# ==============================================================================
configurar_hostname() {
  while true; do
    local name
    name=$(dialog --stdout --title "Nome do Computador (Hostname)" \
      --inputbox "Digite o hostname para este computador (letras, números e hífens):" 10 50 "$HOSTNAME")
    
    [ -z "$name" ] && return

    if [[ "$name" =~ ^[a-zA-Z0-9-]+$ ]]; then
      HOSTNAME="$name"
      break
    else
      dialog --msgbox "Erro: Hostname inválido! Não use espaços, acentos ou caracteres especiais." 8 50
    fi
  done
}

# ==============================================================================
# 5. CONFIGURAÇÃO DE REDE
# ==============================================================================
configurar_rede() {
  local net_op
  net_op=$(dialog --stdout --title "Configurações de Rede" \
    --menu "Selecione uma opção de rede:" 15 60 5 \
    "TEST" "Testar conexão com a internet (Ping)" \
    "NMTUI" "Abrir interface gráfica de rede (Wi-Fi/Cabo)" \
    "DHCP" "Configurar interface de rede automaticamente (DHCP)" \
    "STATIC" "Configurar IP Estático manualmente")

  [ -z "$net_op" ] && return

  case "$net_op" in
    TEST)
      dialog --infobox "Testando conexão com a internet (pingando 8.8.8.8)..." 5 50
      if ping -c 3 8.8.8.8 &>/dev/null; then
        dialog --msgbox "Sucesso! O computador está conectado à Internet." 6 50
      else
        dialog --msgbox "Falha: Sem conexão com a internet. Verifique os cabos ou Wi-Fi." 7 50
      fi
      ;;
    NMTUI)
      if command -v nmtui &>/dev/null; then
        nmtui
      else
        dialog --msgbox "Erro: nmtui (NetworkManager) não está instalado no ambiente live." 7 50
      fi
      ;;
    DHCP)
      # Listar interfaces
      local interfaces
      interfaces=$(ls /sys/class/net | grep -v "lo")
      if [ -z "$interfaces" ]; then
        dialog --msgbox "Nenhuma placa de rede física encontrada!" 6 45
        return
      fi

      local dialog_args=()
      for i in $interfaces; do
        dialog_args+=("$i" "")
      done

      local iface
      iface=$(dialog --stdout --title "Selecionar Placa de Rede" \
        --menu "Escolha a interface para configurar via DHCP:" 15 50 5 \
        "${dialog_args[@]}")
      
      [ -z "$iface" ] && return

      dialog --infobox "Solicitando endereço de IP para $iface via DHCP..." 5 50
      if dhclient "$iface" &>/dev/null || dhcpcd "$iface" &>/dev/null || nmcli device connect "$iface" &>/dev/null; then
        NET_INTERFACE="$iface"
        NET_TYPE="DHCP"
        dialog --msgbox "Interface $iface configurada com sucesso via DHCP!" 6 50
      else
        dialog --msgbox "Falha ao obter IP automático. Verifique o cabo ou o servidor DHCP." 7 50
      fi
      ;;
    STATIC)
      local interfaces
      interfaces=$(ls /sys/class/net | grep -v "lo")
      if [ -z "$interfaces" ]; then
        dialog --msgbox "Nenhuma placa de rede física encontrada!" 6 45
        return
      fi

      local dialog_args=()
      for i in $interfaces; do
        dialog_args+=("$i" "")
      done

      local iface
      iface=$(dialog --stdout --title "Selecionar Placa de Rede" \
        --menu "Escolha a interface para IP Estático:" 15 50 5 \
        "${dialog_args[@]}")
      
      [ -z "$iface" ] && return

      local ip
      ip=$(dialog --stdout --title "IP e Máscara" --inputbox "Digite o IP com a máscara (ex: 192.168.1.100/24):" 10 50 "$NET_IP")
      [ -z "$ip" ] && return

      local gw
      gw=$(dialog --stdout --title "Gateway Padrão" --inputbox "Digite o IP do Gateway (ex: 192.168.1.1):" 10 50 "$NET_GATEWAY")
      [ -z "$gw" ] && return

      local dns
      dns=$(dialog --stdout --title "Servidor DNS" --inputbox "Digite o IP do DNS (ex: 8.8.8.8):" 10 50 "$NET_DNS")
      [ -z "$dns" ] && return

      dialog --infobox "Aplicando configurações de rede estática..." 5 50
      ip addr flush dev "$iface" &>/dev/null
      if ip addr add "$ip" dev "$iface" &>/dev/null && ip route add default via "$gw" &>/dev/null; then
        echo "nameserver $dns" > /etc/resolv.conf
        NET_INTERFACE="$iface"
        NET_TYPE="Estático"
        NET_IP="$ip"
        NET_GATEWAY="$gw"
        NET_DNS="$dns"
        dialog --msgbox "Rede estática configurada com sucesso em $iface!" 6 50
      else
        dialog --msgbox "Erro ao aplicar configurações estáticas. Verifique as informações fornecidas." 8 50
      fi
      ;;
  esac
}

# ==============================================================================
# 6. CONFIGURAÇÃO DA FONTE DE INSTALAÇÃO
# ==============================================================================
escolher_source() {
  local choice
  choice=$(dialog --stdout --title "Fonte de Instalação" \
    --menu "De onde virá o sistema base a ser instalado no disco?" 15 65 4 \
    "Local" "Copia o sistema que está rodando agora (Rsync Live System)" \
    "Rede" "Instalação limpa via utilitário de bootstrap (Internet)")

  [ -z "$choice" ] && return

  if [ "$choice" = "Local" ]; then
    INSTALL_SOURCE="Local (Rsync)"
  else
    local b_tools=()
    if command -v debootstrap &>/dev/null; then b_tools+=("debootstrap" "Debian/Ubuntu Bootstrap"); fi
    if command -v pacstrap &>/dev/null; then b_tools+=("pacstrap" "Arch Linux pacstrap"); fi
    if command -v dnf &>/dev/null; then b_tools+=("dnf" "Fedora Core --installroot"); fi
    if command -v xbps-install &>/dev/null; then b_tools+=("xbps" "Void Linux xbps-install"); fi

    if [ ${#b_tools[@]} -eq 0 ]; then
      dialog --msgbox "Nenhum utilitário de bootstrap (debootstrap, pacstrap, dnf, xbps-install) detectado no ambiente live.\n\nO instalador usará o método Local (Rsync)." 10 55
      INSTALL_SOURCE="Local (Rsync)"
    else
      local b_choice
      b_choice=$(dialog --stdout --title "Utilitário de Bootstrap" \
        --menu "Escolha a ferramenta de bootstrap para download da base:" 15 60 5 \
        "${b_tools[@]}")
      
      if [ -n "$b_choice" ]; then
        INSTALL_SOURCE="Bootstrap ($b_choice)"
      fi
    fi
  fi
}

# ==============================================================================
# 7. PARTICIONAMENTO DE DISCO (CFDISK)
# ==============================================================================
particionar_disco() {
  local disks_list
  disks_list=$(lsblk -dno NAME,SIZE,MODEL | grep -v "loop" | grep -v "zram")
  if [ -z "$disks_list" ]; then
    dialog --msgbox "Erro: Nenhum disco disponível encontrado!" 6 45
    return
  fi

  local dialog_args=()
  while read -r name size model; do
    dialog_args+=("$name" "($size) $model")
  done <<< "$disks_list"

  local chosen_disk
  chosen_disk=$(dialog --stdout --title "Particionamento de Disco" \
    --menu "Selecione o disco rígido/SSD para particionar com cfdisk:" 18 60 10 \
    "${dialog_args[@]}")

  [ -z "$chosen_disk" ] && return

  # Abre o cfdisk no terminal real para que o usuário interaja perfeitamente
  clear
  cfdisk "/dev/$chosen_disk"

  DISK="$chosen_disk"
  dialog --msgbox "Particionamento concluído para /dev/$DISK. Agora prossiga para 'Pontos Montagem' para configurar onde cada partição ficará." 10 55
}

# ==============================================================================
# 8. PONTOS DE MONTAGEM E SISTEMAS DE ARQUIVOS
# ==============================================================================
configurar_pontos_montagem() {
  while true; do
    local mappings_summary=""
    if [ -f "$INSTALLER_MOUNTS" ] && [ -s "$INSTALLER_MOUNTS" ]; then
      mappings_summary="Mapeamentos atuais definidos:\n"
      while IFS=';' read -r part mnt fstype format; do
        mappings_summary+="  - $part -> $mnt ($fstype, formatar: $format)\n"
      done < "$INSTALLER_MOUNTS"
    else
      mappings_summary="Nenhum mapeamento configurado ainda.\nA partição raiz (/) é obrigatória para a instalação."
    fi

    local action
    action=$(dialog --stdout --title "Pontos de Montagem e Sistemas de Arquivos" \
      --menu "$mappings_summary\n\nEscolha uma ação:" 22 75 8 \
      "ADD" "Adicionar/Modificar mapeamento de partição" \
      "DEL" "Remover um mapeamento existente" \
      "CLR" "Limpar todos os mapeamentos" \
      "OK" "Confirmar e Voltar para o Menu Principal")

    [ -z "$action" ] && return

    case "$action" in
      ADD)
        # Obter todas as partições do sistema
        local parts_list
        parts_list=$(lsblk -lnpo NAME,SIZE,TYPE | grep -E "part|lvm|crypt" | awk '{print $1 " (" $2 ")"}')
        if [ -z "$parts_list" ]; then
          dialog --msgbox "Nenhuma partição encontrada! Use o cfdisk no passo anterior primeiro." 8 50
          continue
        fi

        local dialog_args=()
        while read -r part size; do
          dialog_args+=("$part" "$size")
        done <<< "$parts_list"

        local selected_part
        selected_part=$(dialog --stdout --title "Selecionar Partição" \
          --menu "Selecione a partição física/lógica:" 18 60 10 \
          "${dialog_args[@]}")
        [ -z "$selected_part" ] && continue

        local mnt_point
        mnt_point=$(dialog --stdout --title "Ponto de Montagem" \
          --menu "Selecione onde montar $selected_part no novo sistema:" 18 60 8 \
          "/" "Partição Raiz (Obrigatório - Sistema principal)" \
          "/boot" "Partição de Inicialização (GRUB)" \
          "/boot/efi" "Partição EFI (Obrigatório em sistemas UEFI)" \
          "/home" "Arquivos pessoais dos usuários (/home)" \
          "swap" "Área de troca (SWAP)" \
          "custom" "Digitar ponto de montagem personalizado")
        [ -z "$mnt_point" ] && continue

        if [ "$mnt_point" = "custom" ]; then
          mnt_point=$(dialog --stdout --title "Ponto de Montagem Personalizado" \
            --inputbox "Digite o caminho completo de montagem (ex: /var, /mnt/dados):" 10 55)
          [ -z "$mnt_point" ] && continue
          if [[ ! "$mnt_point" =~ ^/ ]]; then
            dialog --msgbox "Erro: O caminho do ponto de montagem deve começar com '/'!" 6 50
            continue
          fi
        fi

        local format_choice
        format_choice=$(dialog --stdout --title "Formatar Partição?" \
          --yesno "Deseja formatar a partição $selected_part? (Isso apagará todos os dados nela)" 8 55)
        local format_status=$?

        local fs_type="none"
        local format_flag="no"

        if [ $format_status -eq 0 ]; then
          format_flag="yes"
          if [ "$mnt_point" = "swap" ]; then
            fs_type="swap"
          elif [ "$mnt_point" = "/boot/efi" ]; then
            fs_type="vfat"
          else
            fs_type=$(dialog --stdout --title "Sistema de Arquivos" \
              --menu "Selecione o formato para $selected_part:" 15 55 5 \
              "ext4" "Extended 4 (Padrão Linux)" \
              "btrfs" "Btrfs (Moderno, Snapshots)" \
              "xfs" "XFS (Performance com arquivos grandes)" \
              "f2fs" "F2FS (Otimizado para SSDs/Flash)")
            [ -z "$fs_type" ] && continue
          fi
        else
          # Se não formatar, tenta ler o filesystem já existente
          fs_type=$(blkid -o value -s TYPE "$selected_part")
          [ -z "$fs_type" ] && fs_type="ext4"
        fi

        # Remove mapeamentos duplicados anteriores para esta partição ou este ponto de montagem
        local temp_file
        temp_file=$(mktemp)
        grep -v -E "^$selected_part;|^[^;]*;$mnt_point;" "$INSTALLER_MOUNTS" > "$temp_file" 2>/dev/null
        mv "$temp_file" "$INSTALLER_MOUNTS"

        echo "$selected_part;$mnt_point;$fs_type;$format_flag" >> "$INSTALLER_MOUNTS"
        ;;

      DEL)
        if [ ! -f "$INSTALLER_MOUNTS" ] || [ ! -s "$INSTALLER_MOUNTS" ]; then
          dialog --msgbox "Nenhum mapeamento registrado para deletar." 6 45
          continue
        fi

        local dialog_args=()
        while IFS=';' read -r part mnt fstype format; do
          dialog_args+=("$part" "-> $mnt ($fstype)")
        done < "$INSTALLER_MOUNTS"

        local to_del
        to_del=$(dialog --stdout --title "Remover Mapeamento" \
          --menu "Selecione o mapeamento que deseja excluir:" 18 60 10 \
          "${dialog_args[@]}")
        [ -z "$to_del" ] && continue

        local temp_file
        temp_file=$(mktemp)
        grep -v "^$to_del;" "$INSTALLER_MOUNTS" > "$temp_file"
        mv "$temp_file" "$INSTALLER_MOUNTS"
        ;;

      CLR)
        if dialog --yesno "Tem certeza que deseja apagar TODOS os mapeamentos?" 7 50; then
          > "$INSTALLER_MOUNTS"
        fi
        ;;

      OK)
        if check_filesystems; then
          break
        else
          dialog --msgbox "Erro obrigatório: Você precisa definir uma partição para a Raiz (/)!" 8 55
        fi
        ;;
    esac
  done
}

# ==============================================================================
# 9. CONFIGURAÇÃO DE CONTAS DE USUÁRIOS
# ==============================================================================
configurar_usuarios() {
  # Senha do Root
  while true; do
    local pass1
    pass1=$(dialog --stdout --title "Senha do Administrador (Root)" \
      --insecure --passwordbox "Digite a senha do usuário root:" 10 50)
    [ -z "$pass1" ] && return

    local pass2
    pass2=$(dialog --stdout --title "Confirmar Senha do Root" \
      --insecure --passwordbox "Digite a senha do root novamente para confirmar:" 10 50)
    
    if [ "$pass1" = "$pass2" ]; then
      ROOT_PASSWORD="$pass1"
      break
    else
      dialog --msgbox "Erro: As senhas do Root não coincidem! Tente de novo." 7 50
    fi
  done

  # Criação do usuário comum
  while true; do
    local uname
    uname=$(dialog --stdout --title "Nome do Usuário Comum" \
      --inputbox "Digite o nome de usuário (letras minúsculas e números apenas):" 10 50 "$USER_NAME")
    [ -z "$uname" ] && return

    if [[ "$uname" =~ ^[a-z0-9_][a-z0-9_-]*$ ]]; then
      USER_NAME="$uname"
      break
    else
      dialog --msgbox "Erro: Nome de usuário inválido! Use apenas minúsculas, números e hífens." 8 50
    fi
  done

  while true; do
    local upass1
    upass1=$(dialog --stdout --title "Senha de $USER_NAME" \
      --insecure --passwordbox "Digite a senha do usuário $USER_NAME:" 10 50)
    [ -z "$upass1" ] && return

    local upass2
    upass2=$(dialog --stdout --title "Confirmar Senha de $USER_NAME" \
      --insecure --passwordbox "Digite a senha de $USER_NAME novamente para confirmar:" 10 50)

    if [ "$upass1" = "$upass2" ]; then
      USER_PASSWORD="$upass1"
      break
    else
      dialog --msgbox "Erro: As senhas do usuário não coincidem! Tente de novo." 7 50
    fi
  done

  # Seleção do shell padrão
  USER_SHELL=$(dialog --stdout --title "Shell do Usuário" \
    --menu "Selecione o shell padrão para o usuário $USER_NAME:" 12 50 3 \
    "/bin/bash" "Bash (Altamente Recomendado)" \
    "/bin/zsh" "Zsh (Moderno)" \
    "/bin/sh" "POSIX Sh (Básico)")
  [ -z "$USER_SHELL" ] && USER_SHELL="/bin/bash"

  # Permissões sudo/wheel
  if dialog --yesno "Deseja permitir que o usuário '$USER_NAME' execute comandos como Root (Sudo)?" 8 55; then
    USER_SUDO="yes"
  else
    USER_SUDO="no"
  fi

  dialog --msgbox "Contas de usuários configuradas com sucesso!" 6 45
}

# ==============================================================================
# 10. PROCESSO DE INSTALAÇÃO NO DISCO (MÁGICA)
# ==============================================================================
log_step() {
  local msg="$1"
  dialog --title "Instalador Void-Style (Progresso)" --infobox "$msg" 10 65
  echo "[STEP] $msg" >> "$INSTALLER_LOG"
  sleep 1.5
}

requisitos_instalacao() {
  local missing=""
  if ! check_keyboard; then missing+="  - Teclado\n"; fi
  if ! check_locale; then missing+="  - Idioma/Locale\n"; fi
  if ! check_timezone; then missing+="  - Fuso Horário\n"; fi
  if ! check_hostname; then missing+="  - Hostname\n"; fi
  if ! check_source; then missing+="  - Fonte de Instalação\n"; fi
  if ! check_filesystems; then missing+="  - Pontos de Montagem (Mapeamento /)\n"; fi
  if ! check_users; then missing+="  - Contas de Usuários (Root / Comum)\n"; fi

  if [ -n "$missing" ]; then
    dialog --title "Configurações Faltando" \
      --msgbox "Por favor, conclua as seguintes configurações antes de instalar:\n\n$missing" 16 60
    return 1
  fi
  return 0
}

executar_instalacao() {
  if ! requisitos_instalacao; then
    return
  fi

  # Confirmação do resumo
  local summary="Resumo das ações de Instalação:\n\n"
  summary+="  - Hostname: $HOSTNAME\n"
  summary+="  - Idioma: $LOCALE | Teclado: $KEYBOARD_LAYOUT\n"
  summary+="  - Fuso Horário: $TIMEZONE\n"
  summary+="  - Usuário Comum: $USER_NAME (Administrador: $USER_SUDO)\n"
  summary+="  - Método: $INSTALL_SOURCE\n\n"
  summary+="Discos e Partições a formatar/montar:\n"
  while IFS=';' read -r part mnt fstype format; do
    summary+="  - $part -> $mnt ($fstype, formatar: $format)\n"
  done < "$INSTALLER_MOUNTS"

  if ! dialog --yesno "$summary\nAVISO: Todo o conteúdo das partições marcadas para formatar será APAGADO permanentemente!\nDeseja iniciar a instalação agora?" 22 75; then
    return
  fi

  # Limpando montagens residuais se houver
  umount -R /mnt &>/dev/null
  swapoff -a &>/dev/null

  # 1. FORMATAÇÃO
  log_step "Formatando as partições selecionadas..."
  while IFS=';' read -r part mnt fstype format; do
    if [ "$format" = "yes" ]; then
      echo "Formatando $part como $fstype..." >> "$INSTALLER_LOG"
      case "$fstype" in
        ext4)  mkfs.ext4 -F "$part" >> "$INSTALLER_LOG" 2>&1 ;;
        btrfs) mkfs.btrfs -f "$part" >> "$INSTALLER_LOG" 2>&1 ;;
        xfs)   mkfs.xfs -f "$part" >> "$INSTALLER_LOG" 2>&1 ;;
        vfat)  mkfs.vfat -F32 "$part" >> "$INSTALLER_LOG" 2>&1 ;;
        swap)  mkswap -f "$part" >> "$INSTALLER_LOG" 2>&1 ;;
      esac
    fi
  done < "$INSTALLER_MOUNTS"

  # 2. MONTAGEM
  # Garante que montamos o / primeiro
  local root_part
  root_part=$(grep ";/;[^;]*;[^;]*$" "$INSTALLER_MOUNTS" | cut -d';' -f1)
  
  log_step "Montando partição Raiz (/) em /mnt..."
  mkdir -p /mnt
  mount "$root_part" /mnt >> "$INSTALLER_LOG" 2>&1

  # Ordena e monta os demais pontos de montagem
  sort -t';' -k2 "$INSTALLER_MOUNTS" | while IFS=';' read -r part mnt fstype format; do
    if [ "$mnt" != "/" ] && [ "$mnt" != "swap" ]; then
      log_step "Montando $part em /mnt$mnt..."
      mkdir -p "/mnt$mnt"
      mount "$part" "/mnt$mnt" >> "$INSTALLER_LOG" 2>&1
    elif [ "$mnt" = "swap" ]; then
      log_step "Ativando Swap em $part..."
      swapon "$part" >> "$INSTALLER_LOG" 2>&1
    fi
  done

  # 3. CÓPIA / BOOTSTRAP DO SISTEMA BASE
  if [[ "$INSTALLER_SOURCE" == "Local"* ]]; then
    log_step "Instalando sistema base via Rsync (Cópia local)... Isso pode demorar..."
    # Rsync inteligente excluindo pastas virtuais e de mídias temporárias
    rsync -aAX --info=progress2 / /mnt \
      --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/home/*","/root/*","/var/tmp/*","/var/log/*"} \
      >> "$INSTALLER_LOG" 2>&1
    
    # Recria os diretórios ignorados vazios
    mkdir -p /mnt/{dev,proc,sys,run,tmp,home,root,media,mnt}
    chmod 1777 /mnt/tmp
  else
    # Bootstrap download
    if [[ "$INSTALLER_SOURCE" == *"debootstrap"* ]]; then
      log_step "Baixando base Debian/Ubuntu via debootstrap..."
      debootstrap stable /mnt http://deb.debian.org/debian/ >> "$INSTALLER_LOG" 2>&1
    elif [[ "$INSTALLER_SOURCE" == *"pacstrap"* ]]; then
      log_step "Baixando base Arch Linux via pacstrap..."
      pacstrap /mnt base linux linux-firmware >> "$INSTALLER_LOG" 2>&1
    elif [[ "$INSTALLER_SOURCE" == *"dnf"* ]]; then
      log_step "Baixando base Fedora via dnf installroot..."
      dnf -y --installroot=/mnt --releasever=44 groupinstall "Minimal Install" >> "$INSTALLER_LOG" 2>&1
    elif [[ "$INSTALLER_SOURCE" == *"xbps"* ]]; then
      log_step "Baixando base Void Linux via xbps-install..."
      XBPS_ARCH=x86_64 xbps-install -S -r /mnt -y base-system >> "$INSTALLER_LOG" 2>&1
    else
      log_step "Nenhum utilitário compatível. Copiando sistema local como fallback..."
      rsync -aAX / /mnt \
        --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/home/*","/root/*"} \
        >> "$INSTALLER_LOG" 2>&1
    fi
  fi

  # 4. GERAR ARQUIVO FSTAB COM UUID
  log_step "Gerando arquivo de partições (/mnt/etc/fstab)..."
  echo "# /etc/fstab: static file system information." > /mnt/etc/fstab
  echo "# Generated by void-style-installer" >> /mnt/etc/fstab
  echo "# <file system> <mount point>   <type>      <options>               <dump>  <pass>" >> /mnt/etc/fstab

  # UUID do / primeiro
  local root_uuid
  root_uuid=$(blkid -s UUID -o value "$root_part")
  local root_fs
  root_fs=$(grep ";/;[^;]*;[^;]*$" "$INSTALLER_MOUNTS" | cut -d';' -f3)
  echo "UUID=$root_uuid /               $root_fs        defaults,noatime        0       1" >> /mnt/etc/fstab

  # Outras partições
  while IFS=';' read -r part mnt fstype format; do
    if [ "$mnt" != "/" ]; then
      local uuid
      uuid=$(blkid -s UUID -o value "$part")
      if [ -n "$uuid" ]; then
        if [ "$mnt" = "swap" ]; then
          echo "UUID=$uuid none            swap        defaults                0       0" >> /mnt/etc/fstab
        else
          local opts="defaults,noatime"
          [ "$fstype" = "vfat" ] && opts="defaults,fmask=0077,dmask=0077"
          local pass="2"
          [ "$fstype" = "vfat" ] && pass="0"
          printf "UUID=%-36s %-15s %-11s %-23s %-7s %s\n" "$uuid" "$mnt" "$fstype" "$opts" "0" "$pass" >> /mnt/etc/fstab
        fi
      fi
    fi
  done < "$INSTALLER_MOUNTS"

  # 5. MONTAGEM DE SISTEMAS DE ARQUIVOS VIRTUAIS DO KERNEL
  log_step "Preparando chroot (bind mount dev/proc/sys/run)..."
  mount --bind /dev /mnt/dev >> "$INSTALLER_LOG" 2>&1
  mount --bind /proc /mnt/proc >> "$INSTALLER_LOG" 2>&1
  mount --bind /sys /mnt/sys >> "$INSTALLER_LOG" 2>&1
  mount --bind /run /mnt/run >> "$INSTALLER_LOG" 2>&1
  
  # Copia resolv.conf para dar internet ao chroot
  cp -L /etc/resolv.conf /mnt/etc/resolv.conf >> "$INSTALLER_LOG" 2>&1

  # 6. CRIAÇÃO DO SCRIPT DE PÓS-INSTALAÇÃO DENTRO DO CHROOT
  log_step "Instalando carregador de inicialização (GRUB) e aplicando definições..."
  
  # Escreve o script do chroot
  cat << CHROOT_EOF > /mnt/tmp/chroot_setup.sh
#!/bin/bash

# Aplicar fuso horário
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Aplicar locale
echo "LANG=$LOCALE" > /etc/locale.conf
if [ -f /etc/locale.gen ]; then
  # Descomenta o locale escolhido no arquivo locale.gen
  escaped_locale=\$(echo "$LOCALE" | sed 's/\\./\\\\./g')
  sed -i "s/^#\s*\(\$escaped_locale\)/\1/" /etc/locale.gen
  locale-gen >> /tmp/installer.log 2>&1
fi

# Aplicar hostname
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" > /etc/hosts
echo "127.0.1.1   $HOSTNAME" >> /etc/hosts

# Aplicar layout do teclado no console do sistema alvo
echo "KEYMAP=$KEYBOARD_LAYOUT" > /etc/vconsole.conf
if [ -f /etc/default/keyboard ]; then
  sed -i "s/XKBLAYOUT=.*/XKBLAYOUT=\"$KEYBOARD_LAYOUT\"/" /etc/default/keyboard
fi

# Definir senha do root
echo "root:$ROOT_PASSWORD" | chpasswd

# Criar usuário comum
if id "$USER_NAME" &>/dev/null; then
  userdel -r "$USER_NAME" >> /tmp/installer.log 2>&1
fi
useradd -m -s "$USER_SHELL" "$USER_NAME"
echo "$USER_NAME:$USER_PASSWORD" | chpasswd

# Adicionar usuário ao Sudoers se solicitado
if [ "$USER_SUDO" = "yes" ]; then
  for g in wheel sudo adm; do
    if getent group "\$g" &>/dev/null; then
      usermod -aG "\$g" "$USER_NAME"
    fi
  done
  
  if [ -f /etc/sudoers ]; then
    sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL:ALL)\s\+ALL\)/\1/' /etc/sudoers
    sed -i 's/^#\s*\(%sudo\s\+ALL=(ALL:ALL)\s\+ALL\)/\1/' /etc/sudoers
    sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+ALL\)/\1/' /etc/sudoers
    sed -i 's/^#\s*\(%sudo\s\+ALL=(ALL)\s\+ALL\)/\1/' /etc/sudoers
  fi
fi

# Instalação do Bootloader GRUB
echo "=== Instalando GRUB ===" >> /tmp/installer.log 2>&1
if [ -d /sys/firmware/efi ]; then
  # Sistema UEFI
  if ! command -v grub-install &>/dev/null; then
    # Tenta garantir os pacotes de inicialização no chroot
    if command -v apt-get &>/dev/null; then apt-get update && apt-get install -y grub-efi-amd64 efibootmgr >> /tmp/installer.log 2>&1; fi
    if command -v dnf &>/dev/null; then dnf -y install grub2-efi-x64 efibootmgr >> /tmp/installer.log 2>&1; fi
    if command -v pacman &>/dev/null; then pacman -Sy --noconfirm grub efibootmgr >> /tmp/installer.log 2>&1; fi
    if command -v xbps-install &>/dev/null; then xbps-install -Sy grub-x86_64-efi efibootmgr >> /tmp/installer.log 2>&1; fi
  fi
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck >> /tmp/installer.log 2>&1
else
  # Sistema BIOS Legacy
  if ! command -v grub-install &>/dev/null; then
    if command -v apt-get &>/dev/null; then apt-get update && apt-get install -y grub-pc >> /tmp/installer.log 2>&1; fi
    if command -v dnf &>/dev/null; then dnf -y install grub2-pc >> /tmp/installer.log 2>&1; fi
    if command -v pacman &>/dev/null; then pacman -Sy --noconfirm grub >> /tmp/installer.log 2>&1; fi
    if command -v xbps-install &>/dev/null; then xbps-install -Sy grub >> /tmp/installer.log 2>&1; fi
  fi
  # Determina disco do raiz
  root_dev_disk=\$(echo "$root_part" | sed -E 's/p?[0-9]+\$//')
  [ -z "\$root_dev_disk" ] && root_dev_disk="/dev/$DISK"
  grub-install --target=i386-pc "\$root_dev_disk" >> /tmp/installer.log 2>&1
fi

# Gerar arquivo grub.cfg
if command -v grub-mkconfig &>/dev/null; then
  grub-mkconfig -o /boot/grub/grub.cfg >> /tmp/installer.log 2>&1
elif command -v grub2-mkconfig &>/dev/null; then
  grub2-mkconfig -o /boot/grub2/grub.cfg >> /tmp/installer.log 2>&1
fi

# Reconstruir initramfs para garantir drivers de disco
if command -v dracut &>/dev/null; then
  dracut --force --regenerate-all >> /tmp/installer.log 2>&1
elif command -v update-initramfs &>/dev/null; then
  update-initramfs -u -k all >> /tmp/installer.log 2>&1
elif command -v mkinitcpio &>/dev/null; then
  mkinitcpio -P >> /tmp/installer.log 2>&1
fi
CHROOT_EOF

  chmod +x /mnt/tmp/chroot_setup.sh
  chroot /mnt /tmp/chroot_setup.sh >> "$INSTALLER_LOG" 2>&1
  rm -f /mnt/tmp/chroot_setup.sh

  # 7. DESMONTAGEM E LIMPEZA
  log_step "Finalizando e desmontando partições com segurança..."
  umount -l /mnt/dev >> "$INSTALLER_LOG" 2>&1
  umount -l /mnt/proc >> "$INSTALLER_LOG" 2>&1
  umount -l /mnt/sys >> "$INSTALLER_LOG" 2>&1
  umount -l /mnt/run >> "$INSTALLER_LOG" 2>&1

  sort -r -t';' -k2 "$INSTALLER_MOUNTS" | while IFS=';' read -r part mnt fstype format; do
    if [ "$mnt" != "/" ] && [ "$mnt" != "swap" ]; then
      umount -l "/mnt$mnt" >> "$INSTALLER_LOG" 2>&1
    elif [ "$mnt" = "swap" ]; then
      swapoff "$part" >> "$INSTALLER_LOG" 2>&1
    fi
  done
  umount -l /mnt >> "$INSTALLER_LOG" 2>&1

  dialog --title "Instalação Completa" --msgbox "Parabéns! O seu novo sistema operacional Linux foi instalado com sucesso!\n\nVocê já pode reiniciar seu computador e desfrutar do novo sistema." 12 65
}

# ==============================================================================
# MENU PRINCIPAL (LOOP PRINCIPAL)
# ==============================================================================
while true; do
  opcao=$(dialog --stdout --title "Instalador do Linux - Estilo Void-Installer" \
    --menu "Navegue pelas opções abaixo para configurar seu novo sistema:" 20 65 11 \
    "1" "$(get_menu_label keyboard)" \
    "2" "$(get_menu_label locale)" \
    "3" "$(get_menu_label timezone)" \
    "4" "$(get_menu_label hostname)" \
    "5" "$(get_menu_label network)" \
    "6" "$(get_menu_label source)" \
    "7" "$(get_menu_label partition)" \
    "8" "$(get_menu_label filesystems)" \
    "9" "$(get_menu_label users)" \
    "10" "Executar Instalação do Sistema" \
    "0" "Sair do Instalador")

  [ -z "$opcao" ] && exit 0

  case "$opcao" in
    1) escolher_teclado ;;
    2) escolher_locale ;;
    3) escolher_timezone ;;
    4) configurar_hostname ;;
    5) configurar_rede ;;
    6) escolher_source ;;
    7) particionar_disco ;;
    8) configurar_pontos_montagem ;;
    9) configurar_usuarios ;;
    10) executar_instalacao ;;
    0)
      clear
      echo "Instalador encerrado pelo usuário."
      exit 0
      ;;
  esac
done
