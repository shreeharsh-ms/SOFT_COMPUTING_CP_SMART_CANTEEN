from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    PROJECT_NAME: str = "Smart Canteen Management System"
    VERSION: str = "3.1.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    
    # PostgreSQL Configuration
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "postgres"
    POSTGRES_HOST: str = "localhost"
    POSTGRES_PORT: str = "5432"
    POSTGRES_DB: str = "smart_canteen_db"
    
    DATABASE_URL_OVERRIDE: str = ""
    
    @property
    def DATABASE_URL(self) -> str:
        import os
        from urllib.parse import urlparse, parse_qs, urlencode, urlunparse
        raw_url = self.DATABASE_URL_OVERRIDE or os.environ.get("DATABASE_URL") or os.environ.get("POSTGRES_URL")
        if raw_url:
            url = raw_url
            if url.startswith("postgres://"):
                url = url.replace("postgres://", "postgresql+asyncpg://", 1)
            elif url.startswith("postgresql://"):
                url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
            try:
                u = urlparse(url)
                q = parse_qs(u.query)
                q.pop("channel_binding", None)
                q.pop("sslmode", None)
                new_query = urlencode(q, doseq=True)
                url = urlunparse(u._replace(query=new_query))
            except Exception:
                pass
            return url
        return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    # JWT Authentication Settings
    JWT_SECRET_KEY: str = "7e8a9f2b3c4d5e6f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 Days

    # Worker Thread Pool Settings for CPU-Bound Soft Computing
    WORKER_THREADS: int = 4

    # Firebase Admin Cloud Messaging (FCM) Credentials
    FCM_CREDENTIALS_PATH: str = "firebase-service-account.json"

    # Production CORS Settings: Explicit Allowed Origins (No Wildcards with Credentials)
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:5000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080"
    ]

    def validate_production_secrets(self):
        # Audit Point #13 Hardening: strictly blocks server startup in production if default secrets are used
        if self.ENVIRONMENT == "production":
            if self.JWT_SECRET_KEY == "7e8a9f2b3c4d5e6f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f":
                raise RuntimeError("CRITICAL SECURITY ERROR: Default JWT_SECRET_KEY cannot be used in production environment!")
            if self.POSTGRES_PASSWORD == "postgres":
                raise RuntimeError("CRITICAL SECURITY ERROR: Default POSTGRES_PASSWORD cannot be used in production environment!")

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
settings.validate_production_secrets()
