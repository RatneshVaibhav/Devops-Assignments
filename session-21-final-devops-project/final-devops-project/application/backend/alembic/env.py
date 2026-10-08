"""Alembic environment. The database URL comes from the app settings, never from alembic.ini."""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, text

from app.config import get_settings
from app.db import Base
from app import models  # noqa: F401  (registers the tables on Base.metadata)

config = context.config
if config.config_file_name:
    fileConfig(config.config_file_name)

# several backend replicas start at once and each runs `alembic upgrade head`;
# a Postgres advisory lock makes them take turns instead of racing
MIGRATION_LOCK_ID = 2026_10_21


def run_migrations_online():
    engine = create_engine(get_settings().sqlalchemy_url)
    with engine.connect() as connection:
        locking = connection.dialect.name == "postgresql"
        if locking:
            connection.execute(text("SELECT pg_advisory_lock(:id)"), {"id": MIGRATION_LOCK_ID})
            connection.commit()
        try:
            context.configure(connection=connection, target_metadata=Base.metadata)
            with context.begin_transaction():
                context.run_migrations()
        finally:
            if locking:
                connection.execute(text("SELECT pg_advisory_unlock(:id)"), {"id": MIGRATION_LOCK_ID})
                connection.commit()


run_migrations_online()
