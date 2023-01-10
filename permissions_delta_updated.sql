USE [GuardingTheKeys]
GO

/****** Object:  StoredProcedure [dbo].[permissions_delta]    Script Date: 1/9/2023 1:06:39 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER       PROCEDURE [dbo].[permissions_delta]
(
    @compareStartDate DATE,
    @compareEndDate DATE
)
AS
/******************************************************************************
* Description: Returns a comparison of permissions between 2 dates
*			
* Procedure Test: 

	DECLARE @s DATE = CAST(DATEADD(DAY, -10, GETDATE()) AS DATE)
	DECLARE @e DATE = GETDATE()
	EXEC [dbo].[permissions_delta] @compareStartDate = @s, @compareEndDate = @e

* Change History:
* -----------------------------------------------------------------------------
* Date			|Author				|Reason
* -----------------------------------------------------------------------------
* 2022-01-08	Sharon				Initial Release
*******************************************************************************/
BEGIN

    SET NOCOUNT ON;
 
    (SELECT p.ServerName,
            COALESCE(p.ObjectName,'') AS ObjectName,
            p.LoginName,
            p.RoleName,
            p.GroupType,
            CASE p.PermissionLevel
                WHEN 'D' THEN 'Database'
                WHEN 'O' THEN 'Object'
                WHEN 'S' THEN 'Server'
                ELSE 'Unknown'
            END AS PermissionLevel,
            'Added' AS PermDelta
     FROM dbo.AllThePermissions AS p
     WHERE p.DateAdded = @compareEndDate
     EXCEPT
     SELECT p.ServerName,
            COALESCE(p.ObjectName,'') AS ObjectName,
            p.LoginName,
            p.RoleName,
            p.GroupType,
            CASE p.PermissionLevel
                WHEN 'D' THEN 'Database'
                WHEN 'O' THEN 'Object'
                WHEN 'S' THEN 'Server'
                ELSE 'Unknown'
            END AS PermissionLevel,
            'Added' AS PermDelta
     FROM dbo.AllThePermissions AS p
     WHERE p.DateAdded = @compareStartDate) 

UNION 

    (SELECT p.ServerName,
            COALESCE(p.ObjectName,'') AS ObjectName,
            p.LoginName,
            p.RoleName,
            p.GroupType,
            CASE p.PermissionLevel
                WHEN 'D' THEN 'Database'
                WHEN 'O' THEN 'Object'
                WHEN 'S' THEN 'Server'
                ELSE 'Unknown'
            END AS PermissionLevel,
            'Dropped' AS PermDelta
     FROM dbo.AllThePermissions AS p
     WHERE p.DateAdded = @compareStartDate
     EXCEPT
     SELECT p.ServerName,
            COALESCE(p.ObjectName,'') AS ObjectName,
            p.LoginName,
            p.RoleName,
            p.GroupType,
            CASE p.PermissionLevel
                WHEN 'D' THEN 'Database'
                WHEN 'O' THEN 'Object'
                WHEN 'S' THEN 'Server'
                ELSE 'Unknown'
            END AS PermissionLevel,
            'Dropped' AS PermDelta
     FROM dbo.AllThePermissions AS p
     WHERE p.DateAdded = @compareEndDate)

    ORDER BY PermDelta, ServerName, ObjectName, LoginName;

END;
GO


