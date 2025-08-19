from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from .models import Base

DB_URL = "sqlite:///tasks.db"
engine = create_engine(DB_URL, echo=False, future=True)
SessionLocal = sessionmaker(bind=engine)


def init_db():
    # Drop existing tables to ensure schema matches models (useful during tests)
    # Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
