##### Restore the Backup Policy on all VMs (from backup restore file) #####

# Set Subscription
$subscriptionId = "6e455061-8c2e-4d6c-9b38-b1fee092ae86"
Set-AzContext -SubscriptionId $subscriptionId

# Load backup configuration
$backupConfigFile = "C:\temp\AzureBackupSettingsBackup\BackupConfig.csv"
$backupConfigs = Import-Csv -Path $backupConfigFile

foreach ($config in $backupConfigs) {
    Write-Host "🔄 Restoring backup for VM: $($config.VMName)"

    # Get the vault in the new subscription
    $vault = Get-AzRecoveryServicesVault -Name $config.VaultName

    # Get the backup policy in the new vault
    $policy = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $vault.ID | Where-Object { $_.Name -eq $config.PolicyName }

    if (-not $policy) {
        Write-Host "⚠ WARNING: Policy not found for VM: $($config.VMName). Skipping..."
        continue
    }

    # Re-enable backup using FullBackupName (to match Azure Backup exactly)
    Enable-AzRecoveryServicesBackupProtection -VaultId $vault.ID -Policy $policy -Name $config.FullBackupName -ResourceType "AzureVM"

    Write-Host "✅ Backup re-enabled for: $($config.VMName)"
}

Write-Host "🔹 Backup configuration restored successfully."
