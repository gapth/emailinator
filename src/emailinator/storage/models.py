from sqlalchemy.orm import declarative_base
from sqlalchemy import Column, Integer, String, Date, Text

Base = declarative_base()

class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user = Column(String(255), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    due_date = Column(Date, nullable=True)
    consequence_if_ignore = Column(Text, nullable=True)
    parent_action = Column(
        String(20),
        nullable=True
    )  # ENUM: "NONE", "SUBMIT", "SIGN", "PAY", "PURCHASE", "ATTEND", "TRANSPORT", "VOLUNTEER", "OTHER"
    parent_requirement_level = Column(
        String(25),
        nullable=True
    )  # ENUM: "NONE", "OPTIONAL", "VOLUNTEER_OPPORTUNITY", "MANDATORY"
    student_action = Column(
        String(20),
        nullable=True
    )  # ENUM: "NONE", "SUBMIT", "ATTEND", "SETUP", "BRING", "PREPARE", "WEAR", "COLLECT", "OTHER"
    student_requirement_level = Column(
        String(25),
        nullable=True
    )  # ENUM: "NONE", "OPTIONAL", "VOLUNTEER_OPPORTUNITY", "MANDATORY"
    status = Column(String(50), default="pending")

    def __repr__(self):
        return f"<Task id={self.id} title={self.title} status={self.status}>"


class User(Base):
    """Simple user account identified by an API key."""

    __tablename__ = "users"

    username = Column(String(255), primary_key=True)
    api_key = Column(String(255), nullable=False)
