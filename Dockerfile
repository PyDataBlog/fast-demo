FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1

RUN pip install uv

WORKDIR /app

COPY pyproject.toml .

RUN uv pip install --system .

COPY main.py .

EXPOSE 8000


CMD ["fastapi", "run", "main.py"]
