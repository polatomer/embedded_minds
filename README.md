# AKS Linux Kurulum Dokümantasyonu

AKS, Linux tabanlı cihazlarda çalışacak şekilde geliştirilen Qt/CMake tabanlı bir uygulamadır.

Bu proje, özellikle Raspberry Pi OS, Ubuntu ve Debian tabanlı Linux sistemlerde tek komutla kurulabilecek şekilde hazırlanmıştır.

Amaç; yazılımın ticari cihazlarda manuel işlem gerektirmeden kurulması, bağımlılıklarının otomatik yüklenmesi, derlenmesi ve çalıştırılabilir hale getirilmesidir.

---

## 1. Projenin Amacı

Bu kurulum yapısı sayesinde AKS yazılımı herhangi bir Linux cihaza şu mantıkla kurulabilir:

```bash
git clone https://github.com/KULLANICI/AKS.git
cd AKS
sudo bash install.sh
```

Kurulum tamamlandıktan sonra yazılım:

```text
/opt/AKS
```

dizinine kurulur.

Kullanıcı veya teknisyen dosyaları elle taşımak zorunda kalmaz.

---

## 2. Desteklenen Sistemler

Bu kurulum yapısı Debian tabanlı Linux dağıtımları için hazırlanmıştır.

Test edilmesi hedeflenen sistemler:

```text
Raspberry Pi OS
Ubuntu
Debian
Linux Mint
```

Not: Bu sistemlerde `apt` paket yöneticisi bulunmalıdır.

---

## 3. Proje Klasör Yapısı

Git deposundaki önerilen proje yapısı:

```text
AKS/
├── CMakeLists.txt
├── src/
├── ui/
├── data/
├── install.sh
├── dependencies-apt.txt
├── .gitignore
└── README.md
```

Açıklamalar:

```text
CMakeLists.txt          Projenin CMake derleme dosyası
src/                    C++ kaynak kodları
ui/                     QML arayüz dosyaları
data/                   Varsayılan veri dosyaları
install.sh              Otomatik kurulum scripti
dependencies-apt.txt    Linux bağımlılık listesi
.gitignore              Git'e gönderilmeyecek dosyalar
README.md               Kurulum dokümantasyonu
```

---

## 4. Git'e Gönderilmemesi Gereken Dosyalar

Aşağıdaki klasör ve dosyalar Git deposuna gönderilmemelidir:

```text
build/
logs/
*.log
*.o
*.user
```

Çünkü:

- `build/` her cihazda yeniden oluşturulur.
- `logs/` cihazdan cihaza değişir.
- Derleme çıktıları Git deposunu gereksiz büyütür.

Önerilen `.gitignore` içeriği:

```gitignore
build/
logs/
*.log
*.o
*.user
.DS_Store
```

---

## 5. Kurulum Sonrası Sistem Klasörleri

Kurulumdan sonra dosyalar Linux sisteminde şu dizinlere yerleştirilir:

```text
/opt/AKS          Ana yazılım dosyaları
/etc/aks          Ayar dosyaları
/var/lib/aks      Veri dosyaları
/var/log/aks      Log dosyaları
```

Bu yapı ticari Linux uygulamaları için daha düzenlidir.

---

## 6. Otomatik Kurulum

Yeni bir cihazda kurulum yapmak için:

```bash
git clone https://github.com/KULLANICI/AKS.git
cd AKS
sudo bash install.sh
```

Buradaki:

```text
https://github.com/KULLANICI/AKS.git
```

kısmı gerçek GitHub depo adresi ile değiştirilmelidir.

Örnek:

```bash
git clone https://github.com/ahmetzeki/AKS.git
cd AKS
sudo bash install.sh
```

---

## 7. install.sh Ne Yapar?

`install.sh` çalıştırıldığında sırasıyla şu işlemleri yapar:

1. Scriptin `sudo` ile çalıştırılıp çalıştırılmadığını kontrol eder.
2. Kurulumu yapan kullanıcıyı tespit eder.
3. Gerekli Linux bağımlılıklarını yükler.
4. `/opt/AKS` klasörünü oluşturur.
5. `/etc/aks` klasörünü oluşturur.
6. `/var/lib/aks` klasörünü oluşturur.
7. `/var/log/aks` klasörünü oluşturur.
8. Proje dosyalarını `/opt/AKS` altına kopyalar.
9. `build/` klasörünü temizler.
10. CMake ile yeniden derleme yapar.
11. Çalıştırılabilir uygulama dosyasını bulur.
12. `/opt/AKS/run.sh` dosyasını oluşturur.
13. Masaüstüne `AKS.desktop` kısayolu ekler.
14. Uygulama menüsüne AKS kısayolu ekler.
15. Cihaz açıldığında otomatik başlatma ayarı oluşturur.
16. Logları `/var/log/aks/aks.log` dosyasına yönlendirir.

---

## 8. Bağımlılıkların Yüklenmesi

Bağımlılıklar `dependencies-apt.txt` dosyasında tutulur.

Bu dosyada kurulması gereken Linux paketleri satır satır yazılır.

Örnek `dependencies-apt.txt` içeriği:

```text
git
rsync
cmake
build-essential
pkg-config
qt6-base-dev
qt6-declarative-dev
qt6-multimedia-dev
qt6-tools-dev
qml6-module-qtquick
qml6-module-qtquick-window
qml6-module-qtquick-controls
qml6-module-qtquick-layouts
qml6-module-qtquick-templates
qml6-module-qtmultimedia
libgl1-mesa-dev
xdg-utils
desktop-file-utils
```

Kurulum sırasında `install.sh` şu komutu çalıştırır:

```bash
apt update
xargs apt install -y < dependencies-apt.txt
```

