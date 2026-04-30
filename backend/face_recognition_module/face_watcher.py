"""
face_watcher.py — Raspberry Pi 4 camera loop with face recognition
Runs continuously, capturing frames and identifying faces.
Uploads unknown faces to the FastAPI backend.

Requirements (install on RPi):
  pip install face_recognition picamera2 requests Pillow numpy

Run: python face_watcher.py
"""
import io
import os
import pickle
import time
import requests
import numpy as np
from datetime import datetime
from PIL import Image

# ─── Config ──────────────────────────────────────────────────────────────────────
API_URL = os.getenv("API_URL", "http://localhost:8000")
BACKEND_TOKEN = os.getenv("BACKEND_TOKEN", "")  # Internal token for RPi → API
FACE_TOLERANCE = float(os.getenv("FACE_RECOGNITION_TOLERANCE", 0.5))
CAPTURE_INTERVAL = 1.5   # seconds between captures
DOOR_OPEN_DURATION = 5   # seconds door stays unlocked after face match

import RPi.GPIO as GPIO
from picamera2 import Picamera2
import face_recognition

DOOR_GPIO_PIN = int(os.getenv("DOOR_GPIO_PIN", 18))
GPIO.setmode(GPIO.BCM)
GPIO.setup(DOOR_GPIO_PIN, GPIO.OUT)
GPIO.output(DOOR_GPIO_PIN, GPIO.LOW)  # Start locked


# ─── Helpers ─────────────────────────────────────────────────────────────────────

def load_known_faces() -> tuple[list, list]:
    """Load all authorized persons' face encodings from the backend."""
    try:
        resp = requests.get(f"{API_URL}/persons", timeout=5)
        persons = resp.json()
    except Exception as e:
        print(f"[ERROR] Cannot load persons: {e}")
        return [], []

    known_encodings = []
    known_names = []
    for person in persons:
        # Fetch the encoding from local DB (we stored it as binary)
        # In production, you'd load from local DB using SQLAlchemy
        pass  # handled via direct DB access below

    # Direct DB access for encodings (faster than API)
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    import sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from database import AuthorizedPerson, Base

    engine = create_engine("sqlite:///./smart_door.db", connect_args={"check_same_thread": False})
    Session = sessionmaker(bind=engine)
    db = Session()

    persons_db = db.query(AuthorizedPerson).all()
    for p in persons_db:
        if p.face_encoding:
            encoding = pickle.loads(p.face_encoding)
            known_encodings.append(encoding)
            known_names.append(p.name)

    db.close()
    print(f"[FACES] Loaded {len(known_names)} known faces: {known_names}")
    return known_encodings, known_names


def unlock_door():
    GPIO.output(DOOR_GPIO_PIN, GPIO.HIGH)
    time.sleep(DOOR_OPEN_DURATION)
    GPIO.output(DOOR_GPIO_PIN, GPIO.LOW)
    print("[DOOR] Locked again")


def send_alert(image_bytes: bytes):
    """Upload unauthorized visitor image to FastAPI backend."""
    try:
        files = {"file": ("visitor.jpg", image_bytes, "image/jpeg")}
        resp = requests.post(
            f"{API_URL}/alerts/from-camera",
            files=files,
            timeout=10,
        )
        print(f"[ALERT] Sent to backend: {resp.status_code}")
    except Exception as e:
        print(f"[ERROR] Failed to send alert: {e}")


# ─── Main Loop ───────────────────────────────────────────────────────────────────

def main():
    print("[STARTUP] Smart Door Face Watcher starting...")

    picam2 = Picamera2()
    picam2.configure(picam2.create_still_configuration(main={"size": (640, 480)}))
    picam2.start()

    # Reload known faces every 5 minutes
    known_encodings, known_names = load_known_faces()
    last_reload = time.time()
    RELOAD_INTERVAL = 300  # 5 minutes

    alert_cooldown = {}  # prevent spam alerts

    try:
        while True:
            # Reload faces periodically
            if time.time() - last_reload > RELOAD_INTERVAL:
                known_encodings, known_names = load_known_faces()
                last_reload = time.time()

            # Capture frame
            frame = picam2.capture_array()
            rgb_frame = frame[:, :, ::-1]  # BGR → RGB

            # Detect faces
            face_locations = face_recognition.face_locations(rgb_frame)
            if not face_locations:
                time.sleep(CAPTURE_INTERVAL)
                continue

            face_encodings = face_recognition.face_encodings(rgb_frame, face_locations)

            for face_encoding in face_encodings:
                matches = face_recognition.compare_faces(known_encodings, face_encoding, tolerance=FACE_TOLERANCE)
                distances = face_recognition.face_distance(known_encodings, face_encoding)

                if True in matches:
                    best_idx = np.argmin(distances)
                    name = known_names[best_idx]
                    print(f"[✅ AUTHORIZED] {name} — Unlocking door")

                    # Log to backend
                    try:
                        requests.post(f"{API_URL}/door/auto-unlock", json={"person_name": name}, timeout=5)
                    except Exception:
                        pass

                    # Unlock GPIO
                    import threading
                    t = threading.Thread(target=unlock_door, daemon=True)
                    t.start()

                else:
                    now = time.time()
                    cooldown_key = "unknown"
                    if now - alert_cooldown.get(cooldown_key, 0) < 30:
                        print("[SKIP] Alert on cooldown")
                        time.sleep(CAPTURE_INTERVAL)
                        continue

                    print("[⚠️  UNAUTHORIZED] Unknown face — sending alert")
                    alert_cooldown[cooldown_key] = now

                    # Convert frame to JPEG bytes
                    pil_img = Image.fromarray(rgb_frame)
                    buf = io.BytesIO()
                    pil_img.save(buf, format="JPEG", quality=85)
                    send_alert(buf.getvalue())

            time.sleep(CAPTURE_INTERVAL)

    except KeyboardInterrupt:
        print("\n[SHUTDOWN] Face watcher stopped")
    finally:
        picam2.stop()
        GPIO.cleanup()


if __name__ == "__main__":
    main()
