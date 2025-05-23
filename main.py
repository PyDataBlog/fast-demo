from typing import Optional

from fastapi import FastAPI
from pydantic import BaseModel


class Item(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    tax: Optional[float] = None


app = FastAPI(title="Main API", root_path="/api")


@app.get("/")
async def read_root():
    return {"message": "Hello World from Main API"}


@app.post("/items/")
async def create_item(item: Item):
    return item


sub_api = FastAPI(title="Sub API")


@sub_api.get("/")
async def read_sub_index():
    return {"message": "Hello World from Sub API Index"}


@sub_api.get("/sub")
async def read_sub_root():
    return {"message": "Hello World from Sub API"}


app.mount("/v21", sub_api)
