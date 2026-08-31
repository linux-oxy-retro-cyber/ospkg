#!/bin/bash

# Diretórios de destino
APP_DIR="$HOME/.local/share/ospkg/apps/fastfetch"
DESKTOP_DIR="$HOME/.local/share/applications"
UNINSTALL_DIR="/usr/share/ospkg/app-uninstall"

echo "-> [OSPන්K] Iniciando a instalação do fastfetch..."

# 1. Cria as pastas necessárias
mkdir -p "$APP_DIR"
mkdir -p "$DESKTOP_DIR"
sudo mkdir -p "$UNINSTALL_DIR"

# 2. Baixa o AppImage mais recente do eDEX-UI do GitHub oficial (com o link corrigido)
APPIMAGE_URL=""
DEST_FILE="$APP_DIR/fastfetch.AppImage"

echo "-> Baixando o binário do fastfetch..."
curl -L -o "$DEST_FILE" "$APPIMAGE_URL"

if [ ! -f "$DEST_FILE" ]; then
    echo "Erro: Falha ao baixar o fastfetch."
    exit 1
fi

# 3. Dá permissão de execução (chmod +x)
chmod +x "$DEST_FILE"
echo "-> Permissão de execução concedida."

# 4. Cria o atalho .desktop para o menu do sistema
echo "-> Criando atalho no menu de aplicativos..."
cat << EOF > "$DESKTOP_DIR/fastfetch.desktop"
[Desktop Entry]
Name=fastfetch
Exec=$DEST_FILE
Icon=utilities-terminal
Type=Application
Terminal=true
StartupNotify=true
EOF

# 5. Cria o script de desinstalação correspondente para o 'ospkg uninstall edex-ui'
sudo tee "$UNINSTALL_DIR/fastfetch.sh" > /dev/null << 'EOF'
#!/bin/bash
echo "-> Removendo o fastfetch..."
rm -rf "$HOME/.local/share/ospkg/apps/fastfetch"
rm -f "$HOME/.local/share/applications/fastfetch.desktop"
echo "-> fastfetch desinstalado com sucesso!"
EOF

sudo chmod +x "$UNINSTALL_DIR/fastfetch.sh"

echo "-> fastfetch instalado com sucesso! Já aparece no seu menu de apps."
