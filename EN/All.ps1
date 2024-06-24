function Log-Message {
    param (
        [string]$Message,
        [string]$LogFile,
        [switch]$Verbose
    )
    
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $Message
    }
    if ($Verbose) {
        Write-Verbose $Message
    } else {
        Write-Host $Message
    }
}

# Execute a function with a simple log message
Log-Message -Message "This is a log message." -Verbose:$true

function Mask-String {
    param (
        [Parameter(Mandatory=$true)]
        [string]$String
    )

    if ($String.Length -le 4) {
        # If the password is very short, do not mask
        return '*' * $String.Length
    }

    $firstPart = $String.Substring(0, 2)
    $lastPart = $String.Substring($String.Length - 2, 2)
    $maskedPart = '*' * ($String.Length - 4)

    return "$firstPart$maskedPart$lastPart"
}

# Example usage
# Mask a string longer than 4 characters
$maskedString = Mask-String -String "SuperSecretPassword"
Write-Host "Masked: $maskedString"

# Mask a string of 4 characters or less
$shortString = Mask-String -String "1234"
Write-Host "Masked: $shortString"

function Connect-SharePoint {
    param (
        [Parameter(Mandatory=$true, HelpMessage="Unique identifier in UUID format.")]
        [Alias("Id")]
        [ValidatePattern("^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$")]  # Validates the UUID format
        [string]$TenantID,

        [Parameter(Mandatory=$true, HelpMessage="Unique identifier in UUID format for the Azure application.")]
        [Alias("AppID")]
        [ValidatePattern("^[A-Fa-f0-9]{8}-[A-Fa0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$")]  # Validates the UUID format
        [string]$ClientID,

        [Parameter(Mandatory=$true, HelpMessage="Secret associated with the unique identifier of the Azure application.")]
        [Alias("Secret")]
        [string]$ClientSecret,

        [Parameter(Mandatory=$false, HelpMessage="Indicates if errors should be displayed.")]
        [switch]$VerboseLogging,

        [Parameter(Mandatory=$false, HelpMessage="Path of the log file.")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent)})]  # Validates that the log folder exists
        [string]$LogFile
    )

    # Display parameters
    Log-Message "################# Connect-SharePoint #################" -Verbose:$VerboseLogging
    Log-Message "[+] TenantID: $TenantID" -Verbose:$VerboseLogging
    Log-Message "[+] ClientID: $ClientID" -Verbose:$VerboseLogging
    $maskedSecret = Mask-String -String $ClientSecret     
    Log-Message "[+] ClientSecret: $maskedSecret" -Verbose:$VerboseLogging

    # Token retrieval
    Log-Message "[-] Retrieving token in progress..." -Verbose:$VerboseLogging
    $graphApiUrl = "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token"
    Log-Message "[-] Graph API URL: $graphApiUrl" -Verbose:$VerboseLogging
    try {
        $response = Invoke-WebRequest -Uri $graphApiUrl -Method Post -Body @{
            grant_type = "client_credentials"
            client_id = $ClientID
            client_secret = $ClientSecret
            scope = 'https://graph.microsoft.com/.default'
        }
        Log-Message "[+] Token retrieval successful" -Verbose:$VerboseLogging
        Log-Message "[-] Converting token in progress..." -Verbose:$VerboseLogging
        try {
            $token = ($response.Content | ConvertFrom-Json).access_token
            Log-Message "[+] Token conversion successful" -Verbose:$VerboseLogging
            return $token
        }
        catch {
            Log-Message "[!] Error during token conversion: $_" -Verbose:$VerboseLogging
            return
        }
    }
    catch {
        Log-Message "[!] Error during token retrieval: $_" -Verbose:$VerboseLogging
        return
    }
}

Connect-SharePoint -TenantID "123e4567-e89b-12d3-a456-426614174000" -ClientID "123e4567-e89b-12d3-a456-426614174001" -ClientSecret "SuperSecret123" -LogFile "C:\Logs\Connect-SharePoint.log" -VerboseLogging

