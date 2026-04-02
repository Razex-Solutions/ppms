from pydantic import BaseModel, ConfigDict


class StationCreate(BaseModel):
    name: str
    code: str
    address: str | None = None
    city: str | None = None
    organization_id: int
    is_head_office: bool = False


class StationUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    address: str | None = None
    city: str | None = None
    organization_id: int | None = None
    is_head_office: bool | None = None


class StationResponse(BaseModel):
    id: int
    name: str
    code: str
    address: str | None = None
    city: str | None = None
    organization_id: int | None = None
    is_head_office: bool

    model_config = ConfigDict(from_attributes=True)
