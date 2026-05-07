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
from vosk import Model, KaldiRecognizer, SetLogLevel

SetLogLevel(-1)

MODEL_PATH = "model-tr"

SAMPLE_RATE = 16000
BLOCK_SIZE  = 4000

MAX_QUEUE_BLOCKS = 4

MIN_RMS        = 200   # Pi'de harici mikrofonla 450 yap
MIN_CMD_CONF   = 0.70
MIN_TAMAM_CONF = 0.80

COOLDOWN_SECONDS = 1.0

AKS_SOCKET_PATH = "/tmp/aks_voice"

audio_queue = queue.Queue(maxsize=MAX_QUEUE_BLOCKS)

# ── Komut eşleme tablosu ──────────────────────────────────────────────────────
# Format: "normalize edilmiş ifade" → "KOMUT_KODU"
# Tüm komutlar "tamam" sözcüğüyle onaylanır: "evet tamam", "kol tamam" gibi.
COMMAND_ALIASES = {
    # Genel onay / ret
    "evet":                 "EVET",
    "hayir":                "HAYIR",

    # Kanama bölgesi seçimi (QuestionScreen)
    "kol":                  "KOL",
    "bacak":                "BACAK",
    "vucut":                "VUCUT",
    "govde":                "VUCUT",

    # Navigasyon
    "geri":                 "GERI",
    "ileri":                "ILERI",
    "devam":                "DEVAM_ET",
    "devam et":             "DEVAM_ET",
    "ana sayfa":            "ANA_SAYFA",
    "anasayfa":             "ANA_SAYFA",

    # Acil başlatma
    "acil":                 "ACIL_DURUM",
    "acil durum":           "ACIL_DURUM",

    # Yardım / ayarlar
    "yardim":               "YARDIM",
    "yardim et":            "YARDIM",
    "yardim edin":          "YARDIM",
    "ayarlar":              "AYARLAR",

    # Dil
    "turkce":               "TURKCE",
    "ingilizce":            "INGILIZCE",

    # Kayıtlar
    "veritabani":           "VERITABANI",
    "veri tabani":          "VERITABANI",
    "veri kaydini sil":     "VERI_KAYDINI_SIL",
    "kaydi sil":            "VERI_KAYDINI_SIL",
    "kayit sil":            "VERI_KAYDINI_SIL",

    # Ambulans
    "ambulans ara":         "AMBULANS_ARA",
    "yuz on iki ara":       "AMBULANS_ARA",
    "on iki ara":           "AMBULANS_ARA",
    "yuz oniki ara":        "AMBULANS_ARA",
}

last_command      = None
last_command_time = 0

# ── AKS socket bağlantısı ─────────────────────────────────────────────────────
_aks_sock = None


def _connect_aks():
    global _aks_sock
    try:
        s = _socket.socket(_socket.AF_UNIX, _socket.SOCK_STREAM)
        s.connect(AKS_SOCKET_PATH)
        _aks_sock = s
        print(f"[AKS] Baglanti kuruldu: {AKS_SOCKET_PATH}")
    except Exception as e:
        _aks_sock = None
        print(f"[AKS] Baglanti yok (AKS calismiyor olabilir): {e}")


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


# ── Ses yardımcıları ──────────────────────────────────────────────────────────

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
    last_command      = command
    last_command_time = now
    return True


def find_last_command_by_tamam(words):
    """
    'komut + tamam' desenini arar. Birden fazla eşleşme varsa sonuncusu alınır.
    """
    last_candidate = None

    for i, (word, tamam_conf) in enumerate(words):
        if word != "tamam":
            continue
        if tamam_conf < MIN_TAMAM_CONF:
            continue

        before = words[:i]

        for n in [5, 4, 3, 2, 1]:
            if len(before) < n:
                continue
            candidate_items = before[-n:]
            phrase          = " ".join(w for w, _ in candidate_items)
            cmd_conf        = average_conf(candidate_items)
            if phrase in COMMAND_ALIASES and cmd_conf >= MIN_CMD_CONF:
                last_candidate = {
                    "command":    COMMAND_ALIASES[phrase],
                    "phrase":     phrase,
                    "cmd_conf":   cmd_conf,
                    "tamam_conf": tamam_conf,
                    "position":   i,
                }
                break

    return last_candidate


def reset_recognizer(model):
    r = KaldiRecognizer(model, SAMPLE_RATE)
    r.SetWords(True)
    return r


# ── Başlangıç ─────────────────────────────────────────────────────────────────
if not os.path.exists(MODEL_PATH):
    print("HATA: model-tr klasoru bulunamadi.")
    sys.exit(1)

print("Vosk modeli yukleniyor...")
model      = Model(MODEL_PATH)
recognizer = reset_recognizer(model)

_connect_aks()

print("Komut dinleme basladi.")
print()
print("Komut formati:  <komut> tamam")
print("Ornekler:")
print("  evet tamam | hayir tamam")
print("  kol tamam  | bacak tamam | vucut tamam")
print("  geri tamam | ana sayfa tamam | acil durum tamam")
print("-" * 60)

silence_blocks = 0

with sd.RawInputStream(
    samplerate=SAMPLE_RATE,
    blocksize=BLOCK_SIZE,
    dtype="int16",
    channels=1,
    callback=callback,
):
    while True:
        data = audio_queue.get()
        rms  = audio_rms(data)

        if rms < MIN_RMS:
            silence_blocks += 1
            if silence_blocks >= 6:
                recognizer     = reset_recognizer(model)
                silence_blocks = 0
            continue

        silence_blocks = 0

        if recognizer.AcceptWaveform(data):
            result = json.loads(recognizer.Result())
            text   = result.get("text", "").strip()

            if not text:
                continue

            words = get_words(result)
            now   = datetime.datetime.now().strftime("%H:%M:%S")

            print(f"[{now}] Algilanan: {text}")
            print(f"Normalize   : {normalize(text)}")
            print(f"RMS         : {rms:.0f}")

            if words:
                debug = " | ".join([f"{w}:{c:.2f}" for w, c in words])
                print("Kelimeler   :", debug)

            selected = find_last_command_by_tamam(words)

            if selected:
                command = selected["command"]
                if cooldown_ok(command):
                    print(
                        f"KOMUT KABUL : {command} | "
                        f"ifade='{selected['phrase']} tamam' | "
                        f"komut_guven={selected['cmd_conf']:.2f} | "
                        f"tamam_guven={selected['tamam_conf']:.2f}"
                    )
                    _send_command(command)
                else:
                    print(f"KOMUT BEKLETILDI: {command} | cooldown aktif")
            else:
                print("REDDEDILDI  | gecerli 'komut + tamam' yok")

            print("-" * 60)
