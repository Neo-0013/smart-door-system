"""
routers/door_router.py — Door lock/unlock control + status
"""
from datetime import datetime

import asyncio
from fastapi import APIRouter, Depends, BackgroundTasks
from sqlalchemy.orm import Session

from auth import get_current_user, require_member_or_above
from database import AccessLog, DoorState, User, get_db, SessionLocal
from models import DoorActionRequest, DoorStatusOut
from websocket_manager import manager

router = APIRouter()

# Try to import GPIO (only works on Raspberry Pi)
try:
    import RPi.GPIO as GPIO
    import os
    DOOR_PIN = int(os.getenv("DOOR_GPIO_PIN", 18))
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(DOOR_PIN, GPIO.OUT)
    GPIO_AVAILABLE = True
    print(f"[GPIO] Door pin {DOOR_PIN} initialized")
except (ImportError, RuntimeError):
    GPIO_AVAILABLE = False
    print("[GPIO] RPi.GPIO not available — running in simulation mode")


async def _set_door(db: Session, status: str, user_id: int, user_name: str):
    """Update door state in DB, control GPIO, and broadcast to WebSocket clients."""
    door = db.query(DoorState).filter(DoorState.id == 1).first()
    if door:
        door.status = status
        door.last_updated = datetime.utcnow()
        door.changed_by = user_id
        db.commit()

    if GPIO_AVAILABLE:
        import RPi.GPIO as GPIO
        if status == "unlocked":
            GPIO.output(DOOR_PIN, GPIO.HIGH)
        else:
            GPIO.output(DOOR_PIN, GPIO.LOW)

    await manager.broadcast("door_status", {"status": status, "changed_by": user_name})


async def auto_lock_door(user_id: int, user_name: str, delay: int = 7):
    """Background task to wait `delay` seconds and automatically relock the door."""
    await asyncio.sleep(delay)
    
    # Must use a fresh session because the request session is already closed!
    db = SessionLocal()
    try:
        door = db.query(DoorState).filter(DoorState.id == 1).first()
        if door and door.status == "unlocked":
            await _set_door(db, "locked", user_id, "Auto-Lock (Timer)")
            print(f"[AUTO-LOCK] Door locked automatically after {delay} seconds.")
    finally:
        db.close()


@router.get("/status", response_model=DoorStatusOut)
def door_status(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    door = db.query(DoorState).filter(DoorState.id == 1).first()
    return DoorStatusOut(status=door.status, last_updated=door.last_updated)


@router.post("/unlock")
async def unlock_door(
    background_tasks: BackgroundTasks,
    body: DoorActionRequest = DoorActionRequest(),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member_or_above),
):
    await _set_door(db, "unlocked", current_user.id, current_user.name)

    log = AccessLog(
        person_name=current_user.name,
        type="authorized",
        action="remote_unlock",
        performed_by=current_user.id,
    )
    db.add(log)
    db.commit()
    
    # Start the auto-lock background timer
    background_tasks.add_task(auto_lock_door, current_user.id, current_user.name)
    
    return {"message": "Door unlocked (Will auto-lock in 7s)", "status": "unlocked"}


@router.post("/lock")
async def lock_door(
    body: DoorActionRequest = DoorActionRequest(),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member_or_above),
):
    await _set_door(db, "locked", current_user.id, current_user.name)

    log = AccessLog(
        person_name=current_user.name,
        type="authorized",
        action="remote_lock",
        performed_by=current_user.id,
    )
    db.add(log)
    db.commit()
    return {"message": "Door locked", "status": "locked"}
