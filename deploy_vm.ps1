clear
$ErrorActionPreference = "Stop" #Automatically exit script in the event of an unhandled exception.
Write-Host "Welcome to the Azure Classic VM Deployment script. - $(Get-Date -Format T)" -ForegroundColor "Green"; Write-Host


#Ensure Azure PS module is installed
If ( -not (Get-Module -ListAvailable -Name Azure)){
    Write-Host "The Azure ASM PowerShell module is not installed. Please install and import that module and try again. - $(Get-Date -Format T)" -ForegroundColor "Red"
    exit
}


#Check if logged in to azure, log in if not.
if (!(Get-AzureAccount)){
    Write-Host "Please log into an Azure account with administrative privileges to continue. - $(Get-Date -Format T)" -ForegroundColor "Red"

    while (!(Get-AzureAccount)){
        Add-AzureAccount
    }
    Write-Host "Successfully signed in. - $(Get-Date -Format T)" -ForegroundColor "Yellow"; Write-Host
}


#Gather required information for deployment
Write-Host "Please provide the following information. - $(Get-Date -Format T)" -ForegroundColor "Yellow"; Write-Host
$region = Read-Host -Prompt 'Enter Region'
$subscriptionID = Read-Host -Prompt 'Enter SubscriptionID'


#See if user account has admin access over subscription.
$adminSubAccount = $false
while ( -not $adminSubAccount){
    try {
            Select-AzureSubscription -SubscriptionId $subscriptionID
            Set-AzureSubscription -SubscriptionId $subscriptionID
            $adminSubAccount = $true
        }
    catch {
        Write-Host; Write-Host "That subscription is unavailable. Please sign in with an account with administrative privileges. - $(Get-Date -Format T)" -ForegroundColor "Red"
        Add-AzureAccount >  $null
    }
}


$affinityGroup = Read-Host -Prompt 'Enter Affinity Group Name. Null if N/A.'
$createAG = $true
#Function to determine if an Affinity Group already exists.
function checkIfAGExists {
    Param ([string]$funAGName)

    try{
        Get-AzureAffinityGroup -Name $funAGName
        $newOrUseAG = "Use"
    }
    catch{
        $newOrUseAG = "New"
    }
}

$useAffinity = $false
if (!$affinityGroup){
    Write-Host "No Affinity Group was specified. An Affinity Group will not be used for these resources." -ForegroundColor "Cyan"
    $createAG = $false
 }
else {
    $useAffinity = $true
    if (checkIfAGExists($affinityGroup)){
        Write-Host "Affinity Group already exists. It will be reused for this Virtual Machine." -ForegroundColor "Cyan"
        $createAG = $false
    }
}


$serviceName = Read-Host -Prompt 'Enter Cloud Service Name'
$createCS = $true
#Function to determine if a Cloud Service already exists.
function checkIfCSExists {
    Param ([string]$funCSName)

    try{
        Get-AzureService -ServiceName $funCSName
        $newOrUseCS = "Use"
    }
    catch{
        $newOrUseCS = "New"
    }
}

if (checkIfCSExists($serviceName)){
    Write-Host "Cloud Service already exists. It will be reused for this Virtual Machine." -ForegroundColor "Cyan"
    $createCS = $false
}


$storageAccount = Read-Host -Prompt 'Enter Storage Account Name'
$createSA = $true
#Function to determine if a storage account already exists.
function checkIfSAExists {
    Param ([string]$funSAName)

    try{
        Get-AzureStorageAccount -StorageAccountName $funSAName
    }
    catch{}
}
if ($new){

}


if (checkIfSAExists($storageAccount)){
    Write-Host "Storage Account already exists. It will be reused for this Virtual Machine." -ForegroundColor "Cyan"
    $createSA = $false
}

if ($createSA){
    
    $storageType = Read-Host "Storage Account does not exist. What type would you like to provision? (ex: Premium_LRS)" 
    
    while ("Standard_LRS","Standard_ZRS","Standard_GRS","Standard_RAGRS","Premium_LRS" -notcontains $storageType){
        $storageType = Read-Host "Invalid Input! What type of storage account would you like to provision? (ex: Premium_LRS)" 
    }
}

