#######################################################
# Script to read in QAS VAS GPOs, extract SudoRoles   #
# and write them back to AD as native LDAP SudoRoles  #
# G. May 05/11/19                                     #
#######################################################


# Specify the source base OU and OU filter to read VAS sudoers GPOs from
$sourceOU = "OU=Servers,DC=contoso,DC=com"
#$OUfilter = "Name -eq 'nonprod' -or Name -eq 'prod' "
$OUfilter = "*"

$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$domaincontext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext -ArgumentList "Domain",$domain
$domaincontroller = [System.DirectoryServices.ActiveDirectory.DomainController]::FindOne($domaincontext)

# Specify the searchScope to process base, onelevel or all subOUs
$OUs = Get-ADOrganizationalUnit -Server $domaincontroller -Filter $OUfilter -SearchBase $sourceOU -SearchScope Subtree #Base, onelevel, subtree
Foreach ($OU in $OUs) {
    Write-host "Processing OU - [$OU]"
    $LinkedGPOs = $OU | Select-object -ExpandProperty LinkedGroupPolicyObjects
    foreach ($LinkedGPO in $LinkedGPOs) {
        $LinkedGPOGUID = $LinkedGPO | ForEach-object{$_.Substring(4,36)}
        $LinkedGPOGUID | ForEach-object {
            $GPO_Name = Get-GPO -Guid $_ | Select-object -ExpandProperty Displayname | out-string -stream
            write-verbose "Processing GPO [$GPO_name] GUID [$_]"
            $manifest = "\\$domaincontroller\sysvol\$domain\Policies\{$_}\Machine\VGP\VTLA\Sudo\SudoersConfiguration\manifest.xml"
            try {
                [xml]$xmldata = get-content $manifest
                $sudoers_entry = Select-Xml -Xml $xmldata -XPath "//sudoers_entry" 
            }
            catch {
                Write-Host -foregroundcolor Magenta "Not able to get-content from [$GPO_Name]"
                Break
            }

            $sudoers_entry.node | ForEach-Object {
                try {
                    foreach ($principal in $_.listelement.principal."#text") {
                        $sudoRoleName = $principal.ToLower(), "--", $_.user, "--ALL--nopasswd" -join ""
                        $params = @{
                            'sudoUser' = $("%", $principal -join "").ToLower();
                            'sudoHost' = "ALL";
                            'sudoCommand' = @();
                            'sudoRunAsUser' = $($_.user).ToLower();
                            'sudoOption' = "!authenticate"
                        }
                        $sudoCommands = $_.command.replace(", ",",") -split ","
                        foreach ($sudoCommand in $sudoCommands) {
                            $params.sudoCommand += @("$sudoCommand"); 
                        }
                        write-host "`n"
                        write-host "Processing: " $sudoRoleName
                        write-host $params.Values
                        $OUPath = $OU.DistinguishedName.Replace("$sourceOU","$targetOU")
                        Try {
                            New-ADObject -Name $sudoRoleName -Type "sudoRole" -OtherAttributes $params -Path $OUPath -Server $domaincontroller
                        }
                        Catch {
                            write-host "sudoRole exists, merging: " $sudoRoleName 
                            Set-ADObject -Identity $("CN=",$sudoRoleName,",",$OUPath -join "";) -Add $params -Server $domaincontroller
                        }
                    }
                }
                catch {
                    Write-Host -foregroundcolor Magenta "SudoRole $sudoers_entry could not be processed"
                    $error[0]
                    Break
                }
            }
        } 
    }
}  