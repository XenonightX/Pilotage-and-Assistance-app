param(
  [string]$DeviceId = "RR8MA062CGF"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$frontendDir = Join-Path $repoRoot "frontend"
$googleServicesPath = Join-Path $frontendDir "android\app\google-services.json"

$firebaseApiKey = $env:FIREBASE_API_KEY
$firebaseAndroidAppId = $env:FIREBASE_ANDROID_APP_ID
$firebaseMessagingSenderId = $env:FIREBASE_MESSAGING_SENDER_ID
$firebaseProjectId = $env:FIREBASE_PROJECT_ID
$firebaseAuthDomain = $env:FIREBASE_AUTH_DOMAIN
$firebaseStorageBucket = $env:FIREBASE_STORAGE_BUCKET

if (
  (Test-Path $googleServicesPath) -and
  (
    [string]::IsNullOrWhiteSpace($firebaseApiKey) -or
    [string]::IsNullOrWhiteSpace($firebaseAndroidAppId) -or
    [string]::IsNullOrWhiteSpace($firebaseMessagingSenderId) -or
    [string]::IsNullOrWhiteSpace($firebaseProjectId)
  )
) {
  $googleServices = Get-Content -Raw -LiteralPath $googleServicesPath | ConvertFrom-Json
  $client = @($googleServices.client) |
    Where-Object { $_.client_info.android_client_info.package_name -eq "com.example.pilotage_and_assistance_app" } |
    Select-Object -First 1

  if ($null -eq $client) {
    $client = @($googleServices.client) | Select-Object -First 1
  }

  if ($null -ne $client) {
    if ([string]::IsNullOrWhiteSpace($firebaseApiKey)) {
      $firebaseApiKey = @($client.api_key)[0].current_key
    }
    if ([string]::IsNullOrWhiteSpace($firebaseAndroidAppId)) {
      $firebaseAndroidAppId = $client.client_info.mobilesdk_app_id
    }
  }

  if ([string]::IsNullOrWhiteSpace($firebaseMessagingSenderId)) {
    $firebaseMessagingSenderId = $googleServices.project_info.project_number
  }
  if ([string]::IsNullOrWhiteSpace($firebaseProjectId)) {
    $firebaseProjectId = $googleServices.project_info.project_id
  }
  if ([string]::IsNullOrWhiteSpace($firebaseStorageBucket)) {
    $firebaseStorageBucket = $googleServices.project_info.storage_bucket
  }
  if ([string]::IsNullOrWhiteSpace($firebaseAuthDomain) -and -not [string]::IsNullOrWhiteSpace($firebaseProjectId)) {
    $firebaseAuthDomain = "$firebaseProjectId.firebaseapp.com"
  }
}

$requiredEnv = @(
  @{ Name = "FIREBASE_API_KEY"; Value = $firebaseApiKey },
  @{ Name = "FIREBASE_ANDROID_APP_ID"; Value = $firebaseAndroidAppId },
  @{ Name = "FIREBASE_MESSAGING_SENDER_ID"; Value = $firebaseMessagingSenderId },
  @{ Name = "FIREBASE_PROJECT_ID"; Value = $firebaseProjectId }
)

$missing = $requiredEnv | Where-Object {
  [string]::IsNullOrWhiteSpace($_.Value)
} | ForEach-Object {
  $_.Name
}

if ($missing.Count -gt 0) {
  throw "Firebase config belum lengkap. Letakkan google-services.json di frontend\android\app atau set env var berikut dulu: $($missing -join ', ')"
}

$flutter = $env:FLUTTER_BIN
if ([string]::IsNullOrWhiteSpace($flutter)) {
  $defaultFlutter = "D:\flutter\bin\flutter.bat"
  $flutter = if (Test-Path $defaultFlutter) { $defaultFlutter } else { "flutter" }
}

Push-Location $frontendDir
try {
  & $flutter devices --device-timeout 20
  & $flutter run `
    -d $DeviceId `
    --debug `
    --dart-define=FIREBASE_API_KEY=$firebaseApiKey `
    --dart-define=FIREBASE_ANDROID_APP_ID=$firebaseAndroidAppId `
    --dart-define=FIREBASE_MESSAGING_SENDER_ID=$firebaseMessagingSenderId `
    --dart-define=FIREBASE_PROJECT_ID=$firebaseProjectId `
    --dart-define=FIREBASE_AUTH_DOMAIN=$firebaseAuthDomain `
    --dart-define=FIREBASE_STORAGE_BUCKET=$firebaseStorageBucket
} finally {
  Pop-Location
}
