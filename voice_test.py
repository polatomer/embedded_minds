import json
import queue
import sys
import os
import time
import datetime
import unicodedata
import socket as _socket

import numpy as np
import sounddevice as sd
from scipy.signal import resample_poly
from vosk import Model, KaldiRecognizer, SetLogLevel

SetLogLevel(-1)

# ============================================================
# AYARLAR
# ============================================================

MODEL_PATH = "model-tr"

# Mikrofon 48 kHz alınır, Vosk'a 16 kHz verilir
INPUT_SAMPLE_RATE = 48000
VOSK_SAMPLE_RATE = 16000

# 48 kHz'de 12000 frame = 0.25 saniye
BLOCK_SIZE = 12000
MAX_QUEUE_BLOCKS = 12

# USB mikrofon/ses kartı adı
PREFERRED_DEVICE_KEYWORD = "clean"

# ============================================================
# SES KAZANÇ AYARLARI
# ============================================================

# Sabit başlangıç kazancı
BASE_GAIN = 1.0

# Otomatik ses yükseltme hedef RMS değeri
TARGET_RMS = 4500.0

# Toplam gain üst sınırı
MAX_TOTAL_GAIN = 1.0

# Çok yüksek seslerde kırpılmayı azaltmak için limiter
LIMITER_LEVEL = 30000.0

# Komut güven eşikleri
# Kısa Türkçe kelimelerde 0.50 fazla sert kalabiliyor
MIN_CMD_CONF = 0.30
MIN_TAMAM_CONF = 0.30

# Komut söylendikten sonra "tamam" bekleme süresi
PENDING_CONFIRM_SECONDS = 4.0
COOLDOWN_SECONDS = 0.8

AKS_SOCKET_PATH = "/tmp/aks_voice"

audio_queue = queue.Queue(maxsize=MAX_QUEUE_BLOCKS)

# ============================================================
# KOMUTLAR
# ============================================================

COMMAND_ALIASES = {
    # Genel onay / ret
    "evet": "EVET",
    "hayir": "HAYIR",
    "hayır": "HAYIR",

    # Kanama bölgesi seçimi
    "kol": "KOL",
    "bacak": "BACAK",
    "vucut": "VUCUT",
    "vücut": "VUCUT",
    "govde": "VUCUT",
    "gövde": "VUCUT",

    # Navigasyon
    "geri": "GERI",
    "ileri": "ILERI",
    "devam": "DEVAM_ET",
    "devam et": "DEVAM_ET",
    "ana sayfa": "ANA_SAYFA",
    "anasayfa": "ANA_SAYFA",

    # Acil başlatma
    "acil": "ACIL_DURUM",
    "acil durum": "ACIL_DURUM",

    # Yardım / ayarlar
    "yardim": "YARDIM",
    "yardım": "YARDIM",
    "yardim et": "YARDIM",
    "yardım et": "YARDIM",
    "yardim edin": "YARDIM",
    "yardım edin": "YARDIM",
    "ayarlar": "AYARLAR",

    # Dil
    "turkce": "TURKCE",
    "türkçe": "TURKCE",
    "ingilizce": "INGILIZCE",

    # Kayıtlar
    "veritabani": "VERITABANI",
    "veri tabani": "VERITABANI",
    "veri tabanı": "VERITABANI",
    "veri kaydini sil": "VERI_KAYDINI_SIL",
    "veri kaydını sil": "VERI_KAYDINI_SIL",
    "kaydi sil": "VERI_KAYDINI_SIL",
    "kaydı sil": "VERI_KAYDINI_SIL",
    "kayit sil": "VERI_KAYDINI_SIL",
    "kayıt sil": "VERI_KAYDINI_SIL",

    # Ambulans
    "ambulans ara": "AMBULANS_ARA",
    "yuz on iki ara": "AMBULANS_ARA",
    "yüz on iki ara": "AMBULANS_ARA",
    "on iki ara": "AMBULANS_ARA",
    "yuz oniki ara": "AMBULANS_ARA",
    "yüz oniki ara": "AMBULANS_ARA",
}

TAMAM_WORDS = {
    "tamam",
    "tamama",
    "tamamdir",
    "tamamdır",
    "olur",
    "onayla",
}

last_command = None
last_command_time = 0

pending_command = None
pending_phrase = None
pending_time = 0

_aks_sock = None


# ============================================================
# AKS SOCKET
# ============================================================

