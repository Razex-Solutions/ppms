from pydantic import BaseModel, ConfigDict


class OrganizationModuleSettingUpdate(BaseModel):
    module_name: str
    is_enabled: bool


class OrganizationModuleSettingResponse(BaseModel):
    id: int
    organization_id: int
    module_name: str
    is_enabled: bool

    model_config = ConfigDict(from_attributes=True)
