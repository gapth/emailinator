from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any
from datetime import date

class ITaskDB(ABC):
    """Abstract interface for Task database backends."""

    @abstractmethod
    def add_task(self, title: str, description: Optional[str] = None,
                 due_date: Optional[date] = None, status: str = "pending"):
        pass

    @abstractmethod
    def list_tasks(self) -> List:
        pass

    @abstractmethod
    def update_task(self, task_id: int, updates: Dict[str, Any]) -> bool:
        pass
