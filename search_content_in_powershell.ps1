###############################################################################
# PowerShell Script: Recursively Search for "password"
# in Specific SMB Shares
###############################################################################

# Define the list of SMB shares to search
$SMBShares = @(
   
)

# Define the search pattern
$SearchPattern = "password"

# Define the log file path
$LogFile = "C:\Path\To\Your\LogFile.txt"

# Function to log messages
function Log-Message {
    param (
        [string]$Message,
        [string]$Type = "INFO" # INFO, WARNING, ERROR
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Type] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogFile -Value $logEntry
}

# Prompt for credentials if needed
$UseCredentials = $false

# Uncomment the following lines if credentials are required to access the shares
# $UseCredentials = $true
# $Cred = Get-Credential -Message "Enter credentials to access SMB shares"

# Start logging
Log-Message "=== SMB Share Search Started ==="

foreach ($share in $SMBShares) {
    Log-Message "--------------------------------------------------------------"
    Log-Message "Searching Share: $share"

    # Check if the share is accessible
    if ($UseCredentials) {
        # Use provided credentials
        $UNCPath = $share
    }
    else {
        # Attempt to access the share without credentials
        $UNCPath = $share
    }

    # Test if the path exists
    if (-not (Test-Path -Path $UNCPath)) {
        Log-Message "Share $share is not accessible or does not exist." "WARNING"
        continue
    }

    try {
        # Retrieve all files recursively, excluding directories
        $Files = Get-ChildItem -Path $UNCPath -Recurse -File -ErrorAction Stop
    }
    catch {
        Log-Message "Failed to retrieve files from $share. Error: $_" "ERROR"
        continue
    }

    foreach ($file in $Files) {
        try {
            # Search for the pattern in the current file
            $Found = Select-String -Path $file.FullName -Pattern $SearchPattern -SimpleMatch -Quiet

            if ($Found) {
                Log-Message "FOUND in file: $($file.FullName)"
            }
        }
        catch {
            # Handle files that cannot be read (e.g., due to permissions)
            Log-Message "Cannot read file: $($file.FullName). Error: $_" "WARNING"
        }
    }
}

Log-Message "=== SMB Share Search Completed ==="
