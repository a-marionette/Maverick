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
