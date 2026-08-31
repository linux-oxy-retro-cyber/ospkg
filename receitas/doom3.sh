#!/bin/bash

# Diretórios de destino
APP_DIR="$HOME/.local/share/ospkg/apps/doom3"
DESKTOP_DIR="$HOME/.local/share/applications"
UNINSTALL_DIR="/usr/share/ospkg/app-uninstall"

echo "-> [OSPන්K] Iniciando a instalação do Doom 3..."

# 1. Cria as pastas necessárias
mkdir -p "$APP_DIR"
mkdir -p "$DESKTOP_DIR"
sudo mkdir -p "$UNINSTALL_DIR"

# 2. Baixa o AppImage mais recente do eDEX-UI do GitHub oficial (com o link corrigido)
APPIMAGE_URL="https://github.com/Johnzin-WakaWaka/OxyohanOS/releases/download/repoup1035/Dhewm3-20250209-1.5.5pre-x86_64.AppImage"
DEST_FILE="$APP_DIR/doom3.AppImage"

echo "-> Baixando o binário do Doom 3..."
curl -L -o "$DEST_FILE" "$APPIMAGE_URL"

if [ ! -f "$DEST_FILE" ]; then
    echo "Erro: Falha ao baixar o Doom 3."
    exit 1
fi

# 3. Dá permissão de execução (chmod +x)
chmod +x "$DEST_FILE"
echo "-> Permissão de execução concedida."

# 4. Cria o atalho .desktop para o menu do sistema
echo "-> Criando atalho no menu de aplicativos..."
cat << EOF > "$DESKTOP_DIR/doom3.desktop"
[Desktop Entry]
Name=Doom 3
Exec=$DEST_FILE
Icon=utilities-terminal
Type=Application
Terminal=false
StartupNotify=true
EOF

# 5. Cria o script de desinstalação correspondente para o 'ospkg uninstall edex-ui'
sudo tee "$UNINSTALL_DIR/doom3.sh" > /dev/null << 'EOF'
#!/bin/bash
echo "-> Removendo o Doom 3..."
rm -rf "$HOME/.local/share/ospkg/apps/doom3"
rm -f "$HOME/.local/share/applications/doom3.desktop"
echo "-> Doom 3 desinstalado com sucesso!"
EOF

sudo chmod +x "$UNINSTALL_DIR/doom3.sh"

echo "-> Doom 3 instalado com sucesso! Já aparece no seu menu de apps."
