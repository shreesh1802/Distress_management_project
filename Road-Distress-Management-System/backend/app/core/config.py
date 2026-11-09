"""
Settings configuration module for the Road Distress Management System.
Uses pydantic-settings to manage environment variables.
"""

from typing import List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Application settings class backing environment configurations.
    """
    PROJECT_NAME: str = "Road Distress Management System"
    API_V1_STR: str = "/api/v1"
    
    # CORS Origins (Comma separated string in environment)
    BACKEND_CORS_ORIGINS: str = "*"

    # Database Configurations
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "postgres"
    POSTGRES_DB: str = "road_distress_db"
    POSTGRES_PORT: str = "5432"
    
    DATABASE_URL: str | None = None

    # Firebase Admin (Google sign-in, see app/services/firebase_service.py).
    # Local dev: path to the service-account JSON. Hosted (Railway): paste
    # the JSON itself into FIREBASE_CREDENTIALS_JSON instead.
    FIREBASE_CREDENTIALS_PATH: str | None = None
    FIREBASE_CREDENTIALS_JSON: str | None = None

    @property
    def sqlalchemy_database_uri(self) -> str:
        """
        Generates the SQLAlchemy database connection URI.
        """
        if self.DATABASE_URL:
            return self.DATABASE_URL
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    # Pydantic settings configuration dict
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )


settings = Settings()
