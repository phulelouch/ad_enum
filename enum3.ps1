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

# Define the LDAP query for the "Administration" group
$filter = "(&(objectCategory=department)(cn=Administration))"

# Execute the LDAPSearch function with the query
$result = LDAPSearch -LDAPQuery $filter

# Print the results directly
Foreach ($obj in $result) {
    Write-Host "Group Name: $($obj.Properties['cn'])"
    Write-Host "Distinguished Name: $($obj.Properties['distinguishedName'])"
    Write-Host "------------------------------"
}
