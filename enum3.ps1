# Define the LDAPSearch function
function LDAPSearch {
    param (
        [string]$LDAPQuery
    )
    
    # Get the Primary Domain Controller (PDC) role owner's name
    $PDC = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name
    
    # Get the Distinguished Name (DN) of the domain
    $DistinguishedName = ([adsi]'').distinguishedName

    # Create a DirectoryEntry object
    $DirectoryEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$PDC/$DistinguishedName")

    # Create a DirectorySearcher object with the provided LDAPQuery
    $DirectorySearcher = New-Object System.DirectoryServices.DirectorySearcher($DirectoryEntry, $LDAPQuery)

    # Return the search results
    return $DirectorySearcher.FindAll()
}

# Use the LDAPSearch function to query for the Administration group
$filter = "(&(objectCategory=group)(cn=Administration))"
$result = LDAPSearch -LDAPQuery $filter

# Print the results
Foreach ($obj in $result) {
    Write-Host "Group: $($obj.Properties['cn'])"
    Write-Host "------------------------------"
}
