if (-Not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example. Edit MAIN_SERVER_IP and SERVER_ID, then rerun."
    exit 1
}

Write-Host "Starting CPU-safe remote collector only."
Write-Host "GPU collection is intentionally skipped on Windows/CPU machines."
docker compose up -d
