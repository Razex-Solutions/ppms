from pydantic import BaseModel, ConfigDict


class OrganizationCreate(BaseModel):
    name: str
    code: str
    description: str | None = None
    is_active: bool = True


class OrganizationUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    description: str | None = None
    is_active: bool | None = None


class OrganizationResponse(BaseModel):
    id: int
    name: str
    code: str
    description: str | None = None
    is_active: bool

    model_config = ConfigDict(from_attributes=True)
