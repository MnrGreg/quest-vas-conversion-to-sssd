###########################################################
# Script to read in QAS VAS GPOs, extract AccessControls  #
# and write them back to AD as native SSSD GPOs           #
# G. May 05/11/19                                         #
###########################################################

Import-Module GroupPolicy
Import-module ActiveDirectory

# Specify the OU to link the GPO to
$sourceOU = "OU=Servers,DC=contoso,DC=com"
$targetOU = "OU=LinuxServers,DC=contoso,DC=com"

$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$domaincontext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext -ArgumentList "Domain",$domain
$domaincontroller = [System.DirectoryServices.ActiveDirectory.DomainController]::FindOne($domaincontext)

# Specify the searchScope to process base, onelevel or all subOUs
$OUs = Get-ADOrganizationalUnit -Server $domaincontroller -filter * -SearchBase $sourceOU -SearchScope Subtree # Base, OneLevel or Subtree
Foreach ($OU in $OUs) {
    Write-host "Processing OU - [$OU]"
    $LinkedGPOs = $OU | Select-object -ExpandProperty LinkedGroupPolicyObjects
    foreach ($LinkedGPO in $LinkedGPOs) {
        $LinkedGPOGUID = $LinkedGPO | ForEach-object{$_.Substring(4,36)}
        $LinkedGPOGUID | ForEach-object {
            $GPO_Name = Get-GPO -Guid $_ | Select-object -ExpandProperty Displayname | out-string -stream
            write-verbose "Processing GPO [$GPO_name] GUID [$_]"
            $manifest = "\\$domaincontroller\sysvol\$domain\Policies\{$_}\Machine\VGP\VTLA\VAS\HostAccessControl\Allow\manifest.xml"
            try {
                [xml]$xmldata = get-content $manifest
                $groups = Select-Xml -Xml $xmldata -XPath "//entry" 
            }
            catch {
                Write-Host -foregroundcolor Magenta "Not able to get-content from [$GPO_Name]"
                Break
            }
            
            #Lookup AD group SIDs from group names
            $group_sids = $null
            $groups.node.InnerXML | ForEach-Object {
                try {
                    $subject = $_.Replace("$domain\","")
                    $subject = $subject.Replace("@$domain","")
                    $group_sid = "*" + (New-Object System.Security.Principal.NTAccount($domain, $subject)).Translate([System.Security.Principal.SecurityIdentifier])
                }
                catch {
                    Write-Host -foregroundcolor Magenta "Subject $subject could not be resolved"
                    Break
                }
                [array]$group_sids = $group_sids + $group_sid
            }
            $all_group_sids = $group_sids -join ","

            $newGPO_Name = "$GPO_Name SSSD"
            Write-Host "Create new GPO [$newGPO_Name]"
            $GPO = New-GPO -name $newGPO_Name -server $domaincontroller -domain $domain

            # Disable GPO User Configuration
            $GPO.GpoStatus = "UserSettingsDisabled"

            # Construct the inf settings to enable RemoteInteractiveLogonRight
            $inf = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeRemoteInteractiveLogonRight = $all_group_sids
SeInteractiveLogonRight = $all_group_sids
"@

            Write-Host "Writing GPO [$newGPO_Name] to SYSVOL"
            Start-Sleep -s 5
            $filepath = "\\$domaincontroller\sysvol\$domain\Policies\{$($GPO.Id)}\Machine\Microsoft\Windows NT\SecEdit"

            if (!(Test-Path $filepath)) {
                md $filepath
            }
            $inf |Out-File (Join-Path $filepath 'GptTmpl.inf')

            # Replace source and target paths below as needed
            $OUPath = $OU.DistinguishedName.Replace("$sourceOU","$targetOU")
            Write-Host "Linking [$newGPO_Name] to [$OUPath]"
            New-GPLink -Name $newGPO_Name -Target $OUPath -LinkEnabled 'Yes' -Server $domaincontroller -Domain $domain 

        } 
    }
}