Bu komut:

1. Paket listesini günceller.
2. `dependencies-apt.txt` içindeki paketleri okur.
3. Eksik olan bağımlılıkları otomatik kurar.

---

## 9. Bağımlılıkları Manuel Kurma

Otomatik kurulum dışında bağımlılıkları manuel yüklemek için:

```bash
sudo apt update
xargs sudo apt install -y < dependencies-apt.txt
```

Eğer `dependencies-apt.txt` dosyası yoksa paketler manuel olarak şöyle kurulabilir:

```bash
sudo apt update

sudo apt install -y \
    git \
    rsync \
    cmake \
    build-essential \
    pkg-config \
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
    xdg-utils \
    desktop-file-utils
```

---

## 10. Programı Elle Derleme

Geliştirme ortamında programı elle derlemek için:

```bash
mkdir -p build
cd build
cmake ..
make -j$(nproc)
```

Derleme tamamlandıktan sonra çalıştırmak için:

```bash
./AKS
```

Not: Binary adı CMake hedef adına göre farklı olabilir.

---

## 11. Kurulumdan Sonra Programı Çalıştırma

Kurulum tamamlandıktan sonra programı elle çalıştırmak için:

```bash
/opt/AKS/run.sh
```

Bu dosya uygulamayı başlatır ve logları şu dosyaya yazar:

```text
/var/log/aks/aks.log
```

---

## 12. Masaüstü Kısayolu

Kurulumdan sonra masaüstünde şu kısayol oluşur:

```text
AKS.desktop
```

Bu kısayola çift tıklanarak yazılım başlatılabilir.

Kısayolun çalıştırdığı dosya:

```text
/opt/AKS/run.sh
```

---

## 13. Uygulama Menüsü Kısayolu

Kurulum scripti ayrıca şu dosyayı oluşturur:

```text
/usr/share/applications/AKS.desktop
```

Bu sayede AKS uygulaması Linux uygulama menüsünde de görünebilir.

---

## 14. Otomatik Başlatma

Kurulum scripti şu dosyayı oluşturur:

```text
~/.config/autostart/AKS.desktop
```

Bu dosya sayesinde cihaz açıldığında AKS otomatik olarak başlar.

Otomatik başlatmayı kapatmak için bu dosya silinebilir:

```bash
rm ~/.config/autostart/AKS.desktop
```

---

## 15. Log Dosyaları

Program logları şu dosyada tutulur:

```text
/var/log/aks/aks.log
```

Log dosyasını görüntülemek için:

```bash
cat /var/log/aks/aks.log
```

Canlı log takibi için:

```bash
tail -f /var/log/aks/aks.log
```

Log dosyasını temizlemek için:

```bash
sudo truncate -s 0 /var/log/aks/aks.log
```

---

## 16. Güncelleme

Yazılımı güncellemek için Git deposunun bulunduğu klasöre girilir:

```bash
cd AKS
git pull
sudo bash install.sh
```

Bu işlem:

1. Git üzerinden güncel kodları çeker.
2. Dosyaları tekrar `/opt/AKS` altına kopyalar.
3. Projeyi yeniden derler.
4. Çalıştırma ve kısayol dosyalarını tekrar oluşturur.

---

## 17. Kurulumu Kontrol Etme

Kurulumdan sonra dosyaları kontrol etmek için:

```bash
ls /opt/AKS
```

Çalıştırma dosyasını kontrol etmek için:

```bash
ls -l /opt/AKS/run.sh
```

Log klasörünü kontrol etmek için:

```bash
ls /var/log/aks
```

Masaüstü kısayolunu kontrol etmek için:

```bash
ls ~/Desktop/AKS.desktop
```

veya Türkçe sistemlerde:

```bash
ls ~/Masaüstü/AKS.desktop
```

---

## 18. Olası Hatalar

### Hata: sudo ile çalıştırılmalı

Çözüm:

```bash
sudo bash install.sh
```

---

### Hata: CMake bulunamadı

Çözüm:

```bash
sudo apt update
sudo apt install -y cmake
```

---

### Hata: Qt modülü bulunamadı

Çözüm:

```bash
sudo apt install -y qt6-base-dev qt6-declarative-dev qt6-multimedia-dev
```

QML modülleri için:

```bash
sudo apt install -y \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtmultimedia
```

---

### Hata: Çalıştırılabilir dosya bulunamadı

Bu durumda CMake hedef adı kontrol edilmelidir.

`CMakeLists.txt` içinde şuna benzer bir hedef bulunmalıdır:

```cmake
add_executable(AKS ...)
```

Eğer hedef adı farklıysa `install.sh` içindeki şu değişken güncellenmelidir:

```bash
APP_BINARY="AKS"
```

---

## 19. Ticari Ürün Kurulum Mantığı

Bu yapı ticari cihazlarda şu avantajları sağlar:

1. Her cihaz aynı şekilde kurulur.
2. Dosyalar standart Linux dizinlerine yerleşir.
3. Bağımlılıklar otomatik kurulur.
4. Yazılım cihaz üzerinde derlenir.
5. Masaüstü kısayolu otomatik oluşur.
6. Cihaz açılışında yazılım otomatik başlar.
7. Loglar merkezi bir yerde tutulur.
8. Güncelleme süreci kolaylaşır.

---

## 20. Temel Kurulum Özeti

Yeni cihazda yapılacak işlem:

```bash
git clone https://github.com/KULLANICI/AKS.git
cd AKS
sudo bash install.sh
```

Kurulumdan sonra çalıştırma:

```bash
/opt/AKS/run.sh
```

Log kontrolü:

```bash
tail -f /var/log/aks/aks.log
```

Ana kurulum dizini:

```text
/opt/AKS
```
