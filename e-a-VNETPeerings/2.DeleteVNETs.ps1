# Connect to Azure
Connect-AzAccount

# Set the Subscription
$subscriptionId = '6e455061-8c2e-4d6c-9b38-b1fee092ae86'
Select-AzSubscription -SubscriptionId $subscriptionId

# Get all Virtual Networks
$vNets = Get-AzVirtualNetwork

# Loop through each VNet and remove peerings
foreach ($vNet in $vNets) {
    $peerings = $vNet.VirtualNetworkPeerings
    foreach ($peering in $peerings) {
        Remove-AzVirtualNetworkPeering -VirtualNetworkName $vNet.Name -ResourceGroupName $vNet.ResourceGroupName -Name $peering.Name -Force
        Write-Output "Deleted Peering: $($peering.Name) from VNet: $($vNet.Name)"
    }
}

Write-Output "All VNet peerings have been removed successfully!"