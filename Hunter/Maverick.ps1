function Find-PrivilegedUsers {

	<#
	.SYNOPSIS
		Hunts for privileged users belonging to the standard privileged Active Directory groups.
		It also finds any users from custom groups nested within these standard groups.
		
		Author: Michael Maturi
	.DESCRIPTION
		Enumerates users in the standard privileged AD groups and users in custom groups nested within these groups.
		This script must be executed from a domain-joined host.
	.EXAMPLE
		PS C:\> Find-PrivilegedUsers
	.LINK
		https://github.com/a-marionette
		https://twitter.com/__amarionette
#>

	$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() 
	$root = $domain.GetDirectoryEntry()

# Consider using the filter (samAccountType=805306368) to more acccurate target only users

	$objsearch = [System.DirectoryServices.DirectorySearcher]$root            
	$objsearch.filter = "(&(objectClass=user)(|(memberOf:1.2.840.113556.1.4.1941:=cn=Domain Admins,cn=Users,dc=evezero,dc=local)(memberOf:1.2.840.113556.1.4.1941:=cn=Enterprise Admins,cn=Users,dc=evezero,dc=local)(memberOf:1.2.840.113556.1.4.1941:=cn=*Admin*,cn=Users,dc=evezero,dc=local)(memberOf:1.2.840.113556.1.4.1941:=cn=Account Operators,cn=Users,dc=evezero,dc=local)(memberOf:1.2.840.113556.1.4.1941:=cn=Server Operators,cn=Users,dc=evezero,dc=local)(memberOf:1.2.840.113556.1.4.1941:=cn=Backup Operators,cn=Users,dc=evezero,dc=local)(memberOf:1.2.840.113556.1.4.1941:=cn=Print Operators,cn=Users,dc=evezero,dc=local)(memberOf:1.2.840.113556.1.4.1941:=cn=Cert Publishers,cn=Users,dc=evezero,dc=local)))"                      
	$objs = $objsearch.findall() 

	"{0,-35}{1,-35}" -f "USER", "GROUPS"
	"--------------------------------------------------------------"

	foreach ($obj in $objs) {
		$objProperties = $obj.Properties
		$usergroups = ''
		foreach ($group in $objProperties.memberof){
			$usergroups +=  $group.toString().split(',')[0].replace('CN=','') + ", " 
		}
		
		"{0,-35}{1,-35}" -f $objProperties.name[0], $usergroups.substring(0,$usergroups.length - 2)
		
	}
}

function Find-AllGroupMembership {

<#
	.SYNOPSIS
		Hunts for users belonging to the specified groups. This function will ALSO pull users from nested groups.
	
		Author: Michael Maturi
	.DESCRIPTION
		Uses ASDI to return all users and users of nested groups from the supplied group(s)
	.PARAMETER Groups
		The groups you wish to query
		
	.EXAMPLE
	   PS C:\> Find-AllGroupMembership -Groups "Domain Admins"
	.LINK
		https://github.com/a-marionette
		https://twitter.com/__amarionette
#>

	[CmdletBinding(DefaultParameterSetName='Groups')]
	param(
	[Parameter(Mandatory = $True,ParameterSetName="Groups")]
	[String[]]
	$Groups = ''
	
	)

	$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()            
	$root = $domain.GetDirectoryEntry()
	$domainRoot = $domain.name.split('.')[0]
	$domainSuffix = $domain.name.split('.')[1]    
	
	foreach ($group in $groups){
		$allGroups += "(memberOf:1.2.840.113556.1.4.1941:=cn=$group,cn=Users,dc=$domainRoot,dc=$domainSuffix)"
	}

	$objsearch = [System.DirectoryServices.DirectorySearcher]$root            
	$objsearch.filter = "(&(objectClass=user)(|$allGroups))"                       
	$objs = $objsearch.findall() 

	"{0,-35}{1,-35}" -f "USER", "GROUPS"
	"--------------------------------------------------------------"

	foreach ($obj in $objs) {
		$objProperties = $obj.Properties
		$usergroups = ''
		foreach ($group in $objProperties.memberof){
			$usergroups +=  $group.toString().split(',')[0].replace('CN=','') + ", " 
		}
		
		"{0,-35}{1,-35}" -f $objProperties.name[0], $usergroups.substring(0,$usergroups.length - 2)
		
	}
}

