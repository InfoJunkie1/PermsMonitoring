#-------------------------------------------------------
#Script out user permissions for each instance
#Is run through job XXXXXXXX on ServerNameXXXXX at 6 a.m. (or whatever time)
#
#Change History
#------------------------------------------------------
# Date          Author                	Reason
#------------------------------------------------------
# 2023-01-10	Sharon Reid				Initial release
#------------------------------------------------------

import-module -name 'dbatools'
$sqlservers = Get-Content "C:\SQLBackups\permissions\Instances.txt"

foreach($sqlserver in $sqlservers)
{
	$currdate = (get-date).tostring("yyyyMMdd")
	
	#create needed folders
	$currPath = "C:\SQLBackups\permissions\$sqlServer";
	if($false -eq (test-path -path $currPath ) )
	{
		New-Item -Path $currPath -ItemType directory
	}
	
	$currPath = "C:\SQLBackups\permissions\$sqlServer\$currdate";
	if ( $false -eq ( test-path -path $currPath ) )
	{
		New-Item -Path $currPath -ItemType directory
	}
	
	#create sql script of users
	$filename = "C:\SQLBackups\permissions\$sqlserver\$currdate\DBPermissions_$sqlserver`_$currdate.sql" 
	Export-DBAUser -SqlInstance $sqlServer -filepath $filename  
	
	#create sql script of logins
    $filename = "C:\SQLBackups\permissions\$sqlserver\$currdate\LoginPermissions_$sqlserver`_$currdate.sql"
	Export-DBAlogin -SqlInstance $sqlServer -filepath $filename 
}
	
	