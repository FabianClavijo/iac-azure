using './main.bicep'

param location = 'centralus'
param baseName = 'demoappsql'
param linuxFxVersion = 'DOTNET|8.0'

// App Service Plan: Free (F1)
param appServiceSkuName = 'F1'
param appServiceSkuTier = 'Free'
param appServiceSkuSize = 'F1'
param appServiceCapacity = 1

// SQL habilitado y modo más barato: Basic (DTU)
param enableSql = true
param sqlPricingMode = 'basic'
param sqlHostSuffix = 'database.windows.net'

param sqlAdminUser = 'sqladminuser'
@secure()
param sqlAdminPassword = 'Demo#Passw0rd123'   // Solo demo; NO subir a Git real

param allowAzureIpsOnSql = true

// Básico: 2 GB (ajusta si quieres)
param basicMaxSizeBytes = 2147483648

// Serverless (no se usa en demo, pero quedan por si cambias)
param serverlessAutoPauseDelay = 60
param serverlessMinVcores = 1
param serverlessMaxSizeBytes = 34359738368

// GP provisionado (no se usa en demo)
param gpSkuName = 'GP_Gen5_2'
param gpFamily = 'Gen5'
param gpCapacity = 2
param gpMaxSizeBytes = 137438953472

// Add your parameters

