from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Condition = Literal["new", "good", "fair", "worn"]
Status = Literal["available", "reserved", "exchanged"]


class BookCreate(BaseModel):
    title: str = Field(min_length=2, max_length=120)
    author: str = Field(min_length=2, max_length=80)
    course_code: str = Field(pattern=r"^[A-Z]{2,4}[0-9]{3}$", examples=["CS301"])
    condition: Condition = "good"
    owner_name: str = Field(min_length=2, max_length=60)


class BookUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=120)
    author: str | None = Field(default=None, min_length=2, max_length=80)
    course_code: str | None = Field(default=None, pattern=r"^[A-Z]{2,4}[0-9]{3}$")
    condition: Condition | None = None
    status: Status | None = None


class Reservation(BaseModel):
    reserved_by: str = Field(min_length=2, max_length=60)


class BookOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    author: str
    course_code: str
    condition: str
    owner_name: str
    status: str
    reserved_by: str | None
    created_at: datetime
    updated_at: datetime


class Stats(BaseModel):
    total: int
    by_status: dict[str, int]
    top_courses: list[dict]
