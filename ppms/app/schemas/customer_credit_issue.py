from datetime import datetime

from pydantic import BaseModel, ConfigDict


class CustomerCreditIssueResponse(BaseModel):
    id: int
    customer_id: int
    station_id: int
    shift_id: int | None = None
    amount: float
    notes: str | None = None
    created_by_user_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
