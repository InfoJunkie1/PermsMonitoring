#-------------------------------------------------------
#Monitors for permission backup files > 30 days old
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
	get-childItem -Path "C:\SQLBackups\permissions" -Recurse | where-object ( $_.LastWriteTime -le (get-date).addDays( -30 ) ) |Remove-Item -Recurse;
}
	