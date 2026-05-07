#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AKS"
APP_BINARY="AKS"
INSTALL_DIR="/opt/AKS"
CONFIG_DIR="/etc/aks"
DATA_DIR="/var/lib/aks"
LOG_DIR="/var/log/aks"
VOSK_MODEL_URL="https://alphacephei.com/vosk/models/vosk-model-small-tr-0.3.zip"
VOSK_MODEL_ZIP="vosk-model-small-tr-0.3.zip"
VOSK_MODEL_DIR="vosk-model-small-tr-0.3"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "Hata: Kurulum sudo ile çalıştırılmalı."
    echo "Kullanım: sudo bash install.sh"
    exit 1
fi

INSTALL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
USER_HOME="$(getent passwd "$INSTALL_USER" | cut -d: -f6)"

echo "=================================================="
echo " AKS Kurulumu Başlıyor"
echo " Kullanıcı : $INSTALL_USER"
echo " Kaynak    : $SRC_DIR"
echo " Hedef     : $INSTALL_DIR"
echo "=================================================="

echo ""
echo "[1/8] C++ ve Qt bağımlılıkları kuruluyor..."
apt-get update -qq

apt-get install -y \
    rsync \
    git \
    cmake \
    build-essential \
    pkg-config \
    nlohmann-json3-dev \
    libgpiod-dev \
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-multimedia-dev \
    qt6-tools-dev \
    qml6-module-qtquick \
    qml6-module-qtquick-window \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-templates \
    qml6-module-qtmultimedia \
    libgl1-mesa-dev \
    libpulse-dev \
    alsa-utils \
    unzip \
    wget

echo ""
echo "[2/8] Python ve Vosk bağımlılıkları kuruluyor..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    portaudio19-dev \
    libsndfile1

pip3 install --break-system-packages vosk sounddevice numpy 2>/dev/null || \
pip3 install vosk sounddevice numpy

echo ""
echo "[3/8] Klasörler oluşturuluyor..."
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"

echo ""
echo "[4/8] Dosyalar $INSTALL_DIR altına kopyalanıyor..."
rsync -a --delete \
    --exclude "build/" \
    --exclude ".git/" \
    --exclude ".gitignore" \
    --exclude "*.log" \
    --exclude "*.o" \
    --exclude "*.user" \
    "$SRC_DIR/" "$INSTALL_DIR/"

chown -R "$INSTALL_USER:$INSTALL_USER" "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR"

echo ""
echo "[5/8] Proje derleniyor..."
cd "$INSTALL_DIR"
rm -rf build
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"

REAL_BINARY="$INSTALL_DIR/build/$APP_BINARY"
if [ ! -x "$REAL_BINARY" ]; then
    FOUND_BINARY="$(find "$INSTALL_DIR/build" -maxdepth 1 -type f -executable | head -n 1 || true)"
    if [ -z "$FOUND_BINARY" ]; then
        echo "Hata: Çalıştırılabilir dosya bulunamadı."
        exit 1
    fi
    REAL_BINARY="$FOUND_BINARY"
fi
echo "Binary: $REAL_BINARY"

echo ""
echo "[6/8] Vosk Türkçe model indiriliyor..."
cd "$INSTALL_DIR"
if [ -d "model-tr" ]; then
    echo "model-tr zaten mevcut, atlanıyor."
else
    echo "İndiriliyor: $VOSK_MODEL_URL"
    wget -q --show-progress "$VOSK_MODEL_URL" -O "$VOSK_MODEL_ZIP"
    unzip -q "$VOSK_MODEL_ZIP"
    mv "$VOSK_MODEL_DIR" model-tr
    rm -f "$VOSK_MODEL_ZIP"
    echo "Model kuruldu: $INSTALL_DIR/model-tr"
fi
chown -R "$INSTALL_USER:$INSTALL_USER" "$INSTALL_DIR/model-tr"

echo ""
echo "[7/8] Başlatma dosyaları oluşturuluyor..."
cat > "$INSTALL_DIR/run.sh" <<RUNEOF
#!/usr/bin/env bash
set -e
cd "$INSTALL_DIR/build"
export QT_QPA_PLATFORM=xcb
export DISPLAY=:0
"$REAL_BINARY" >> "$LOG_DIR/aks.log" 2>&1
RUNEOF
chmod +x "$INSTALL_DIR/run.sh"
chown "$INSTALL_USER:$INSTALL_USER" "$INSTALL_DIR/run.sh"

if [ -f "$INSTALL_DIR/voice_test.py" ]; then
    cat > "$INSTALL_DIR/run_voice.sh" <<VOICEEOF
#!/usr/bin/env bash
cd "$INSTALL_DIR"
if [ ! -d "model-tr" ]; then
    echo "Hata: model-tr klasörü bulunamadı."
    exit 1
fi
python3 "$INSTALL_DIR/voice_test.py" >> "$LOG_DIR/voice.log" 2>&1
VOICEEOF
    chmod +x "$INSTALL_DIR/run_voice.sh"
    chown "$INSTALL_USER:$INSTALL_USER" "$INSTALL_DIR/run_voice.sh"
fi

echo ""
echo "[8/8] Otomatik başlatma ayarlanıyor..."
mkdir -p "$USER_HOME/.config/autostart"

cat > "$USER_HOME/.config/autostart/aks.desktop" <<DESKTOPEOF
[Desktop Entry]
Type=Application
Name=AKS - Akıllı Sağlık Çantası
Exec=$INSTALL_DIR/run.sh
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOPEOF

if [ -f "$INSTALL_DIR/run_voice.sh" ] && [ -d "$INSTALL_DIR/model-tr" ]; then
    cat > "$USER_HOME/.config/autostart/aks-voice.desktop" <<VOICEDESKTOPEOF
[Desktop Entry]
Type=Application
Name=AKS Sesli Komut
Exec=bash -c "sleep 5 && $INSTALL_DIR/run_voice.sh"
Terminal=false
X-GNOME-Autostart-enabled=true
VOICEDESKTOPEOF
fi

chown -R "$INSTALL_USER:$INSTALL_USER" "$USER_HOME/.config/autostart"

for DESKTOP_DIR in "$USER_HOME/Desktop" "$USER_HOME/Masaüstü"; do
    if [ -d "$DESKTOP_DIR" ]; then
        cat > "$DESKTOP_DIR/AKS.desktop" <<SHORTCUTEOF
[Desktop Entry]
Type=Application
Name=AKS - Akıllı Sağlık Çantası
Exec=$INSTALL_DIR/run.sh
Terminal=false
SHORTCUTEOF
        chmod +x "$DESKTOP_DIR/AKS.desktop"
        chown "$INSTALL_USER:$INSTALL_USER" "$DESKTOP_DIR/AKS.desktop"
    fi
done

echo ""
echo "=================================================="
echo " Kurulum Tamamlandı"
echo "=================================================="
echo " Çalıştırmak için:  $INSTALL_DIR/run.sh"
echo " Sesli komut:       $INSTALL_DIR/run_voice.sh"
echo " Loglar:            $LOG_DIR/aks.log"
echo "=================================================="