#Finish collecting other information
$vmName = Read-Host -Prompt 'Enter Virtual Machine Name'
$resIpName = Read-Host -Prompt 'Enter Reserved IP Address Name. Null if N/A'
$createResIP = $true
$useResIp = $false
if (!$resIpName){
    Write-Host "No Reserved IP was specified. A Reserved IP will not be used for these resources." -ForegroundColor "Cyan"
    $createResIP = $false
 }
else {
    $useResIp = $true
}


#Function to determine if a Reserved IP already exists. 
function checkIfResIPExists {
    Param ([string]$funIPName)

    try{
        Get-AzureReservedIP -ReservedIPName $funIPName
        $resIPExists = $false
    }
    catch{
        $resIPExists = $true
    }
}

if ($useResIp){
    if (checkIfResIPExists($resIpName)){
        Write-Host "Reserved IP Address already exists. It will be reused for this Virtual Machine." -ForegroundColor "Cyan"
        $createResIP = $false
    }
}


$instanceSize = Read-Host -Prompt 'Enter Instance Size (ex: Standard_DS12_v2_Promo)'
$osCreds = Get-Credential -Message 'Enter OS User Name and Password:' -UserName $UserName
$vnetName = Read-Host -Prompt 'Enter VNet Name (ex: Group Group Vnet)'
$subnetName = Read-Host -Prompt 'Enter Subnet Name'
[ValidatePattern("\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")]$ipAddress = Read-Host -Prompt 'Enter IP Address'


#Ask if the user intends to provision a secondary NIC
$twoNic = Read-Host "Would you like to provision a secondary NIC? (ex: Yes|No)"
while ("Yes","No" -notcontains $twoNic){
    $twoNic = Read-Host "Invalid Input! Would you like to provision a secondary NIC? (ex: Yes|No)"
}


#If they do, prompt for required fields.
if ($twoNic -eq "Yes"){
    $secondaryvnetName = Read-Host -Prompt 'Enter Secondary Virtual Network Name. (ex: Vnet)'
    $SecondarySubnetName = Read-Host -Prompt 'Enter Secondary Subnet Name'
    [ValidatePattern("\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")]$secondaryIPAddress = Read-Host -Prompt 'Enter Secondary IP Address'
}
else {
    Write-Host "Secondary NIC will not be deployed." -ForegroundColor "Cyan"
}


#Begin deployment
Write-Host; write-Host "Required information has been collected. Provisioning prerequisite resources. - $(Get-Date -Format T)" -ForegroundColor "Yellow"


if ($createag){
    New-AzureAffinityGroup -Name $affinityGroup -Location $region > $null
    Write-Host; Write-Host "-Affinity Group has been provisioned. - $(Get-Date -Format T)" -ForegroundColor "Cyan"
}

#If create new storage account, use different command depending on also use affinity group and type of storage account
if ($createSA){
    if ($useAffinity){
        New-AzureStorageAccount -StorageAccountName $storageAccount -AffinityGroup $affinityGroup -Type $storageType > $null
    }
    else{
        New-AzureStorageAccount -StorageAccountName $storageAccount -Location $region -Type $storageType > $null
    }
    Write-Host; Write-Host "-Storage Account has been provisioned. - $(Get-Date -Format T)" -ForegroundColor "Cyan"
}

Set-AzureSubscription -SubscriptionId $subscriptionID -CurrentStorageAccountName $storageAccount -InformationAction SilentlyContinue -ErrorAction SilentlyContinue -WarningAction SilentlyContinue > $null
Select-AzureSubscription -SubscriptionId $subscriptionID -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue > $null


