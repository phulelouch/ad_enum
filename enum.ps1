# Get the Primary Domain Controller (PDC) role owner's name
$PDC = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name

# Get the Distinguished Name (DN) of the domain
$DN = ([adsi]'').distinguishedName

# Build the LDAP path
$LDAP = "LDAP://$PDC/$DN"

# Create a DirectoryEntry object for the LDAP path
$direntry = New-Object System.DirectoryServices.DirectoryEntry($LDAP)

# Create a DirectorySearcher object using the DirectoryEntry object
$dirsearcher = New-Object System.DirectoryServices.DirectorySearcher($direntry)

# Perform a search and retrieve all objects
$dirsearcher.FindAll()
