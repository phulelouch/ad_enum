# Get the Domain Object
$domainObj = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()

# Get the Primary Domain Controller (PDC) role owner's name
$PDC = $domainObj.PdcRoleOwner.Name

# Get the Distinguished Name (DN) of the domain
$DN = ([adsi]'').distinguishedName

# Build the LDAP path
$LDAP = "LDAP://$PDC/$DN"

# Create a DirectoryEntry object for the LDAP path
$direntry = New-Object System.DirectoryServices.DirectoryEntry($LDAP)

# Create a DirectorySearcher object using the DirectoryEntry object
$dirsearcher = New-Object System.DirectoryServices.DirectorySearcher($direntry)

# Set the filter for the search
$dirsearcher.filter = "samAccountType=805306368"

# Perform a search and retrieve all matching results
$result = $dirsearcher.FindAll()

# Loop through each result object
Foreach ($obj in $result) {
    # Loop through each property in the object
    Foreach ($prop in $obj.Properties) {
        $prop
    }
    # Write a separator for each object
    Write-Host "------------------------------"
}
