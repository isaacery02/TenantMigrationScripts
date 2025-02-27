##### REMEMBER TO REMOVE SOFT DELETE ON THE RECOVERY SERVICES VAULTS #####
#### https://learn.microsoft.com/en-us/azure/backup/backup-azure-move-recovery-services-vault?toc=%2Fazure%2Fazure-resource-manager%2Fmanagement%2Ftoc.json

##### Get the Recovery Services Vaults #####
# Set Subscription
$subscriptionId = "1f40864d-113a-446e-8207-f0400d7552c0"
Set-AzContext -SubscriptionId $subscriptionId

# Load backup configuration
$backupConfigFile = "C:\temp\AzureBackupSettingsBackup\BackupConfig.csv"
$backupConfigs = Import-Csv -Path $backupConfigFile

foreach ($config in $backupConfigs) {
    Write-Host "🔍 Checking Backup for VM: $($config.VMName) in Vault: $($config.VaultName)"

    # Get the Recovery Services Vault
    $vault = Get-AzRecoveryServicesVault -Name $config.VaultName

    # Set the vault context (Fixes the "Set vault context first" error)
    Set-AzRecoveryServicesVaultContext -Vault $vault

    # Get the backup container first (fixes the issue where PowerShell asks for 'Container')
    $container = Get-AzRecoveryServicesBackupContainer -VaultId $vault.ID -ContainerType "AzureVM" | Where-Object { $_.FriendlyName -eq $config.VMName }

    if (-not $container) {
        Write-Host "⚠ No backup container found for VM: $($config.VMName). Skipping..."
        continue
    }

    # Get backup items from the container
    $backupItems = Get-AzRecoveryServicesBackupItem -VaultId $vault.ID -Container $container -WorkloadType "AzureVM"

    # Find the matching backup item by Resource ID (ensures exact match)
    $vmBackupItem = $backupItems | Where-Object { $_.SourceResourceId -eq $config.ResourceId }

    if ($vmBackupItem) {
        Write-Host "⏸ Stopping Backup for: $($config.VMName) ($($config.ResourceId))"

        # Stop backup WITHOUT deleting recovery points
        Disable-AzRecoveryServicesBackupProtection -Item $vmBackupItem -Force

        Write-Host "✅ Backup stopped, but recovery points are retained for: $($config.VMName)"
    } else {
        Write-Host "⚠ No backup found for VM: $($config.VMName) in Vault: $($config.VaultName)"
    }
}

Write-Host "🔹 Backup stopping process complete. Recovery points are retained."

##### DELETE INSTANT RESTORE POINT COLLECTIONS #####

# Get all resource groups
$resourceGroups = Get-AzResourceGroup

foreach ($rg in $resourceGroups) {
    Write-Host "🔍 Checking for Restore Point Collections in Resource Group: $($rg.ResourceGroupName)"

    # Get restore point collections
    $restorePointCollections = Get-AzResource -ResourceGroupName $rg.ResourceGroupName -ResourceType "Microsoft.Compute/restorePointCollections"

    foreach ($collection in $restorePointCollections) {
        Write-Host "❌ Deleting Restore Point Collection: $($collection.Name)"

        # Get all restore points in the collection
        $restorePoints = Get-AzComputeRestorePoint -ResourceGroupName $rg.ResourceGroupName -RestorePointCollectionName $collection.Name

        foreach ($restorePoint in $restorePoints) {
            Write-Host "❌ Revoking Access for Restore Point: $($restorePoint.Name)"

            # Revoke active SAS access before deletion
            Revoke-AzComputeRestorePointAccess -ResourceGroupName $rg.ResourceGroupName -RestorePointCollectionName $collection.Name -RestorePointName $restorePoint.Name

            Write-Host "✅ Access revoked for Restore Point: $($restorePoint.Name)"
        }

        # Delete the Restore Point Collection
        Remove-AzResource -ResourceId $collection.ResourceId -Force
        Write-Host "✅ Deleted: $($collection.Name)"
    }
}

Write-Host "🔹 All Instant Restore Point Collections have been deleted."

