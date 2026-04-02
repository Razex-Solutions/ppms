from pydantic import BaseModel, ConfigDict
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

    model_config = ConfigDict(from_attributes=True)