#Create Cloud Service if necessary
if ($createCS){
    if ($useAffinity){
        New-AzureService -ServiceName $serviceName -AffinityGroup $affinityGroup > $null
    }
    else{
        New-AzureService -ServiceName $serviceName -Location $region > $null
    }

    Write-Host; Write-Host "-Cloud Service has been provisioned. - $(Get-Date -Format T)" -ForegroundColor "Cyan"
}
Write-Host


#Create Reserved IP if necessary.
if ($createResIP -eq $true){
    New-AzureReservedIP -Location $region -ReservedIPName $resIpName > $null
    Write-Host "-Reserved IP Address has been provisioned. -$(Get-Date -Format T)" -ForegroundColor "Cyan"; Write-Host

}


Write-Host "All required resources are provisioned. Building Virtual Machine Configuration Schema. - $(Get-Date -Format T)" -ForegroundColor "Yellow"; Write-Host
#Find the newest version of Windows Server 2012 R2 Datacenter available, build vm config from this base.
#$imageName = ( Get-AzureVMImage | where-object { $_.Label -like "Windows Server 2012 R2 Datacenter*" } ).ImageName | Select-Object -Last 1
$imageName = ( Get-AzureVMImage | where-object { $_.Label -like "Windows Server 2012 R2 Datacenter*" } | where { $_.Location.Contains($region) }).ImageName | Select-Object -Last 1
$vm = New-AzureVMConfig -Name $vmName -InstanceSize $instanceSize -Image $imageName -InformationAction SilentlyContinue
Add-AzureProvisioningConfig -VM $vm -Windows -AdminUserName $osCreds.GetNetworkCredential().UserName -Password $osCreds.GetNetworkCredential().Password > $null
Set-AzureSubnet -SubnetNames $subnetName -VM $vm > $null
Set-AzureStaticVNetIP -IPAddress $ipAddress -VM $vm > $null


#Create second NIC if necessary
if ($twoNic -eq "Yes"){
    Add-AzureNetworkInterfaceConfig -Name $secondaryvnetName -SubnetName $secondarySubnetName -StaticVNetIPAddress $secondaryIPAddress -VM $vm > $null
}

#Build virtual machine. If new deployment, specify VNET. Otherwise don't.
Write-Host "Configuration Schema has been defined. Provisioning Virtual Machine. - $(Get-Date -Format T)" -ForegroundColor "Yellow"
if ($createCS -or ($twoNic -eq "Yes")){
    if ($createResIP){
        New-AzureVM -ServiceName $serviceName -VNetName $vnetName -VMs $vm -WaitForBoot -WarningAction SilentlyContinue -InformationAction SilentlyContinue -ReservedIPName $resIpName > $null
    }
    else{
        New-AzureVM -ServiceName $serviceName -VNetName $vnetName -VMs $vm -WaitForBoot -WarningAction SilentlyContinue -InformationAction SilentlyContinue > $null
    }

}
else{
    if ($createResIP){
        New-AzureVM -ServiceName $serviceName -VMs $vm -WaitForBoot -WarningAction SilentlyContinue -InformationAction SilentlyContinue -ReservedIPName $resIpName > $null
    }
    else{
        New-AzureVM -ServiceName $serviceName -VMs $vm -WaitForBoot -WarningAction SilentlyContinue -InformationAction SilentlyContinue > $null
    }
}

Write-Host; Write-Host "Virtual Machine has been provisioned successfully. - $(Get-Date -Format T)" -ForegroundColor "Yellow"; Write-Host


#Determine if user wants to build data disks for the VM.
$provisionDisk = Read-Host "Would you like to provision Data Disks for your VM? (ex: Yes|No)"
while ("Yes","No" -notcontains $provisionDisk){
    $provisionDisk = Read-Host "Invalid Input! Would you like to provision Data Disks for your VM? (ex: Yes|No)"
}


