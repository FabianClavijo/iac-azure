@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name/prefix for resources (used in resource names)')
param baseName string

@description('App runtime stack (linuxFxVersion), e.g., "DOTNET|8.0" or "NODE|20-lts"')
param linuxFxVersion string

@description('App Service Plan SKU name, e.g., F1, B1, P1v3')
param appServiceSkuName string

@description('App Service Plan SKU tier, e.g., Free, Basic, PremiumV3')
param appServiceSkuTier string

@description('App Service Plan SKU size, e.g., F1, B1, P1v3')
param appServiceSkuSize string

@description('App Service Plan instance count')
param appServiceCapacity int

@description('Enable Azure SQL Server + Database')
param enableSql bool

@allowed([
  'basic'          // DTU Basic
  'serverless'     // General Purpose Serverless (auto-pause)
  'gp_provisioned' // General Purpose provisionado
])
@description('SQL pricing mode (when enableSql=true)')
param sqlPricingMode string

@description('SQL host suffix (override for sovereign clouds).')
param sqlHostSuffix string = environment().suffixes.sqlServerHostname

@description('SQL Administrator username (required only if enableSql=true)')
param sqlAdminUser string

@secure()
@description('SQL Administrator password (required only if enableSql=true)')
param sqlAdminPassword string

@description('Create firewall rule to allow Azure services (0.0.0.0). Applies only if enableSql=true')
param allowAzureIpsOnSql bool

@description('Optional override for SQL Server name')
param sqlServerName string = toLower('${baseName}${uniqueString(resourceGroup().id)}')

@description('Optional override for SQL Database name')
param sqlDbName string = '${baseName}-db'

@description('Max size (bytes) for Basic DTU DB (used if sqlPricingMode=basic)')
param basicMaxSizeBytes int = 2147483648 // 2 GB

@description('Serverless: auto-pause delay in minutes (used if sqlPricingMode=serverless)')
param serverlessAutoPauseDelay int = 60

@description('Serverless: min vCores (1 typically; used if sqlPricingMode=serverless)')
param serverlessMinVcores int = 1

@description('Serverless: max size (bytes) (used if sqlPricingMode=serverless)')
param serverlessMaxSizeBytes int = 34359738368 // 32 GB

@description('GP provisioned: SKU name, e.g., GP_Gen5_2 (used if sqlPricingMode=gp_provisioned)')
param gpSkuName string = 'GP_Gen5_2'

@description('GP provisioned: family, e.g., Gen5 (used if sqlPricingMode=gp_provisioned)')
param gpFamily string = 'Gen5'

@description('GP provisioned: capacity (vCores), e.g., 2 (used if sqlPricingMode=gp_provisioned)')
param gpCapacity int = 2

@description('GP provisioned: max size (bytes) (used if sqlPricingMode=gp_provisioned)')
param gpMaxSizeBytes int = 137438953472 // 128 GB

// ---------------- Derived names ----------------
var appServicePlanName = '${baseName}-plan'
var webAppName         = '${baseName}-web'

// ---------------- App Service Plan (Linux) ----------------
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServiceSkuName
    tier: appServiceSkuTier
    size: appServiceSkuSize
    capacity: appServiceCapacity
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// ---------------- Web App (Linux) ----------------
resource web 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appSettings: concat(
        [
          {
            name: 'WEBSITE_RUN_FROM_PACKAGE'
            value: '1'
          }
        ],
        enableSql ? [
          {
            name: 'ConnectionStrings__Default'
            // Importante: usa sufijo parametrizable (por defecto: database.windows.net)
            value: 'Server=tcp:${sqlServerName}.${sqlHostSuffix},1433;Initial Catalog=${sqlDbName};Persist Security Info=False;User ID=${sqlAdminUser};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
          }
        ] : []
      )
    }
  }
}

// ---------------- SQL Server (opcional) ----------------
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = if (enableSql) {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUser
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
  }
}

// Firewall: permitir servicios Azure (0.0.0.0)
resource fwAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = if (enableSql && allowAzureIpsOnSql) {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ---------------- SQL Database (opcional) ----------------

// DTU Basic
resource sqlDbBasic 'Microsoft.Sql/servers/databases@2023-08-01-preview' = if (enableSql && sqlPricingMode == 'basic') {
  name: sqlDbName
  parent: sqlServer
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    maxSizeBytes: basicMaxSizeBytes
  }
}

// General Purpose Serverless
resource sqlDbServerless 'Microsoft.Sql/servers/databases@2023-08-01-preview' = if (enableSql && sqlPricingMode == 'serverless') {
  name: sqlDbName
  parent: sqlServer
  location: location
  sku: {
    name: 'GP_S_Gen5_1'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    autoPauseDelay: serverlessAutoPauseDelay
    minCapacity: serverlessMinVcores
    maxSizeBytes: serverlessMaxSizeBytes
    zoneRedundant: false
  }
}

// General Purpose provisionado
resource sqlDbGp 'Microsoft.Sql/servers/databases@2023-08-01-preview' = if (enableSql && sqlPricingMode == 'gp_provisioned') {
  name: sqlDbName
  parent: sqlServer
  location: location
  sku: {
    name: gpSkuName          // ej: GP_Gen5_2
    tier: 'GeneralPurpose'
    family: gpFamily         // ej: Gen5
    capacity: gpCapacity     // ej: 2 vCores
  }
  properties: {
    maxSizeBytes: gpMaxSizeBytes
    zoneRedundant: false
  }
}

// ---------------- Outputs (no exponen secretos) ----------------
@description('App Service default hostname')
output webAppUrl string = 'https://${web.properties.defaultHostName}'

@description('SQL Server FQDN (only if enableSql=true)')
output sqlServerFqdn string = enableSql ? '${sqlServerName}.${sqlHostSuffix}' : ''
