#######################################################
# Script to read in QAS VAS GPOs, extract SudoRoles   #
# and write them back to AD as native LDAP SudoRoles  #
# G. May 05/11/19                                     #
#######################################################


# Specify the source base OU and OU filter to read VAS sudoers GPOs from
$sourceOU = "OU=TDS,OU=Linux,OU=SUDOers,DC=wsgc,DC=com"
#$OUfilter = "Name -eq 'nonprod' -or Name -eq 'prod' "
#$OUfilter = "Name -eq 'nonprod'"

$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$domaincontext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext -ArgumentList "Domain",$domain
$domaincontroller = [System.DirectoryServices.ActiveDirectory.DomainController]::FindOne($domaincontext)

# Specify the searchScope to process base, onelevel or all subOUs
$OUs = Get-ADOrganizationalUnit -Server $domaincontroller -Filter "*" -SearchBase $sourceOU -SearchScope Subtree #Base, onelevel, subtree
Foreach ($OU in $OUs) {
    Write-Debug "Processing OU - [$OU]"
    $sudoRoleNames = Get-ADObject -LDAPFilter "(objectClass=sudoRole)" -Properties sudoUser -SearchBase $OU -credential $cred -server $domaincontroller
    foreach ($sudoRoleName in $sudoRoleNames) {
        Write-Debug "Processing SudoRole: $sudoRoleName"
        $userName = ($sudoRoleName.SudoUser).Trim("%")
        try{
            Write-Debug "Checking subject: $username"
            If (Get-ADUser -Identity $username -ErrorAction Ignore) {
                write-host "Processing" $sudoRoleName.distinguishedName
                $sudoUser = @()
                $sudoUser += ($sudoRoleName.sudoUser).replace("%","") 
                Set-ADObject -Identity $sudoRoleName -Replace @{sudoUser=$sudoUser} -Server $domaincontroller -credential $cred
            }
        }
        catch{
            Write-Debug "Username $username not found"
        }
    }
}  
 