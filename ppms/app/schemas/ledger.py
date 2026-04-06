from datetime import datetime

from pydantic import BaseModel, ConfigDict


class LedgerEntryResponse(BaseModel):
    date: datetime
    type: str
    amount: float
    description: str
    reference: str | None = None
    balance: float


class LedgerSummaryResponse(BaseModel):
    party_id: int
    party_type: str
    party_name: str
    party_code: str | None = None
    station_id: int | None = None
    station_name: str | None = None
    total_charges: float
    total_payments: float
    current_balance: float
    transaction_count: int
    last_activity_at: datetime | None = None


class LedgerResponse(BaseModel):
    party_id: int
    party_type: str
    party_name: str
    party_code: str | None = None
    station_id: int | None = None
    station_name: str | None = None
    summary: LedgerSummaryResponse
    ledger: list[LedgerEntryResponse]

    model_config = ConfigDict(from_attributes=True)
