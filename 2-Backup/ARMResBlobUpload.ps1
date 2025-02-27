# Authenticate using the Managed Identity of the Azure Automation Account
Connect-AzAccount -Identity

# Set the specific subscription context
Set-AzContext -Subscription 'c2a3e820-72d6-4da4-b565-d188e3f1f447'

# Define storage account details
$storageAccountName = "yourstorageaccountname"
$containerName = "resourceexports"
$resourceExportPath = "PROD/CommBrandsProd-ResourceExport"

# Ensure the storage account context is available
$storageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $storageAccountName }
if (-not $storageAccount) {
    Write-Error "Storage account $storageAccountName not found"
    exit
}

# Get storage account context
$storageContext = $storageAccount.Context

# Create container if it doesn't exist
$container = Get-AzStorageContainer -Name $containerName -Context $storageContext -ErrorAction SilentlyContinue
if (-not $container) {
    New-AzStorageContainer -Name $containerName -Context $storageContext -Permission Blob
}

# Define the temporary local export directory using system temp
$baseOutputDirectory = [System.IO.Path]::Combine($env:TEMP, "ResourceExports")

# Ensure the base output directory exists
if (!(Test-Path -Path $baseOutputDirectory)) {
    New-Item -ItemType Directory -Path $baseOutputDirectory | Out-Null
}

# Get a list of all resource groups
$resourceGroups = Get-AzResourceGroup

# Loop through each resource group
foreach ($rg in $resourceGroups) {
    # Define the resource group name
    $resourceGroupName = $rg.ResourceGroupName

    # Define the output directory for this resource group
    $rgOutputDirectory = Join-Path -Path $baseOutputDirectory -ChildPath $resourceGroupName

    # Ensure the resource group output directory exists
    if (!(Test-Path -Path $rgOutputDirectory)) {
        New-Item -ItemType Directory -Path $rgOutputDirectory | Out-Null
    }

    # Get all resources in the resource group
    $resources = Get-AzResource -ResourceGroupName $resourceGroupName

    # Loop through each resource in the resource group
    foreach ($resource in $resources) {
        # Define the output file path (resource name with .json extension in the RG-specific directory)
        $outputFile = Join-Path -Path $rgOutputDirectory -ChildPath "$($resource.Name).json"

        try {
            # Export the resource template
            Export-AzResourceGroup `
                -ResourceGroupName $resourceGroupName `
                -Resource $resource.ResourceId `
                -Path $outputFile

            # Define the blob path
            $blobPath = [System.IO.Path]::Combine(
                $resourceExportPath, 
                $resourceGroupName, 
                "$($resource.Name).json"
            )

            # Upload to Azure Blob Storage
            Set-AzStorageBlobContent `
                -File $outputFile `
                -Container $containerName `
                -Blob $blobPath `
                -Context $storageContext `
                -Force

            Write-Output "Exported and uploaded $($resource.Name) in $resourceGroupName to storage account"
        }
        catch {
            Write-Error "Failed to export or upload resource $($resource.Name) in $resourceGroupName. Error: $_"
        }
    }
}

# Optional: Clean up local temporary files
Remove-Item -Path $baseOutputDirectory -Recurse -Force