function Find-AutomaticLogon {

<#
	.SYNOPSIS
		Returns clear-text passwords stored in the registry per Microsoft's Admin Auto-logon feature
		
		Author: Michael Maturi
	.DESCRIPTION
		Uses WMI to return clear-text passwords stored in the registry per Microsoft's Admin Auto-logon feature
	.PARAMETER Credential
		Specify the user with local admin access to the hosts' registry you are querying.
		Specify username and password in this format: "username:password"
	.EXAMPLE
		PS C:\> Find-AutomaticLogon -Hosts 127.0.0.1,172.16.30.192
	.EXAMPLE
		PS C:\> Find-AutomaticLogon -Creds amarionette:passw0rd -Hosts (Get-Content ./hostlist.txt)
	.LINK
		https://github.com/a-marionette
		https://twitter.com/__amarionette
#>

	[CmdletBinding(DefaultParameterSetName='Hosts')]
	param(
	[Parameter(Mandatory = $True,ParameterSetName="Hosts")]
	[String[]]
	$Hosts = '127.0.0.1',
	
	[Parameter(Mandatory = $False)]
	[String[]]
	$Creds = '',
	
	[int]
	$Timeout = 500
	
	)

	$ErrorActionPreference = "silentlycontinue"

	$HKLM = 2147483650
	"{0,-35}{1,-35}{2,-35}" -f "HOSTS", "USER", "PASSWORD"
	"--------------------------------------------------------------"
	
	if ($PSBoundParameters.ContainsKey('Creds'))
	{
		$Credarray = $Creds -split ":"
		$user = $Credarray[0]
		$password =  ConvertTo-SecureString -String $Credarray[1] -AsPlainText -Force
		$Credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $user, $password 
		
	}
	
	foreach ($ComputerName in $Hosts) {

		$HostIsValid = $True
		if (!(Test-Port -Computer $ComputerName -Port 445 -Timeout $Timeout)) {
			"{0,-35}" -f "Host $ComputerName is not accessible on port 445, skipping!"                  
			continue
			
		}
		
		if (!$HostIsValid) {
			continue
			
		}

		$autoLogonUserName = ''
		$autoLogonPassword = ''
		
		if ($Credential){
			$reg = Get-WmiObject -List -Namespace root\default -ComputerName $ComputerName -ErrorVariable WMIErr -Credential $Credential | Where-Object {$_.Name -eq "StdRegProv"}
		}
		else
		{
			$reg = Get-WmiObject -List -Namespace root\default -ComputerName $ComputerName -ErrorVariable WMIErr | Where-Object {$_.Name -eq "StdRegProv"}
		}
		
		$autoLogonUserName = $reg.GetStringValue($HKLM,"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon","DefaultUserName").sValue
		$autoLogonPassword = $reg.GetStringValue($HKLM,"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon","DefaultPassword").sValue
		
		if ($WMIErr){
			"{0,-35}{1,-35}{2,-35}" -f $ComputerName, "No Admin Access", "No Admin Access"
		}
		else {
			
			if ($autoLogonPassword){
				"{0,-35}{1,-35}{2,-35}" -f $ComputerName, $autoLogonUserName, $autoLogonPassword
			}
			else{
				"{0,-35}{1,-35}{2,-35}" -f $ComputerName, "None", "None"
			}
			
		}
		
	}
	
	function Test-Port
	{ 
		param ( [string]$Computer, [int]$Port, [int] $Timeout=300 )
		
		$Test = New-Object Net.Sockets.TcpClient
		
		$Test.BeginConnect( $Computer, $Port, $Null, $Null ) | Out-Null
		
		$Time = ( Get-Date ).AddMilliseconds( $Timeout )
		
		While ( -not $Test.Connected -and ( Get-Date ) -lt $Time ) {
			Sleep -Milliseconds 50
		}
		
		#  Return the connection status (Boolean)
		$Test.Connected
		
		# Cleanup
		$Test.Close()
		
	}
}


