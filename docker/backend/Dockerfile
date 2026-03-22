FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc libpango-1.0-0 libcairo2 netcat-openbsd libgdk-pixbuf-xlib-2.0-0 libffi-dev && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


COPY . .
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh                                                                      
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 8000

CMD ["daphne", "config.asgi:application", "-b", "0.0.0.0", "-p", "8000"]