def _connect_aks():
    global _aks_sock

    try:
        s = _socket.socket(_socket.AF_UNIX, _socket.SOCK_STREAM)
        s.connect(AKS_SOCKET_PATH)
        _aks_sock = s
        print(f"[AKS] Baglanti kuruldu: {AKS_SOCKET_PATH}")
    except Exception as e:
        _aks_sock = None
        print(f"[AKS] Baglanti yok: {e}")


def _send_command(cmd: str):
    global _aks_sock

    if _aks_sock is None:
        _connect_aks()

    if _aks_sock is None:
        return

    try:
        _aks_sock.setblocking(False)
        _aks_sock.sendall((cmd + "\n").encode("utf-8"))
    except BlockingIOError:
        print("[AKS] Soket mesgul, komut atildi")
    except Exception as e:
        print(f"[AKS] Gonderim hatasi, yeniden baglaniliyor: {e}")
        try:
            _aks_sock.close()
        except Exception:
            pass
        _aks_sock = None


# ============================================================
# SES VE METIN FONKSIYONLARI
# ============================================================

def normalize(text):
    text = text.lower().strip()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))

    text = text.replace("ı", "i")
    text = text.replace("ğ", "g")
    text = text.replace("ü", "u")
    text = text.replace("ş", "s")
    text = text.replace("ö", "o")
    text = text.replace("ç", "c")

    for ch in [".", ",", "!", "?", ":", ";", "-", "_", "\"", "'", "\u2019"]:
        text = text.replace(ch, " ")

    return " ".join(text.split())


def safe_put_audio(data):
    try:
        audio_queue.put_nowait(data)
    except queue.Full:
        try:
            audio_queue.get_nowait()
        except queue.Empty:
            pass

        try:
            audio_queue.put_nowait(data)
        except queue.Full:
            pass


def callback(indata, frames, time_info, status):
    if status:
        print("Ses uyarisi:", status, file=sys.stderr)

    safe_put_audio(bytes(indata))


def audio_rms(data):
    samples = np.frombuffer(data, dtype=np.int16)

    if samples.size == 0:
        return 0.0

    return float(np.sqrt(np.mean(samples.astype(np.float32) ** 2)))


def process_audio_48k(data):
    """
    48 kHz ham mikrofon sesini işler.

    Bu sürüm:
    - DC offset temizler
    - Otomatik gain uygular
    - Çok yüksek sesi limiter ile sınırlar
    - 48 kHz -> 16 kHz dönüştürür
    - Noise gate kullanmaz
    """

    samples = np.frombuffer(data, dtype=np.int16).astype(np.float32)

    if samples.size == 0:
        return data, 0.0, 0.0, 1.0

    raw_rms = float(np.sqrt(np.mean(samples ** 2)))

    # DC offset temizleme
    samples = samples - np.mean(samples)

    clean_rms = float(np.sqrt(np.mean(samples ** 2)))

    # Otomatik gain
    if clean_rms > 1.0:
        auto_gain = TARGET_RMS / clean_rms
    else:
        auto_gain = 1.0

    total_gain = BASE_GAIN * auto_gain

    if total_gain > MAX_TOTAL_GAIN:
        total_gain = MAX_TOTAL_GAIN

    if total_gain < 1.0:
        total_gain = 1.0

    samples *= total_gain

    # Soft limiter
    peak = float(np.max(np.abs(samples))) if samples.size else 0.0

    if peak > LIMITER_LEVEL:
        samples *= LIMITER_LEVEL / peak

    samples = np.clip(samples, -32768, 32767)

    # 48 kHz -> 16 kHz
    resampled = resample_poly(samples, up=1, down=3)
    resampled = np.clip(resampled, -32768, 32767)

    out = resampled.astype(np.int16).tobytes()

    return out, raw_rms, clean_rms, total_gain


def get_words(result):
    words = []

    for item in result.get("result", []):
        word = normalize(item.get("word", ""))
        conf = float(item.get("conf", 0.0))

        if word:
            words.append((word, conf))

    return words


def average_conf(items):
    if not items:
        return 0.0

    return sum(conf for _, conf in items) / len(items)


def cooldown_ok(command):
    global last_command, last_command_time

    now = time.time()

    if last_command == command and now - last_command_time < COOLDOWN_SECONDS:
        return False

    last_command = command
    last_command_time = now
    return True


# ============================================================
# KOMUT ALGILAMA
# ============================================================

def has_strong_tamam(words):
    for word, conf in words:
        if word in TAMAM_WORDS and conf >= MIN_TAMAM_CONF:
            return True, word, conf

    return False, None, 0.0


