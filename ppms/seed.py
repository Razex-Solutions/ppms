"""
Run once to create the initial admin user and required setup.
Usage: python seed.py
"""
from pathlib import Path

from alembic import command
from alembic.config import Config

from app.core.database import SessionLocal
from app.models.organization import Organization
from app.core.security import hash_password
from app.models.role import Role
from app.models.station import Station
from app.models.user import User


def run_migrations() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    config = Config(str(repo_root / "alembic.ini"))
    config.set_main_option("script_location", str(repo_root / "alembic"))
    command.upgrade(config, "head")


run_migrations()

db = SessionLocal()

# Create default roles
roles_data = [
    {"name": "Admin", "description": "Full system access"},
    {"name": "HeadOffice", "description": "Organization-wide read access"},
    {"name": "Manager", "description": "Station management access"},
    {"name": "Operator", "description": "Daily operations access"},
    {"name": "Accountant", "description": "Financial access only"},
]

for r in roles_data:
    if not db.query(Role).filter(Role.name == r["name"]).first():
        db.add(Role(**r))
db.commit()

admin_role = db.query(Role).filter(Role.name == "Admin").first()

# Create default station
organization = db.query(Organization).filter(Organization.code == "DEFAULT").first()
if not organization:
    organization = Organization(
        name="Default Organization",
        code="DEFAULT",
        description="Default head-office organization",
        is_active=True,
    )
    db.add(organization)
    db.commit()
    db.refresh(organization)

station = db.query(Station).filter(Station.code == "HQ").first()
if not station:
    station = Station(
        name="Main Station",
        code="HQ",
        address="Head Office",
        city="Karachi",
        organization_id=organization.id,
        is_head_office=True,
    )
    db.add(station)
    db.commit()
    db.refresh(station)
elif station.organization_id is None:
    station.organization_id = organization.id
    station.is_head_office = True
    db.commit()

# Create admin user
if not db.query(User).filter(User.username == "admin").first():
    admin = User(
        full_name="System Admin",
        username="admin",
        email="admin@ppms.com",
        hashed_password=hash_password("admin123"),
        is_active=True,
        role_id=admin_role.id,
        station_id=station.id,
    )
    db.add(admin)
    db.commit()
    print("Admin user created: username=admin  password=admin123")
else:
    print("Admin user already exists.")

db.close()
print("Seed complete.")
