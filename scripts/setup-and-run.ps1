# Setup virtualenv, install deps and run docker-compose for local dev (Windows PowerShell)
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r app/requirements.txt
docker-compose up --build
