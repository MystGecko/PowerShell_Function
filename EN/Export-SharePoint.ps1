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