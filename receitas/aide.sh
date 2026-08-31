#!/bin/bash

# Diretórios de destino
APP_DIR="$HOME/.local/share/ospkg/apps/aide"
DESKTOP_DIR="$HOME/.local/share/applications"
UNINSTALL_DIR="/usr/share/ospkg/app-uninstall"

echo "-> [OSPන්K] Iniciando a instalação do Arduino IDE..."

# 1. Cria as pastas necessárias
mkdir -p "$APP_DIR"
mkdir -p "$DESKTOP_DIR"
sudo mkdir -p "$UNINSTALL_DIR"

# 2. Baixa o AppImage mais recente do eDEX-UI do GitHub oficial (com o link corrigido)
APPIMAGE_URL="https://github.com/Johnzin-WakaWaka/OxyohanOS/releases/download/repoup1035/arduino-ide_2.3.10_Linux_64bit.AppImage"
DEST_FILE="$APP_DIR/aide.AppImage"

echo "-> Baixando o binário do Arduino IDE..."
curl -L -o "$DEST_FILE" "$APPIMAGE_URL"

if [ ! -f "$DEST_FILE" ]; then
    echo "Erro: Falha ao baixar o Arduino IDE."
    exit 1
fi

# 3. Dá permissão de execução (chmod +x)
chmod +x "$DEST_FILE"
echo "-> Permissão de execução concedida."

# 4. Cria o atalho .desktop para o menu do sistema
echo "-> Criando atalho no menu de aplicativos..."
cat << EOF > "$DESKTOP_DIR/aide.desktop"
[Desktop Entry]
Name=Arduino IDE
Exec=$DEST_FILE
Icon=utilities-terminal
Type=Application
Terminal=false
StartupNotify=true
EOF

# 5. Cria o script de desinstalação correspondente para o 'ospkg uninstall edex-ui'
sudo tee "$UNINSTALL_DIR/aide.sh" > /dev/null << 'EOF'
#!/bin/bash
echo "-> Removendo o VLC..."
rm -rf "$HOME/.local/share/ospkg/apps/aide"
rm -f "$HOME/.local/share/applications/aide.desktop"
echo "-> VLC desinstalado com sucesso!"
EOF

sudo chmod +x "$UNINSTALL_DIR/aide.sh"

echo "-> Arduino IDE instalado com sucesso! Já aparece no seu menu de apps."