def find_command_before_tamam(words):
    """
    Aynı Vosk sonucunda 'komut tamam' geldiyse bulur.
    """

    last_candidate = None

    for i, (word, tamam_conf) in enumerate(words):
        if word not in TAMAM_WORDS:
            continue

        if tamam_conf < MIN_TAMAM_CONF:
            continue

        before = words[:i]

        for n in [5, 4, 3, 2, 1]:
            if len(before) < n:
                continue

            candidate_items = before[-n:]
            phrase = " ".join(w for w, _ in candidate_items)
            cmd_conf = average_conf(candidate_items)

            if phrase in COMMAND_ALIASES and cmd_conf >= MIN_CMD_CONF:
                last_candidate = {
                    "command": COMMAND_ALIASES[phrase],
                    "phrase": phrase,
                    "cmd_conf": cmd_conf,
                    "tamam_conf": tamam_conf,
                    "mode": "komut_tamam_ayni_sonuc",
                }
                break

    return last_candidate


def find_command_only(words):
    """
    Sadece komut geldiyse yakalar.
    Komutu hemen çalıştırmaz.
    Hafızaya alır ve tamam bekler.
    """

    if not words:
        return None

    word_list = [w for w, _ in words]

    # Sadece tamam varsa komut sayma
    if all(w in TAMAM_WORDS for w in word_list):
        return None

    aliases = sorted(COMMAND_ALIASES.items(), key=lambda x: len(x[0]), reverse=True)

    for phrase, cmd in aliases:
        phrase_norm = normalize(phrase)
        phrase_words = phrase_norm.split()
        n = len(phrase_words)

        if len(words) < n:
            continue

        # Cümle içinde kaydırmalı arama
        for start in range(0, len(words) - n + 1):
            part = words[start:start + n]
            part_words = [w for w, _ in part]

            if part_words == phrase_words:
                cmd_conf = average_conf(part)

                if cmd_conf >= MIN_CMD_CONF:
                    return {
                        "command": cmd,
                        "phrase": phrase_norm,
                        "cmd_conf": cmd_conf,
                        "mode": "bekleyen_komut",
                    }

    return None


def reset_recognizer(model):
    r = KaldiRecognizer(model, VOSK_SAMPLE_RATE)
    r.SetWords(True)
    return r


def find_input_device():
    devices = sd.query_devices()

    print()
    print("Ses cihazlari:")
    print(devices)
    print()

    for idx, dev in enumerate(devices):
        name = dev.get("name", "")
        max_input_channels = dev.get("max_input_channels", 0)

        if max_input_channels > 0 and PREFERRED_DEVICE_KEYWORD.lower() in name.lower():
            print(f"Secilen giris cihazi: index={idx}, name={name}")
            return idx

    print("USB PnP giris cihazi otomatik bulunamadi. Default input kullanilacak.")
    return None


def print_selected_command(selected):
    print(
        f"KOMUT KABUL  : {selected['command']} | "
        f"ifade='{selected['phrase']} tamam' | "
        f"mod={selected['mode']} | "
        f"komut_guven={selected['cmd_conf']:.2f} | "
        f"tamam_guven={selected['tamam_conf']:.2f}"
    )


def print_start_info():
    print("Komut dinleme basladi.")
    print()
    print("Mikrofon girisi : 48 kHz")
    print("Vosk girisi     : 16 kHz")
    print(f"Base gain       : {BASE_GAIN}")
    print(f"Target RMS      : {TARGET_RMS}")
    print(f"Max total gain  : {MAX_TOTAL_GAIN}")
    print("Noise gate      : KAPALI")
    print("RMS filtre      : KAPALI")
    print(f"Min komut conf  : {MIN_CMD_CONF}")
    print(f"Min tamam conf  : {MIN_TAMAM_CONF}")
    print()
    print("Calisma mantigi:")
    print("  1. Komutu soyle: evet / hayir / kol / bacak / devam")
    print("  2. Ardindan 4 sn icinde 'tamam' de")
    print()
    print("Ornek:")
    print("  evet tamam")
    print("  kol tamam")
    print("  acil durum tamam")
    print("-" * 60)


# ============================================================
# BASLANGIC
# ============================================================

if not os.path.exists(MODEL_PATH):
    print("HATA: model-tr klasoru bulunamadi.")
    sys.exit(1)

print("Vosk modeli yukleniyor...")
model = Model(MODEL_PATH)
recognizer = reset_recognizer(model)

