using './main.bicep'

param location = 'eastus'
param baseName = 'prodapp'
param linuxFxVersion = 'DOTNET|8.0'

// App Service Plan: PremiumV3 P1v3 x2 instancias
param appServiceSkuName = 'P1v3'
param appServiceSkuTier = 'PremiumV3'
param appServiceSkuSize = 'P1v3'
param appServiceCapacity = 2

// SQL habilitado (General Purpose provisionado)
param enableSql = true
param sqlPricingMode = 'gp_provisioned'
param sqlHostSuffix = 'database.windows.net'

param sqlAdminUser = 'sqladminuser'

// Password desde Key Vault (reemplaza NOMBRES reales)
@secure()
param sqlAdminPassword = reference(
  resourceId('Microsoft.KeyVault/vaults/secrets', 'kv-iac-prod', 'SqlPassword'),
  '2021-04-01-preview'
).value

// En prod, idealmente NO abrir 0.0.0.0
param allowAzureIpsOnSql = false

// Parámetros de cada modo (usa los de GP)
param basicMaxSizeBytes = 2147483648

param serverlessAutoPauseDelay = 60
param serverlessMinVcores = 1
param serverlessMaxSizeBytes = 34359738368

param gpSkuName = 'GP_Gen5_2'           // 2 vCores
param gpFamily = 'Gen5'
param gpCapacity = 2
param gpMaxSizeBytes = 137438953472      // 128 GB
