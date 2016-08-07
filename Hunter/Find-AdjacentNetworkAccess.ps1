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