if ($provisionDisk -eq "Yes"){

    $diskVM = Get-AzureVM -ServiceName $serviceName -Name $vmName
    do {
        try {
            $validNum = $true
            [int]$numDisks = Read-host "How many Data Disks would you like to provision? (ex: 0-64)"

            if ($numDisks -ne $null -and ($numDisks -gt 64 -or $numDisks -lt 0)){
                Write-Host; Write-Host "Invalid Input! Available range is 0-64. Most sizes support less. - $(Get-Date -Format T)" -ForegroundColor "Red";Write-Host
            }
        }
        catch {
            $validNum = $false
            Write-Host; Write-Host "Invalid Input! Available range is 0-64. Most sizes support less. - $(Get-Date -Format T)" -ForegroundColor "Red";Write-Host
        }
    }
    until ((($numDisks -ge 0 -and $numDisks -lt 65) -and $validNum))


    $provisionDisks = $false
    if ($numDisks -ge 1){
        $provisionDisks = $true
        Write-Host;Write-Host "Provisioning $numDisks Data Disks now. - $(Get-Date -Format T)" -ForegroundColor "Yellow"

        $diskVM = Get-AzureVM -ServiceName $serviceName -Name $vmName
    }
    else {
        Write-Host "Not provisioning any Data Disks."
    }


    $lunNum = 1
    $counter = $numDisks
    Write-Host
    while ($counter -gt 0){
        Write-Host "Provisioning Data Disk ($lunNum/$numDisks) - $(Get-Date -Format T)" -ForegroundColor "Cyan"
        $diskSize = Read-Host -Prompt "How many GB would you like to make Disk $lunNum (ex: 128|512|1023|2048|4095)?"

        $randomNum = $(get-random -Maximum 1000000 -Minimum 100000)
        $(Add-AzureDataDisk -CreateNew -DiskSizeInGB $diskSize -DiskLabel "DataDisk-$($lunNum)-$($vmName)-$($randomNum)" -VM $diskVM -MediaLocation "https://$($storageAccount).blob.core.windows.net/vhds/DataDisk-$($lunNum)-$($vmName)-$($randomNum)" -HostCaching ReadOnly -LUN $lunNum -InformationAction SilentlyContinue -WarningAction SilentlyContinue | Update-AzureVM -InformationAction SilentlyContinue -WarningAction SilentlyContinue) > $null
        Write-Host "Data Disk $lunNum has been provisioned."

        $lunNum++
        $counter--
        Write-Host
    }
    if ($provisionDisks -eq $true){
        Write-Host "All Data Disks have been provisioned successfully. - $(Get-Date -Format T)" -ForegroundColor "Yellow"
    }
}


#Print deployment summary
Write-Host; Write-Host "All steps have completed successfully. Printing a deployment summary now. - $(Get-Date -Format T)" -ForegroundColor "Green"; Write-Host
Write-Host "*************************************************" -ForegroundColor Green
Write-Host "VM State    : " -NoNewline;Write-Host $(Get-AzureVM -ServiceName $serviceName -Name $vmName).PowerState -ForegroundColor Cyan
Write-Host "Machine Name: " -NoNewline;Write-Host $vmName -ForegroundColor Cyan
Write-Host "Private IP  : " -NoNewline;Write-Host $ipAddress -ForegroundColor Cyan

If ($twoNic -eq "Yes"){
    Write-Host "Private IP 2: " -NoNewline;Write-Host $secondaryIPAddress -ForegroundColor Cyan
}

if ($useResIp){
    Write-Host "Public IP   : " -NoNewline;Write-Host $(Get-AzureReservedIP -ReservedIPName $resIpName).Address -ForegroundColor Cyan
}

$dataDiskSummary = $(Get-AzureVM -ServiceName $serviceName -Name $vmName | Get-AzureDataDisk)
If ($dataDiskSummary -ne $null){
    Write-Host "Data Disks  : " -NoNewline;Write-Host $($dataDiskSummary.length) -ForegroundColor Cyan
    $dataDiskSummary | Format-Table -AutoSize -Property "Lun","Disklabel","LogicalDiskSizeInGB" -HideTableHeaders
}

Write-Host "*************************************************" -ForegroundColor Green
Write-Host; Read-Host -Prompt "Press Enter to exit"
