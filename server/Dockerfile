FROM amazonlinux

WORKDIR /app

COPY requirements.txt .

RUN python3 -m venv .venv
RUN .venv/bin/pip install -r requirements.txt

COPY server.py .

CMD [".venv/bin/gunicorn", "--bind", "0.0.0.0:80", "--workers", "2", "server:app"]
