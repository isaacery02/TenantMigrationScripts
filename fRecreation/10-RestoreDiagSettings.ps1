# Update the Resource ID of all JSON files!!

set-azcontext -Subscription a5811947-b2de-4412-ac6e-aff6fe5dfc86

$backupFiles = Get-ChildItem -Path "C:\temp\AzureDiagnosticsBackup\*.json"

foreach ($file in $backupFiles) {
    $settings = Get-Content $file.FullName | ConvertFrom-Json
    Set-AzDiagnosticSetting -ResourceId $settings.ResourceId -WorkspaceId $settings.WorkspaceId -Enabled $settings.Enabled
}
