#!/bin/bash

# Diretórios de destino
APP_DIR="$HOME/.local/share/ospkg/apps/edex-ui"
DESKTOP_DIR="$HOME/.local/share/applications"
UNINSTALL_DIR="/usr/share/ospkg/app-uninstall"

echo "-> [OSPන්K] Iniciando a instalação do eDEX-UI..."

# 1. Cria as pastas necessárias
mkdir -p "$APP_DIR"
mkdir -p "$DESKTOP_DIR"
sudo mkdir -p "$UNINSTALL_DIR"

# 2. Baixa o AppImage mais recente do eDEX-UI do GitHub oficial (com o link corrigido)
APPIMAGE_URL="https://github.com/Johnzin-WakaWaka/OxyohanOS/releases/download/repoup1035/eDEX-UI-Linux-x86_64.AppImage"
DEST_FILE="$APP_DIR/edex-ui.AppImage"

echo "-> Baixando o binário do eDEX-UI..."
curl -L -o "$DEST_FILE" "$APPIMAGE_URL"

if [ ! -f "$DEST_FILE" ]; then
    echo "Erro: Falha ao baixar o eDEX-UI."
    exit 1
fi

# 3. Dá permissão de execução (chmod +x)
chmod +x "$DEST_FILE"
echo "-> Permissão de execução concedida."

# 4. Cria o atalho .desktop para o menu do sistema
echo "-> Criando atalho no menu de aplicativos..."
cat << EOF > "$DESKTOP_DIR/edex-ui.desktop"
[Desktop Entry]
Name=eDEX-UI
Exec=$DEST_FILE
Icon=utilities-terminal
Type=Application
Categories=System;TerminalEmulator;
Terminal=false
StartupNotify=true
EOF

# 5. Cria o script de desinstalação correspondente para o 'ospkg uninstall edex-ui'
sudo tee "$UNINSTALL_DIR/edex-ui.sh" > /dev/null << 'EOF'
#!/bin/bash
echo "-> Removendo o eDEX-UI..."
rm -rf "$HOME/.local/share/ospkg/apps/edex-ui"
rm -f "$HOME/.local/share/applications/edex-ui.desktop"
echo "-> eDEX-UI desinstalado com sucesso!"
EOF

sudo chmod +x "$UNINSTALL_DIR/edex-ui.sh"

echo "-> eDEX-UI instalado com sucesso! Já aparece no seu menu de apps."
