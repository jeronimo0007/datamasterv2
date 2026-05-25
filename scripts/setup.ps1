# Script de setup do ambiente de desenvolvimento (PowerShell)

Write-Host "🚀 Configurando ambiente de desenvolvimento..." -ForegroundColor Green

# Verifica Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Python não encontrado. Por favor, instale Python 3.9+" -ForegroundColor Red
    exit 1
}

# Verifica Java
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Java não encontrado. Por favor, instale Java 17+" -ForegroundColor Red
    exit 1
}

# Verifica Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker não encontrado. Por favor, instale Docker" -ForegroundColor Red
    exit 1
}

# Cria ambiente virtual Python
Write-Host "📦 Criando ambiente virtual Python..." -ForegroundColor Yellow
python -m venv venv
.\venv\Scripts\Activate.ps1

# Instala dependências Python
Write-Host "📦 Instalando dependências Python..." -ForegroundColor Yellow
pip install --upgrade pip
pip install -r requirements.txt

# Configura variáveis de ambiente
Write-Host "⚙️  Configurando variáveis de ambiente..." -ForegroundColor Yellow
if (-not (Test-Path .env)) {
    Copy-Item .env.example .env
    Write-Host "✅ Arquivo .env criado. Por favor, configure as variáveis." -ForegroundColor Green
}

# Inicia serviços com Docker Compose
Write-Host "🐳 Iniciando serviços com Docker Compose..." -ForegroundColor Yellow
docker-compose up -d

# Aguarda serviços iniciarem
Write-Host "⏳ Aguardando serviços iniciarem..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "✅ Ambiente configurado com sucesso!" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Cyan
Write-Host "1. Configure o arquivo .env com suas credenciais"
Write-Host "2. Execute: .\venv\Scripts\Activate.ps1"
Write-Host "3. Execute: cd api-java; .\mvnw.cmd spring-boot:run"
Write-Host "4. Acesse: http://localhost:8080/swagger-ui.html"

