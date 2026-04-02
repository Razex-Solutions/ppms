from pydantic import BaseModel
from datetime import datetime


class NozzleReadingBase(BaseModel):
    nozzle_id: int
    reading: float
    sale_id: int | None = None


class NozzleReadingCreate(NozzleReadingBase):
    pass


class NozzleReadingResponse(NozzleReadingBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True
