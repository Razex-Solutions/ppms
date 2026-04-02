import os


DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./ppms.db")
SECRET_KEY = os.getenv("SECRET_KEY", "ppms-secret-key-change-in-production")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "480"))
ENABLED_MODULES = os.getenv("ENABLED_MODULES", "*")
APP_ENV = os.getenv("APP_ENV", "development")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
