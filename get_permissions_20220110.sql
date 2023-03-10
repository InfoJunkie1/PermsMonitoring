USE GuardingTheKeys
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO



CREATE OR ALTER PROCEDURE [dbo].[get_permissions]
(
	@TestMode BIT = 0
	, @PerformDirectInsert BIT = 0
)
AS
/******************************************************************************
* Description: 	Pulls all permissions for users on production servers. This is modeled
	after sproc written by Clayton Hoyt
*			
* Procedure Test: 

	EXEC [dbo].[get_permissions] @TestMode = 1

	EXEC [dbo].[get_permissions] @TestMode = 0, @PerformDirectInsert = 1							

* Change History:
* -----------------------------------------------------------------------------
* Date			|Author				|Reason
* -----------------------------------------------------------------------------
* 01/10/2023	Sharon Reid		Initial Release

*******************************************************************************/
BEGIN

    SET NOCOUNT ON;

    DECLARE @db sysname
          , @dbCursor CURSOR
          , @SQL NVARCHAR(MAX)
          , @actualDbCount INT = 0
          , @expectedDbCount INT = 0
          , @i INT = 0;

	DECLARE @v CHAR(1) = CAST(@PerformDirectInsert AS CHAR(1));
    RAISERROR ('PERM: Perform Direct Insert - %s', 10, 1, @v) WITH LOG;

    CREATE TABLE #sec
    (
        ServerName VARCHAR(25) NOT NULL
      , ObjectName VARCHAR(256) NULL
      , LoginName VARCHAR(256) NULL
      , RoleName VARCHAR(100) NULL
      , GroupType VARCHAR(50) NULL
      , PermissionLevel CHAR(1) NOT NULL
      , IsDisabled BIT NOT NULL
            DEFAULT 0
    );
    CREATE TABLE #t (SID VARBINARY(100) NOT NULL, NTLoginName sysname NOT NULL);

    SET @expectedDbCount =
        (
            SELECT COUNT (*)
            FROM sys.databases d
            WHERE d.source_database_id IS NULL
                  AND d.state_desc = 'ONLINE'
                  AND d.is_read_only = 0
                  AND d.name NOT IN ('tempdb')
        );
    --select * from 

	--Database permissions
    RAISERROR ('PERM: Expected DB Count of [%d] established', 10, 1, @expectedDbCount) WITH LOG;

    SET @dbCursor = CURSOR FAST_FORWARD LOCAL FOR
    SELECT d.name
    FROM sys.databases d
    WHERE d.source_database_id IS NULL
          AND d.state_desc = 'ONLINE'
          AND d.name NOT IN ('tempdb')
          AND d.is_read_only = 0

    ORDER BY name;

    RAISERROR ('PERM: Cursor established', 10, 1) WITH LOG;

    OPEN @dbCursor;

    FETCH NEXT FROM @dbCursor
    INTO @db;

    WHILE (@@FETCH_STATUS = 0)
    BEGIN

        SET @actualDbCount = @actualDbCount + 1;
        RAISERROR ('PERM: Current Database Collection Is [%s].', 10, 1, @db) WITH LOG;
        BEGIN TRY
            SET @SQL
                = N'USE [' + @db + N']; '
                  + N'INSERT INTO #sec (ServerName,ObjectName,LoginName,RoleName,GroupType,PermissionLevel,IsDisabled)
					 SELECT  DISTINCT 
							 @@SERVERNAME, 
							 DB_NAME() COLLATE SQL_Latin1_General_CP1_CI_AS,
							 s.name AS LoginName, 
							 p.name COLLATE SQL_Latin1_General_CP1_CI_AS AS RoleName, 
							 ISNULL(s.Type_Desc, ''UNKNOWN'') AS GroupType,							
							 ''D'' AS PermissionLevel,
							 sp.is_disabled
					 FROM sys.database_role_members m
						INNER JOIN sys.database_principals p ON m.role_principal_id = p.principal_id
						INNER JOIN sys.database_principals s ON m.member_principal_id = s.principal_id  						
						INNER JOIN sys.server_principals sp ON sp.sid = s.SID
					WHERE (s.name NOT IN (''dbo'')';

            SET @SQL
                = @SQL
                  + N') 

					UNION ALL
					
					-- Pickup Orphaned Users
					----------------------------------
					SELECT	@@SERVERNAME,
							DB_NAME() COLLATE SQL_Latin1_General_CP1_CI_AS AS Object,
							p.Name as LogingName,
							''Orphan'',
							''ORPHAN_SQL_LOGIN'',
							''D'',
							0
					FROM sys.database_principals p
					WHERE p.SID NOT IN (SELECT SID FROM sys.server_principals)
						AND p.name NOT IN (''dbo'', ''guest'',''INFORMATION_SCHEMA'',''sys'',''MS_DataCollectorInternalUser'')						
						AND type_desc <> ''DATABASE_ROLE''

					UNION ALL

					SELECT	@@SERVERNAME,
							CASE 
								WHEN class_desc = ''OBJECT_OR_COLUMN'' THEN ''[' + @db
                  + N'].['' + ISNULL(s.name, '''') + ''].['' + ISNULL(so.name, '''') + '']''
								WHEN class_desc = ''DATABASE'' THEN ''' + @db
                  + N'''
								WHEN class_desc = ''SCHEMA'' THEN ''[' + @db
                  + N'].['' + (SCHEMA_NAME(m.major_id)) + '']''
								WHEN class_desc = ''TYPE'' THEN TYPE_NAME([major_id])
								WHEN class_desc = ''DATABASE_PRINCIPAL'' THEN (SELECT [name]
																			   FROM  sys.database_principals
																			   WHERE  [principal_id] = [major_id])
								WHEN class_desc = ''XML_SCHEMA_COLLECTION'' THEN (SELECT   [name]
																			   FROM     sys.xml_schema_collections
																			   WHERE    [xml_collection_id] = [major_id])
								WHEN class_desc = ''MESSAGE_TYPE'' THEN (SELECT   [name]
																	     FROM     sys.service_message_types
																	     WHERE    [message_type_id] = [major_id])
								WHEN class_desc = ''SERVICE_CONTRACT'' THEN (SELECT   [name]
																		     FROM     sys.service_contracts
																		     WHERE    [service_contract_id] = [major_id])
								WHEN class_desc = ''SERVICE'' THEN (SELECT   [name]
																    FROM     sys.services
																	WHERE    [service_id] = [major_id])
								WHEN class_desc = ''REMOTE_SERVICE_BINDING'' THEN (SELECT   [name]
																				   FROM     sys.remote_service_bindings
																				   WHERE    [remote_service_binding_id] = [major_id])																			  
								WHEN class_desc = ''ROUTE'' THEN (SELECT   [name]
																  FROM     sys.routes
																  WHERE    [route_id] = [major_id])
								WHEN class_desc = ''FULLTEXT_CATALOG'' THEN (SELECT   [name]
																 		     FROM     sys.fulltext_catalogs
																			 WHERE    [fulltext_catalog_id] = [major_id])
								WHEN class_desc = ''SYMMETRIC_KEY'' THEN (SELECT   [name]
																		  FROM     sys.symmetric_keys
																		  WHERE    [symmetric_key_id] = [major_id])
								WHEN class_desc = ''CERTIFICATE'' THEN (SELECT   [name]
																		FROM     sys.certificates
																		WHERE    [certificate_id] = [major_id])
								WHEN class_desc = ''ASYMMETRIC_KEY'' THEN (SELECT   [name]
																		   FROM     sys.asymmetric_keys
																		   WHERE    [asymmetric_key_id] = [major_id])

								WHEN class_desc IS NULL THEN CAST(m.major_id AS NVARCHAR(60))
								
								ELSE class_desc + '' '' + CAST(m.major_id AS NVARCHAR(60)) +  CAST(m.minor_id AS NVARCHAR(60))
								
							END  COLLATE SQL_Latin1_General_CP1_CI_AS AS object,
							p.name,
							m.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS as permission_name,
							p.type_desc,
							''O'',
							sp.is_disabled
					FROM sys.database_permissions m 
						INNER JOIN sys.database_principals p on m.grantee_principal_id = p.principal_id 
						INNER JOIN sys.server_principals sp ON sp.sid = p.SID
						LEFT OUTER JOIN sys.objects so ON m.major_id = so.object_id
						LEFT OUTER JOIN sys.schemas s ON so.schema_id = s.schema_id
					WHERE (m.Major_ID > -1 
						AND m.state_desc IN (''GRANT'', ''GRANT_WITH_GRANT_OPTION'')';

            SET @SQL
                = @SQL
                  + N') 
						   ';

            RAISERROR ('PERM: Starting Write Of Database Collection for [%s].', 10, 1, @db) WITH LOG;
            EXEC sys.sp_executesql @stmt = @SQL;
            RAISERROR ('PERM: Finished Database Collection for [%s].', 10, 1, @db) WITH LOG;

        END TRY
        BEGIN CATCH
            DECLARE @msg VARCHAR(MAX);
            SET @msg
                = 'PERM: Error attempting security check of [' + @db
                  + '] during permissions collection. Skipping to next database. ' + ERROR_MESSAGE ();
            RAISERROR ('%s', 10, 1, @msg) WITH LOG;
        END CATCH;

        FETCH NEXT FROM @dbCursor
        INTO @db;

    END;

    CLOSE @dbCursor;
    DEALLOCATE @dbCursor;

    -- SERVER ROLES 
    INSERT INTO #sec
    (
        ServerName, ObjectName, LoginName, RoleName, GroupType, PermissionLevel, IsDisabled
    )
    SELECT @@SERVERNAME
         , NULL
         , p.[name]
         , rp.name COLLATE SQL_Latin1_General_CP1_CI_AS
         , p.type_desc AS loginType
         , 'S'
         , p.is_disabled
    FROM sys.server_principals p
    JOIN sys.server_role_members RM
        ON p.principal_id = RM.member_principal_id
    JOIN sys.server_principals rp
        ON RM.role_principal_id = rp.principal_id;

	--Server securables
    INSERT INTO #sec
    (
        ServerName, ObjectName, LoginName, RoleName, GroupType, PermissionLevel, IsDisabled
    )
    SELECT @@SERVERNAME
         , NULL
         , p.[name]
         , CASE Sp.type
               WHEN 'AAES' THEN
                   'ALTER ANY EVENT SESSION'
               WHEN 'ADBO' THEN
                   'ADMINISTER BULK OPERATIONS'
               WHEN 'AL' THEN
                   'ALTER'
               WHEN 'ALAA' THEN
                   'ALTER ANY SERVER AUDIT'
               WHEN 'ALAG' THEN
                   'ALTER ANY AVAILABILITY GROUP'
               WHEN 'ALCD' THEN
                   'ALTER ANY CREDENTIAL'
               WHEN 'ALCO' THEN
                   'ALTER ANY CONNECTION'
               WHEN 'ALDB' THEN
                   'ALTER ANY DATABASE'
               WHEN 'ALES' THEN
                   'ALTER ANY EVENT NOTIFICATION'
               WHEN 'ALHE' THEN
                   'ALTER ANY ENDPOINT'
               WHEN 'ALLG' THEN
                   'ALTER ANY LOGIN'
               WHEN 'ALLS' THEN
                   'ALTER ANY LINKED SERVER'
               WHEN 'ALRS' THEN
                   'ALTER RESOURCES'
               WHEN 'ALSR' THEN
                   'ALTER ANY SERVER ROLE'
               WHEN 'ALSS' THEN
                   'ALTER SERVER STATE'
               WHEN 'ALST' THEN
                   'ALTER SETTINGS'
               WHEN 'ALTR' THEN
                   'ALTER TRACE'
               WHEN 'AUTH' THEN
                   'AUTHENTICATE SERVER'
               WHEN 'CADB' THEN
                   'CONNECT ANY DATABASE'
               WHEN 'CL' THEN
                   'CONTROL SERVER'
               WHEN 'CO' THEN
                   'CONNECT'
               WHEN 'COSQ' THEN
                   'CONNECT SQL'
               WHEN 'CRAC' THEN
                   'CREATE AVAILABILITY GROUP'
               WHEN 'CRDB' THEN
                   'CREATE ANY DATABASE'
               WHEN 'CRDE' THEN
                   'CREATE DDL EVENT NOTIFICATION'
               WHEN 'CRHE' THEN
                   'CREATE ENDPOINT'
               WHEN 'CRSR' THEN
                   'CREATE SERVER ROLE'
               WHEN 'CRTE' THEN
                   'CREATE TRACE EVENT NOTIFICATION'
               WHEN 'IM' THEN
                   'IMPERSONATE'
               WHEN 'SHDN' THEN
                   'SHUTDOWN'
               WHEN 'SUS' THEN
                   'SELECT ALL USER SECURABLES'
               WHEN 'TO' THEN
                   'TAKE OWNERSHIP'
               WHEN 'VW' THEN
                   'VIEW DEFINITION'
               WHEN 'VWAD' THEN
                   'VIEW ANY DEFINITION'
               WHEN 'VWDB' THEN
                   'VIEW ANY DATABASE'
               WHEN 'VWSS' THEN
                   'VIEW SERVER STATE'
               WHEN 'XA' THEN
                   'EXTERNAL ACCESS'
               WHEN 'XU' THEN
                   'UNSAFE ASSEMBLY'
               ELSE
                   Sp.type
           END AS RoleName
         , p.type_desc
         , 'S'
         , p.is_disabled
    FROM sys.server_principals AS p
    JOIN sys.server_permissions AS Sp
        ON p.principal_id = Sp.grantee_principal_id
    WHERE Sp.class = 100
          AND Sp.state IN ('G', 'W') -- Grant or Grant w Grant Option
          AND Sp.[type] NOT IN ('CO', 'COSQ')


    RAISERROR ('PERM: Server level permissions collected', 10, 1) WITH LOG;

	--test mode
    IF (@TestMode = 1)
    BEGIN
        SELECT s.ServerName
             , CASE
                   WHEN s.PermissionLevel = 'S' THEN
                       'Server'
                   ELSE
                       s.ObjectName
               END AS ObjectName
             , s.LoginName
             , s.RoleName
             , s.GroupType
             , CASE s.PermissionLevel
                   WHEN 'S' THEN
                       'Server'
                   WHEN 'D' THEN
                       'Database'
                   WHEN 'O' THEN
                       'Object'
                   ELSE
                       ''
               END AS PermissionLevel
             , s.IsDisabled
        FROM #sec AS s
		WHERE LoginName not like '##%'
		AND	(RoleName NOT IN ('CONNECT', 'CONNECT SQL')
              OR
                  (
                      LoginName IN ('guest', 'public')
                      AND RoleName IN ('CONNECT', 'CONNECT SQL')
                  ))
        ORDER BY ObjectName, s.LoginName, s.RoleName;
    END;

	--write to table
    ELSE IF (@PerformDirectInsert = 1)
    BEGIN

		--Delete previous entries from today so that we don't accidentally double insert if troubleshooting
        DELETE FROM dbo.AllThePermissions
        WHERE ServerName = @@SERVERNAME
              AND DateAdded = CAST(GETDATE () AS DATE);

        SET @i = @@ROWCOUNT;
        RAISERROR ('PERM: %d records were deleted from Elevated Permissions for today.', 10, 1, @i) WITH LOG;

		--Insert those perms into dbo.AllThePermissions table
        INSERT INTO dbo.AllThePermissions
        (
            ServerName, ObjectName, LoginName, RoleName, GroupType, PermissionLevel, IsDisabled
        )
        SELECT UPPER (ServerName) AS ServerName
             , ObjectName
             , LoginName
             , RoleName
             , GroupType
             , PermissionLevel
             , IsDisabled
        FROM #sec
		WHERE LoginName not like '##%'
		AND	(RoleName NOT IN ('CONNECT', 'CONNECT SQL')
              OR
                  (
                      LoginName IN ('guest', 'public')
                      AND RoleName IN ('CONNECT', 'CONNECT SQL')
                  ))

        SET @i = @@ROWCOUNT;
        RAISERROR ('PERM: %d records were inserted into Elevated Permissions for today.', 10, 1, @i) WITH LOG;

    END;
    ELSE
    BEGIN
        SELECT ServerName, ObjectName, LoginName, RoleName, GroupType, PermissionLevel, IsDisabled
        FROM #sec
        WHERE LoginName not like '##%'
		AND	(RoleName NOT IN ('CONNECT', 'CONNECT SQL')
              OR
                  (
                      LoginName IN ('guest', 'public')
                      AND RoleName IN ('CONNECT', 'CONNECT SQL')
                  ))
    END;


    RAISERROR ('PERM: Final Insert/Select', 10, 1) WITH LOG;

    IF OBJECT_ID ('tempdb..#t') IS NOT NULL
        DROP TABLE #t;
    IF OBJECT_ID ('tempdb..#sec') IS NOT NULL
        DROP TABLE #sec;

	--Logging whether or not the expected database count and actual database count match
    IF (@actualDbCount <> @expectedDbCount)
        RAISERROR (
                      'PERM: FAILURE COLLECTING PERMISSIONS: %d databases were expected to be reviewed but only %d were actually tested. The process should be rerun for this server.'
                    , 16
                    , 1
                    , @expectedDbCount
                    , @actualDbCount
                  ) WITH LOG;
    ELSE
        RAISERROR (
                      'PERM: %d databases were expected to be reviewed and %d were actually tested.'
                    , 10
                    , 1
                    , @expectedDbCount
                    , @actualDbCount
                  ) WITH LOG;
END;
