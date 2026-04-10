from sqlalchemy import Boolean, Column, Float, ForeignKey, Integer, String

from app.models.base import Base


class POSProduct(Base):
    __tablename__ = "pos_products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    code = Column(String, unique=True, nullable=False, index=True)
    category = Column(String, nullable=False)
    module = Column(String, nullable=False)  # mart / service_station / tyre_shop / other
    buying_price = Column(Float, nullable=False, default=0.0)
    price = Column(Float, nullable=False)
    stock_quantity = Column(Float, default=0.0)
    track_inventory = Column(Boolean, default=True, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)