function Find-AdjacentNetworkAccess {

<#
	.SYNOPSIS
		Hunt for hosts that have the ability to interact with another network segmnet.
	
Author: Michael Maturi
	.DESCRIPTION
		This script attempts to identify any dual-homed hosts existing within the network. In doing so,
		you may be able to increase the potential attack surface and move to other network segments.
	.PARAMETER Hosts
		The hostnames to attempt to authenticate to in a list format. Use
		Get-Content to pipe in the list.
	.PARAMETER Credentials
		The privileged credentials required to remotly administer WMI commands via Powershell's WMI cmdlets.  The proper 
		format for this is "Username:Password", and a DA is ideal to ensure maximum coverage.
	.EXAMPLE
		PS C:\> Find-AdjacentNetworkAccess -Accounts DAUSER:DAPASS -Hosts (Get-Content hosts.txt)
	.EXAMPLE
		PS C:\> Find-AdjacentNetworkAccess -Hosts '10.10.10.10','10.20.20.20' -Credentials "DAUSER:DAPASS"
	.LINK
		https://github.com/a-marionette
		https://twitter.com/__amarionette
#>
	
	[CmdletBinding(DefaultParameterSetName='Hosts')]
	param(
		[Parameter(Mandatory = $True,ParameterSetName="Hosts")]
		[String[]]
		$Hosts = '127.0.0.1',
		
		[Parameter(Mandatory = $False)]
		[String[]]
		$Accounts = '127.0.0.1',
		
		[Parameter(Mandatory = $False)]
		[String[]]
		$Creds = '',
			
		[int]
		$Timeout = 500
	
	)
		
	$defaultcolor = $host.ui.RawUI.ForegroundColor 
		
	#$ErrorActionPreference = "silentlycontinue"
	
	$errormsg = 'null'
	$successmsg = 'null'
		
	"{0,-35}{1,-35}" -f "Host", "Subnets"
		"---------------------------------------------------------------------------------------------"
	
	foreach ($ComputerName in $Hosts){
		$HostIsValid = $True
		if (!(Test-Port -Computer $ComputerName -Port 445 -Timeout $Timeout)) {
					"{0,-35}" -f "Host $ComputerName is not accessible on port 445, skipping!"
					continue
				}
		
		if (!$HostIsValid) {
				continue
			}
		
		$successmsg = $null
		$errormsg = $null

		if ($PSBoundParameters.ContainsKey('Creds'))
		{
		$Credarray = $Creds -split ":"
		$user = $Credarray[0]
		$password =  ConvertTo-SecureString -String $Credarray[1] -AsPlainText -Force
		$Credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $user, $password
		try{
		$WMINetResult = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ComputerName -Credential $Credential -ErrorVariable WMIErr  -filter "NOT ServiceName LIKE '%VM%' AND NOT ServiceName LIKE '%FUTUREUSE%' AND IPenabled = $true"
		}
		catch {
		
		}
		$StandardIPS = $WMINetResult | where{($_.Description -notlike "*VPN*")} | Out-String | %{$_.split("`n")}  | Select-String  -Pattern "(?<!Gateway.*)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" |  % { $_.Matches } | % { $_.Value }
		$VPNIPS = $WMINetResult | where{($_.Description -like "*VPN*")} | Out-String | %{$_.split("`n")}  | Select-String  -Pattern "(?<!Gateway.*)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" |  % { $_.Matches } | % { $_.Value }
		}
		else
		{
		#$IParray = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName 127.0.0.1  -filter "NOT ServiceName LIKE '%VM%' AND NOT ServiceName LIKE '%OTHERSTUFF%' AND IPenabled = $true" | Out-String | %{$_.split("`n")} | Select-String  -Pattern "(?<!Gateway.*)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" |  % { $_.Matches } | % { $_.Value }
		try{
		$WMINetResult = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ComputerName -ErrorVariable WMIErr  -filter "NOT ServiceName LIKE '%VM%' AND NOT ServiceName LIKE '%FUTUREUSE%' AND IPenabled = $true"
		}
		catch{
		$WMIErr
		}
		$StandardIPS = $WMINetResult | where{($_.Description -notlike "*VPN*")} | Out-String | %{$_.split("`n")}  | Select-String  -Pattern "(?<!Gateway.*)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" |  % { $_.Matches } | % { $_.Value }
		$VPNIPS = $WMINetResult | where{($_.Description -like "*VPN*")} | Out-String | %{$_.split("`n")}  | Select-String  -Pattern "(?<!Gateway.*)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" |  % { $_.Matches } | % { $_.Value }

	}
		
		$Subnets = @()
		
		foreach ($IP in $StandardIPS)
		{
		$Subnets += $IP  | Select-String  -Pattern "(\d{1,3}\.\d{1,3}\.\d{1,3})" |  % { $_.Matches } | % { $_.Value }
		}
		
		foreach ($IP in $VPNIPS)
		{
		$Subnets += $IP  | Select-String  -Pattern "(\d{1,3}\.\d{1,3}\.\d{1,3})" |  % { $_.Matches } | % { $_.Value + ' (VPN)' }
		}
		
		## If-Statement is a work around for a casting issue resulting from the 'select'
		
		if (($Subnets | select -unique | out-string).split('.').length -gt 3 )
		{
		$UniqueSubnets = $Subnets | select -unique | Out-String | % {$_.replace("`n","   ")}
		$UniqueSubnets += ' - YES - '
		$host.ui.RawUI.ForegroundColor = “Green”
		}
		elseif ($WMIErr)
		{
		$UniqueSubnets = "No Admin Access.."
		$host.ui.RawUI.ForegroundColor = “Red”
		}
		else
		{
		$UniqueSubnets = "No additional subnets.."
		$host.ui.RawUI.ForegroundColor = “Red”
		}
					
		"{0,-35}{1,-35}" -f $ComputerName, $UniqueSubnets
						
}

$host.ui.RawUI.ForegroundColor = $defaultcolor	


}

