"""Settings come from environment variables (ConfigMap + Secret in Kubernetes)."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    log_level: str = "INFO"
    # either a full URL ...
    database_url: str | None = None
    # ... or its parts (the password comes from a Secret, the rest from a ConfigMap)
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "shelfshare"
    db_user: str = "shelfshare"
    db_password: str = ""
    cors_origins: str = "*"
    build_sha: str = "local"

    @property
    def sqlalchemy_url(self) -> str:
        if self.database_url:
            return self.database_url
        return (f"postgresql+psycopg://{self.db_user}:{self.db_password}"
                f"@{self.db_host}:{self.db_port}/{self.db_name}")


@lru_cache
def get_settings() -> Settings:
    return Settings()