input_device = find_input_device()

_connect_aks()
print_start_info()

try:
    with sd.RawInputStream(
        device=input_device,
        samplerate=INPUT_SAMPLE_RATE,
        blocksize=BLOCK_SIZE,
        dtype="int16",
        channels=1,
        callback=callback,
    ):
        while True:
            raw_data = audio_queue.get()

            data, raw_rms, clean_rms, total_gain = process_audio_48k(raw_data)
            rms = audio_rms(data)

            # Her blok Vosk'a gönderilir
            if recognizer.AcceptWaveform(data):
                result = json.loads(recognizer.Result())
                text = result.get("text", "").strip()

                if not text:
                    continue

                words = get_words(result)
                now_str = datetime.datetime.now().strftime("%H:%M:%S")
                now_ts = time.time()

                print(f"[{now_str}] Algilanan : {text}")
                print(f"Normalize    : {normalize(text)}")
                print(f"Raw RMS      : {raw_rms:.0f}")
                print(f"Clean RMS    : {clean_rms:.0f}")
                print(f"Vosk RMS     : {rms:.0f}")
                print(f"Total Gain   : {total_gain:.1f}x")

                if words:
                    debug = " | ".join([f"{w}:{c:.2f}" for w, c in words])
                    print("Kelimeler    :", debug)
                else:
                    print("Kelimeler    : yok")

                # 1. Aynı sonuç içinde "komut tamam" geldiyse direkt çalıştır
                selected = find_command_before_tamam(words)

                if selected:
                    pending_command = None
                    pending_phrase = None
                    pending_time = 0

                    command = selected["command"]

                    if cooldown_ok(command):
                        print_selected_command(selected)
                        _send_command(command)
                    else:
                        print(f"KOMUT BEKLETILDI: {command} | cooldown aktif")

                    print("-" * 60)
                    continue

                # 2. Sadece "tamam" geldiyse bekleyen komutu onayla
                tamam_ok, tamam_word, tamam_conf = has_strong_tamam(words)

                if tamam_ok and pending_command is not None:
                    if now_ts - pending_time <= PENDING_CONFIRM_SECONDS:
                        command = pending_command

                        if cooldown_ok(command):
                            print(
                                f"KOMUT ONAYLANDI: {command} | "
                                f"onceki_ifade='{pending_phrase}' | "
                                f"onay='{tamam_word}' | "
                                f"tamam_guven={tamam_conf:.2f}"
                            )
                            _send_command(command)
                        else:
                            print(f"KOMUT BEKLETILDI: {command} | cooldown aktif")

                        pending_command = None
                        pending_phrase = None
                        pending_time = 0

                    else:
                        print("REDDEDILDI   | bekleyen komutun suresi doldu")

                        pending_command = None
                        pending_phrase = None
                        pending_time = 0

                    print("-" * 60)
                    continue

                # 3. Sadece tamam geldiyse ama bekleyen komut yoksa reddet
                if tamam_ok and pending_command is None:
                    print("REDDEDILDI   | sadece tamam geldi, bekleyen komut yok")
                    print("-" * 60)
                    continue

                # 4. Sadece komut geldiyse hafızaya al, çalıştırma
                command_candidate = find_command_only(words)

                if command_candidate:
                    pending_command = command_candidate["command"]
                    pending_phrase = command_candidate["phrase"]
                    pending_time = now_ts

                    print(
                        f"KOMUT HAZIR  : {pending_command} | "
                        f"ifade='{pending_phrase}' | "
                        f"komut_guven={command_candidate['cmd_conf']:.2f} | "
                        f"{PENDING_CONFIRM_SECONDS:.0f} sn icinde 'tamam' bekleniyor"
                    )

                else:
                    if pending_command is not None and now_ts - pending_time > PENDING_CONFIRM_SECONDS:
                        pending_command = None
                        pending_phrase = None
                        pending_time = 0
                        print("REDDEDILDI   | bekleyen komut temizlendi")
                    else:
                        print("REDDEDILDI   | gecerli komut yok")

                print("-" * 60)

except KeyboardInterrupt:
    print()
    print("Cikis yapildi.")

except Exception as e:
    print()
    print("HATA:", e)
    print()
    print("Kontrol et:")
    print("1. Mikrofon baska program tarafindan kullaniliyor mu?")
    print("2. USB ses karti dogru porta takili mi?")
    print("3. scipy kurulu mu? sudo apt install -y python3-scipy")