function Find-PastUserAccess {

<#
	.SYNOPSIS
		Hunt for systems a user has previously accessed.
		
		Author: Michael Maturi
	.DESCRIPTION
		This script uses the underlying workings of the binary 'GPRESULT'. Verbose error messages will detail when a user has accessed
		a particular host in the past. Using this knowledge, it may be applied to your pentesting endeavors.
	.PARAMETER Hosts
		The hostnames to attempt to authenticate to in a list format. Use
		Get-Content to pipe in the list.
	.PARAMETER Credentials
		The privileged credentials required to execute the GP query.  The proper 
		format for this is "Username:Password", and a DA is ideal to ensure maximum coverage.
	.PARAMETER Accounts
		The accounts to be checked to see if they had at any time accessed any of the hosts provided.
	.EXAMPLE
		PS C:\> Find-PastUserAccess -Accounts (Get-Content accounts.txt) -Hosts (Get-Content hosts.txt)
	.EXAMPLE
		PS C:\> Find-PastUserAccess -Accounts 'LordKnight' -Hosts '10.10.10.10','10.20.20.20' -Credentials "DAUSER:DAPASS"
	.LINK
	https://github.com/a-marionette
	https://twitter.com/__amarionette
#>
	
	[CmdletBinding(DefaultParameterSetName='Accounts')]
	param(
		[Parameter(Mandatory = $True,ParameterSetName="Accounts")]
		[String[]]
		$Accounts = '',
		
		[Parameter(Mandatory = $True)]
		[String[]]
		$Hosts = '127.0.0.1',
		
		[Parameter(Mandatory = $False)]
		[String[]]
		$Creds = '',
			
		[int]
		$Timeout = 500
	
	)
	
	#$ErrorActionPreference = "silentlycontinue"

	$errormsg = 'null'
	$successmsg = 'null'
	
	"{0,-35}{1,-35}{2,-35}" -f "Username", "Host", "Result"
		"---------------------------------------------------------------------------------------------"
	
	foreach ($ComputerName in $Hosts){
		$HostIsValid = $True
		if (!(Test-Port -Computer $ComputerName -Port 445 -Timeout $Timeout)) {
					"{0,-35}" -f "Host $ComputerName is not accessible on port 445, skipping!"
					continue
				}
	
		foreach ($Account in $Accounts){
		
			if (!$HostIsValid) {
					continue
				}
			
			$successmsg = $null
			$errormsg = $null

			if ($PSBoundParameters.ContainsKey('Creds'))
			{
			$Credarray = $Creds -split ":"
			$user = $Credarray[0]
			$pass = $Credarray[1]
			$successmsg = gpresult /r /z /u $user /p $pass /user $Account /S $ComputerName 
			}
			else
			{
			$successmsg = gpresult /r /z /user $Account /S $ComputerName 
			
			}
		
			if ($successmsg -match "Logging Mode")
			{
				
				$result =  'User has accessed this host before!' 
			}
			elseif ($successmsg -match 'not have')
			{
				$result = 'Unlikely to have accessed this host..' 
			}
			else
			{
			$result =  'Error: Invalid account or insufficient permissions?' 
			}
			
			"{0,-35}{1,-35}{2,-35}" -f $Account, $ComputerName, $result
			
			
			#$successmsg | out-file -Append -Force errorlog.txt
			$successmsg | out-null
							
		}
	
	}
		
}


function Test-Port { 
	param ( [string]$Computer, [int]$Port, [int] $Timeout=300 )
	
	$Test = New-Object Net.Sockets.TcpClient
	
	$Test.BeginConnect( $Computer, $Port, $Null, $Null ) | Out-Null
	
	$Time = ( Get-Date ).AddMilliseconds( $Timeout )
	
	While ( -not $Test.Connected -and ( Get-Date ) -lt $Time ) {
		Sleep -Milliseconds 50
	}
	
	#  Return the connection status (Boolean)
	$Test.Connected
		
	# Cleanup
	$Test.Close()
	
	} 