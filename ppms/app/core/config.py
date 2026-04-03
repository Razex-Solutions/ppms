import os


DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./ppms.db")
SECRET_KEY = os.getenv("SECRET_KEY", "ppms-secret-key-change-in-production")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "480"))
ENABLED_MODULES = os.getenv("ENABLED_MODULES", "*")
APP_ENV = os.getenv("APP_ENV", "development")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
DELIVERY_MODE = os.getenv("DELIVERY_MODE", "mock").lower()
SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME = os.getenv("SMTP_USERNAME", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_FROM_EMAIL = os.getenv("SMTP_FROM_EMAIL", "")
SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_SMS_FROM = os.getenv("TWILIO_SMS_FROM", "")
TWILIO_WHATSAPP_FROM = os.getenv("TWILIO_WHATSAPP_FROM", "")
DELIVERY_WORKER_ENABLED = os.getenv("DELIVERY_WORKER_ENABLED", "false").lower() == "true"
DELIVERY_WORKER_INTERVAL_SECONDS = int(os.getenv("DELIVERY_WORKER_INTERVAL_SECONDS", "30"))
BACKUP_DIRECTORY = os.getenv("BACKUP_DIRECTORY", "./backups")
ONLINE_HOOKS_MODE = os.getenv("ONLINE_HOOKS_MODE", "mock").lower()
