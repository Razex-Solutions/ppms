from pydantic import BaseModel, ConfigDict


class StationModuleSettingUpdate(BaseModel):
    module_name: str
    is_enabled: bool


class StationModuleSettingResponse(BaseModel):
    id: int
    station_id: int
    module_name: str
    is_enabled: bool

    model_config = ConfigDict(from_attributes=True)