function Export-SharePointFile {
    param (
        [Parameter(Mandatory=$true, HelpMessage="Name of the SharePoint site containing the file to download.")]
        [Alias("Site")]
        [ValidatePattern("^[a-zA-Z0-9\-]+$")]  # Validates SharePoint site names
        [string]$SiteName,

        [Parameter(Mandatory=$false, HelpMessage="Name of the SharePoint site library containing the file to download. Defaults to Documents")]
        [Alias("Library")]
        [string]$LibraryName="Documents",

        [Parameter(Mandatory=$true, HelpMessage="Name of the file to download.")]
        [Alias("File")]
        [string]$FileName,

        [Parameter(Mandatory=$false, HelpMessage="Full path where the downloaded file will be saved.")]
        [Alias("Path")]
        [ValidateScript({
            if ($_ -match "^[a-zA-Z]:\\(?:[^\\\/:*?`"<>|]+\\)*[^\\\/:*?`"<>|]+\.[a-zA-Z0-9]+$") {
                $true
            } else {
                throw "The OutFile path must be a valid full path and end with a file extension."
            }
        })]
        [string]$OutFile,

        [Parameter(Mandatory=$true, HelpMessage="Microsoft Graph token.")]
        [ValidatePattern("^[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+$")]  # Validates the JWT format
        [string]$Token,

        [Parameter(Mandatory=$true, HelpMessage="Name of the tenant associated with the unique identifier.")]
        [Alias("Tenant")]
        [string]$TenantName,

        [Parameter(Mandatory=$false, HelpMessage="Indicates if errors should be displayed.")]
        [switch]$VerboseLogging,

        [Parameter(Mandatory=$false, HelpMessage="Path of the log file.")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent)})]  # Validates that the log folder exists
        [string]$LogFile
    )

    # If the OutFile parameter is not provided, use the name of the downloaded file
    if (-not $OutFile) {
        $OutFile = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetFileName($FileName))
    }

    # Display parameters
    Log-Message "################# Export-SharePointFile #################" -Verbose:$VerboseLogging
    Log-Message "[-] Tenant:    $TenantName" -Verbose:$VerboseLogging
    Log-Message "[-] Site:      $SiteName" -Verbose:$VerboseLogging
    Log-Message "[-] Library:   $LibraryName" -Verbose:$VerboseLogging
    Log-Message "[-] FileName:  $FileName" -Verbose:$VerboseLogging
    Log-Message "[-] OutFile:   $OutFile" -Verbose:$VerboseLogging

    # File ID retrieval
    try {                
        # URL to get the file ID                
        $graphApiUrl = "https://graph.microsoft.com/v1.0/sites/$TenantName.sharepoint.com:/sites/${SiteName}:/lists/$LibraryName/items"                        
        Log-Message "[-] Retrieving ID for $FileName in progress..." -Verbose:$VerboseLogging
        Log-Message "[-] Graph API URL: $graphApiUrl" -Verbose:$VerboseLogging        
        $fileID = Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $graphApiUrl -Method Get | Select-Object -ExpandProperty value | Where-Object { $_.webUrl -ilike "*/$FileName" } | Select-Object -ExpandProperty id
        if($fileID -and $null -ne $fileID){        
            Log-Message "[+] ID retrieval for $FileName successful: $fileID" -Verbose:$VerboseLogging
            Log-Message "[-] Downloading $FileName (ID: $fileID) in progress..." -Verbose:$VerboseLogging
            # File download
            try {                          
                $graphApiUrl = "https://graph.microsoft.com/v1.0/sites/$TenantName.sharepoint.com:/sites/${SiteName}:/lists/$LibraryName/items/$fileID/driveItem/content"                           
                Log-Message "[-] Graph API URL: $graphApiUrl" -Verbose:$VerboseLogging
                # Request to get file content
                Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $graphApiUrl -Method Get -OutFile $OutFile
                Log-Message "[+] File download successful!" -Verbose:$VerboseLogging
                Log-Message "[+] File downloaded to: $OutFile" -Verbose:$VerboseLogging
                return 0
            }
            catch {
                Log-Message "[!] Error during file download: $_" -Verbose:$VerboseLogging
            }
        }
        else {
            Log-Message "[!] Error during ID retrieval: $FileName does not exist in the $LibraryName library. Check the information and try again." -Verbose:$VerboseLogging
        }        
    }
    catch {
        Log-Message "[!] Error during ID retrieval: $_" -Verbose:$VerboseLogging
    }
}

Export-SharePointFile -SiteName "MySite" -LibraryName "Documents" -FileName "myfile.docx" -OutFile "C:\Path\To\The\File\myfile.docx" -Token "eyJ0eXAiOiJKV1QiLCJhbGciOi..." -TenantName "MyTenant" -LogFile "C:\Logs\Export-SharePointFile.log" -VerboseLogging