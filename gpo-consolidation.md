

    $sourceOU = "OU=LinuxServers,DC=contoso,DC=com" - Base - not subtree
        Get each GPO
            Add SSH groups to Base-SSH-group array
            Add Console groups to Base-Console-group array

    For Each OU (BU) do - OneLevel
        Get each GPO
            Add SSH groups to BU-SSH-group array
            Add Console groups to BU-Console-group array 
        For Each TwoLevel OU (apps) do
            Get GPO
                Merge Base-SSH & BU-SSH-group to Apps GPO
                Merge Base-Console & BU-Console-group to Apps GPO
    

