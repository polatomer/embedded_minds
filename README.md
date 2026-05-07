# AKS — Akıllı Sağlık Çantası

Qt6/QML tabanlı, Raspberry Pi üzerinde çalışan dokunmatik ekran acil ilk yardım rehber sistemi.  
MAX30102 nabız/SpO2 sensörü, gaz dedektörü ve sesli komut desteği içerir.

---

## Hızlı Kurulum

```bash
git clone https://github.com/polatomer/embedded_minds.git
cd embedded_minds
sudo bash install.sh
```

Kurulum tamamlandıktan sonra uygulama `/opt/AKS` dizinine kurulur ve cihaz açılışında otomatik başlar.

---

## Desteklenen Sistemler

- Raspberry Pi OS (önerilen)
- Ubuntu 22.04+
- Debian 11+

> `apt` paket yöneticisi gereklidir.

---

## Proje Yapısı

```
embedded_minds/
├── CMakeLists.txt          # CMake derleme dosyası
├── install.sh              # Otomatik kurulum scripti
├── voice_test.py           # Sesli komut servisi (Vosk tabanlı)
├── src/                    # C++ kaynak kodları
│   ├── main.cpp
│   ├── app_bridge.h/cpp    # QML ↔ C++ köprüsü
│   ├── voice_command_server.h/cpp  # Sesli komut Unix socket sunucusu
│   ├── cpr_controller.h/cpp
│   ├── bleeding_controller.h/cpp
│   ├── vital_signs_service.h/cpp
│   ├── max30102_sensor.h/cpp
│   └── event_recorder.h/cpp
├── ui/                     # QML arayüz dosyaları
│   ├── main.qml
│   ├── HomeScreen.qml
│   ├── CPRGuidanceScreen.qml
│   └── ...
├── data/                   # Soru/tanı/yönlendirme JSON dosyaları
│   ├── questions/
│   ├── diagnoses/
│   └── guidance/
└── README.md
```

---

## Bağımlılıklar

`install.sh` aşağıdaki paketleri otomatik kurar:

**C++ / Qt:**
```
cmake, build-essential, pkg-config
nlohmann-json3-dev, libgpiod-dev
qt6-base-dev, qt6-declarative-dev, qt6-multimedia-dev, qt6-tools-dev
libqt6network6-dev
qml6-module-qtquick, qml6-module-qtquick-controls
qml6-module-qtquick-layouts, qml6-module-qtmultimedia
libgl1-mesa-dev, libpulse-dev, alsa-utils
```

**Python / Sesli Komut:**
```
python3, python3-pip, portaudio19-dev
vosk, sounddevice, numpy
```

---

## Sesli Komut Kurulumu

Sesli komut için Vosk Türkçe modeli gereklidir (repo'ya dahil değildir, boyutu büyük olduğundan).

```bash
cd /opt/AKS
wget https://alphacephei.com/vosk/models/vosk-model-small-tr-0.3.zip
unzip vosk-model-small-tr-0.3.zip
mv vosk-model-small-tr-0.3 model-tr
```

Model kurulduktan sonra sesli komut servisi cihaz açılışında otomatik başlar.

**Desteklenen sesli komutlar** (`<komut> tamam` formatında söylenir):

| Söylenen | İşlev |
|---|---|
| `evet tamam` | Evet / Onayla |
| `hayır tamam` | Hayır / Reddet |
| `geri tamam` | Geri git |
| `ileri tamam` | İleri git |
| `devam et tamam` | Devam et |
| `ana sayfa tamam` | Ana sayfaya dön |
| `acil durum tamam` | Acil değerlendirme başlat |
| `ayarlar tamam` | Ayarlar ekranı |
| `ambulans ara tamam` | 112'yi ara |
| `türkçe tamam` | Dili Türkçe yap |
| `ingilizce tamam` | Dili İngilizce yap |
| `veritabanı tamam` | Kayıtlar ekranı |
| `veri kaydını sil tamam` | Kayıtları sil |

---

## Manuel Derleme

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
./AKS
```

---

## Kurulum Sonrası

| Dosya / Dizin | Açıklama |
|---|---|
| `/opt/AKS/` | Uygulama dosyaları |
| `/opt/AKS/run.sh` | Uygulamayı başlatır |
| `/opt/AKS/run_voice.sh` | Sesli komut servisini başlatır |
| `/var/log/aks/aks.log` | Uygulama logları |
| `/var/log/aks/voice.log` | Sesli komut logları |
| `~/.config/autostart/` | Otomatik başlatma dosyaları |

**Elle çalıştırmak için:**
```bash
/opt/AKS/run.sh          # Uygulama
/opt/AKS/run_voice.sh    # Sesli komut (ayrı terminal)
```

**Canlı log takibi:**
```bash
tail -f /var/log/aks/aks.log
tail -f /var/log/aks/voice.log
```

---

## Güncelleme

```bash
cd embedded_minds
git pull
sudo bash install.sh
```

---

## Sık Karşılaşılan Hatalar

**`nlohmann_json` bulunamadı:**
```bash
sudo apt install nlohmann-json3-dev
```

**`gpiod` bulunamadı:**
```bash
sudo apt install libgpiod-dev
```

**`Qt6::Network` bulunamadı:**
```bash
sudo apt install libqt6network6-dev
```

**QML modülü bulunamadı:**
```bash
sudo apt install qml6-module-qtquick qml6-module-qtquick-controls \
                 qml6-module-qtquick-layouts qml6-module-qtmultimedia
```

**`model-tr` bulunamadı (sesli komut çalışmıyor):**  
Yukarıdaki "Sesli Komut Kurulumu" adımlarını takip et.

**Ekran açılmıyor (`xcb` hatası):**
```bash
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb
/opt/AKS/run.sh
```
