from sqlalchemy.orm import declarative_base
from sqlalchemy import Column, Integer, String, Date, Text

Base = declarative_base()

class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    due_date = Column(Date, nullable=True)
    status = Column(String(50), default="pending")

    def __repr__(self):
        return f"<Task id={self.id} title={self.title} status={self.status}>"
