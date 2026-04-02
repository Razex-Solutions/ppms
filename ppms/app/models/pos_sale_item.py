from sqlalchemy import Column, Float, ForeignKey, Integer
from sqlalchemy.orm import relationship

from app.models.base import Base


class POSSaleItem(Base):
    __tablename__ = "pos_sale_items"

    id = Column(Integer, primary_key=True, index=True)
    sale_id = Column(Integer, ForeignKey("pos_sales.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("pos_products.id"), nullable=False)
    quantity = Column(Float, nullable=False)
    unit_price = Column(Float, nullable=False)
    line_total = Column(Float, nullable=False)

    sale = relationship("POSSale")
    product = relationship("POSProduct")
