#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AKS"
APP_BINARY="AKS"
INSTALL_DIR="/opt/AKS"
CONFIG_DIR="/etc/aks"
DATA_DIR="/var/lib/aks"
LOG_DIR="/var/log/aks"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Root kontrolü ─────────────────────────────────────────────────────────────
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

# ── C++/Qt bağımlılıkları ─────────────────────────────────────────────────────
echo ""
echo "[1/7] C++ ve Qt bağımlılıkları kuruluyor..."
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
    libqt6network6-dev \
    qml6-module-qtquick \
    qml6-module-qtquick-window \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-templates \
    qml6-module-qtmultimedia \
    libgl1-mesa-dev \
    libpulse-dev \
    alsa-utils

# ── Python ses tanıma bağımlılıkları ─────────────────────────────────────────
echo ""
echo "[2/7] Python ve Vosk bağımlılıkları kuruluyor..."

apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    portaudio19-dev \
    libsndfile1

pip3 install --break-system-packages \
    vosk \
    sounddevice \
    numpy

# ── Klasörler ─────────────────────────────────────────────────────────────────
echo ""
echo "[3/7] Klasörler oluşturuluyor..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$DATA_DIR"
mkdir -p "$LOG_DIR"

# ── Dosya kopyalama ───────────────────────────────────────────────────────────
echo ""
echo "[4/7] Dosyalar $INSTALL_DIR altına kopyalanıyor..."
rsync -a --delete \
    --exclude "build/" \
    --exclude ".git/" \
    --exclude ".gitignore" \
    --exclude "*.log" \
    --exclude "*.o" \
    --exclude "*.user" \
    "$SRC_DIR/" "$INSTALL_DIR/"

# ── Yetkilendirme ─────────────────────────────────────────────────────────────
chown -R "$INSTALL_USER:$INSTALL_USER" "$INSTALL_DIR"
chown -R "$INSTALL_USER:$INSTALL_USER" "$DATA_DIR"
chown -R "$INSTALL_USER:$INSTALL_USER" "$LOG_DIR"

# ── Derleme ───────────────────────────────────────────────────────────────────
echo ""
echo "[5/7] Proje derleniyor (bu biraz sürebilir)..."
cd "$INSTALL_DIR"
rm -rf build
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"

# Binary'i bul
REAL_BINARY="$INSTALL_DIR/build/$APP_BINARY"
if [ ! -x "$REAL_BINARY" ]; then
    FOUND_BINARY="$(find "$INSTALL_DIR/build" -maxdepth 1 -type f -executable | head -n 1 || true)"
    if [ -z "$FOUND_BINARY" ]; then
        echo ""
        echo "Hata: Çalıştırılabilir dosya bulunamadı."
        echo "CMakeLists.txt içindeki add_executable hedef adını kontrol et."
        exit 1
    fi
    REAL_BINARY="$FOUND_BINARY"
fi

echo "Binary: $REAL_BINARY"

# ── run.sh ────────────────────────────────────────────────────────────────────
echo ""
echo "[6/7] Başlatma dosyaları oluşturuluyor..."

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

# ── Ses tanıma başlatma scripti ───────────────────────────────────────────────
# voice_test.py ve model-tr klasörünün $INSTALL_DIR içinde olmasını bekler.
# Yoksa bu kısım sessizce atlanır.
if [ -f "$INSTALL_DIR/voice_test.py" ]; then
    cat > "$INSTALL_DIR/run_voice.sh" <<VOICEEOF
#!/usr/bin/env bash
# AKS sesli komut servisi
# Gereksinim: $INSTALL_DIR/model-tr klasörü mevcut olmalı
cd "$INSTALL_DIR"
if [ ! -d "model-tr" ]; then
    echo "Hata: model-tr klasörü bulunamadı: $INSTALL_DIR/model-tr"
    exit 1
fi
python3 "$INSTALL_DIR/voice_test.py" >> "$LOG_DIR/voice.log" 2>&1
VOICEEOF
    chmod +x "$INSTALL_DIR/run_voice.sh"
    chown "$INSTALL_USER:$INSTALL_USER" "$INSTALL_DIR/run_voice.sh"
    echo "Sesli komut scripti oluşturuldu: $INSTALL_DIR/run_voice.sh"
fi

# ── Otomatik başlatma (LXDE / GNOME / KDE) ───────────────────────────────────
mkdir -p "$USER_HOME/.config/autostart"

# AKS uygulaması
cat > "$USER_HOME/.config/autostart/aks.desktop" <<DESKTOPEOF
[Desktop Entry]
Type=Application
Name=AKS - Akıllı Sağlık Çantası
Exec=$INSTALL_DIR/run.sh
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOPEOF

# Sesli komut servisi (model-tr varsa)
if [ -f "$INSTALL_DIR/run_voice.sh" ] && [ -d "$INSTALL_DIR/model-tr" ]; then
    cat > "$USER_HOME/.config/autostart/aks-voice.desktop" <<VOICEDESKTOPEOF
[Desktop Entry]
Type=Application
Name=AKS Sesli Komut
Exec=bash -c "sleep 5 && $INSTALL_DIR/run_voice.sh"
Terminal=false
X-GNOME-Autostart-enabled=true
VOICEDESKTOPEOF
    echo "Sesli komut otomatik başlatma eklendi (5 sn gecikme ile)."
fi

chown -R "$INSTALL_USER:$INSTALL_USER" "$USER_HOME/.config/autostart"

# ── Masaüstü kısayolu ─────────────────────────────────────────────────────────
DESKTOP_DIR="$USER_HOME/Desktop"
if [ ! -d "$DESKTOP_DIR" ]; then
    DESKTOP_DIR="$USER_HOME/Masaüstü"
fi
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

# ── Özet ─────────────────────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo " Kurulum Tamamlandı"
echo "=================================================="
echo ""
echo " AKS başlatmak için:"
echo "   $INSTALL_DIR/run.sh"
echo ""
echo " Sesli komut başlatmak için (ayrı terminal):"
echo "   $INSTALL_DIR/run_voice.sh"
echo ""
echo " Loglar:"
echo "   $LOG_DIR/aks.log"
echo "   $LOG_DIR/voice.log"
echo ""
echo " Cihaz yeniden başlatıldığında her ikisi otomatik açılır."
echo "=================================================="
