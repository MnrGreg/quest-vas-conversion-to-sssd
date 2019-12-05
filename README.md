## Powershell scripts to convert Linux QAS/VAS SudoRole and AccessControl policies to native ActiveDirectory

### QAS Access Control to SSSD GPO
- Iterates through VAS Group Policies
- Extract users and group names
- Resolves user and groups to ActiveDirectory SIDs
- Contructs new AD GPOs
- Add the SIDs to SeRemoteInteractiveLogonRight and SeInteractiveLogonRight within the GPOs

### QAS SudoRoles to AD LDAP SudoRoles
- Iterates through VAS Group Policies
- Extracts sudoroles (sudoCommand, sudoUser, SudoHost, sudoRunAsUser, sudoOption)
- Constructs consolidate sudoRole object based on sudoUser
- Writes sudoRoles back to target OU within ActiveDirectory