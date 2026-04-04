from pydantic import BaseModel, ConfigDict


class BrandCatalogResponse(BaseModel):
    id: int
    code: str
    name: str
    logo_url: str | None = None
    primary_color: str | None = None
    sort_order: int
    is_active: bool

    model_config = ConfigDict(from_attributes=True)
