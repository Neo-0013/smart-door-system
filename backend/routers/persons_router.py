"""
routers/persons_router.py — Authorized persons management (add/remove known faces)
"""
import io
import os
import pickle
from typing import List

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from auth import get_current_user, require_admin
from database import AuthorizedPerson, User, get_db
from models import PersonOut

router = APIRouter()

BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")
IMAGES_DIR = os.getenv("IMAGES_DIR", "./images")
KNOWN_FACES_DIR = "./known_faces"


def _person_out(p: AuthorizedPerson) -> PersonOut:
    return PersonOut(
        id=p.id,
        name=p.name,
        photo_url=f"{BASE_URL}/images/{os.path.basename(p.photo_path)}" if p.photo_path else None,
        added_by_name=p.added_by_user.name if p.added_by_user else None,
        added_at=p.added_at,
    )


@router.get("", response_model=List[PersonOut])
def list_persons(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    persons = db.query(AuthorizedPerson).order_by(AuthorizedPerson.added_at.desc()).all()
    return [_person_out(p) for p in persons]


@router.post("", response_model=PersonOut)
async def add_person(
    name: str = Form(...),
    photo: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Add an authorized person. Photo is used to encode their face."""
    os.makedirs(IMAGES_DIR, exist_ok=True)
    os.makedirs(KNOWN_FACES_DIR, exist_ok=True)

    # Save photo
    filename = f"person_{name.lower().replace(' ', '_')}_{int(__import__('time').time())}.jpg"
    filepath = os.path.join(IMAGES_DIR, filename)
    contents = await photo.read()
    with open(filepath, "wb") as f:
        f.write(contents)

    # Try to encode face (only works on RPi with face_recognition installed)
    encoding_bytes = None
    try:
        import face_recognition
        import numpy as np
        from PIL import Image

        img = face_recognition.load_image_file(io.BytesIO(contents))
        encodings = face_recognition.face_encodings(img)
        if encodings:
            encoding_bytes = pickle.dumps(encodings[0])
    except ImportError:
        pass  # face_recognition not available on dev machine

    person = AuthorizedPerson(
        name=name,
        photo_path=filepath,
        face_encoding=encoding_bytes,
        added_by=current_user.id,
    )
    db.add(person)
    db.commit()
    db.refresh(person)
    return _person_out(person)


@router.delete("/{person_id}")
def delete_person(
    person_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    person = db.query(AuthorizedPerson).filter(AuthorizedPerson.id == person_id).first()
    if not person:
        raise HTTPException(status_code=404, detail="Person not found")

    # Delete photo file
    if person.photo_path and os.path.exists(person.photo_path):
        os.remove(person.photo_path)

    db.delete(person)
    db.commit()
    return {"message": f"Removed {person.name} from authorized list"}
