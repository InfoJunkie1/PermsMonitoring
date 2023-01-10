USE [GuardingTheKeys]
GO

/****** Object:  Table [dbo].[AllThePermissions]    Script Date: 1/9/2023 12:14:50 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[AllThePermissions](
	[PermissionsID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [varchar](25) NOT NULL,
	[ObjectName] [nvarchar](256) NULL,
	[LoginName] [nvarchar](256) NULL,
	[RoleName] [varchar](100) NULL,
	[GroupType] [varchar](50) NULL,
	[PermissionLevel] [char](1) NOT NULL,
	[DateAdded] [date] NOT NULL,
	[IsDisabled] [bit] NULL,
 CONSTRAINT [PK_AllThePermissions] PRIMARY KEY CLUSTERED 
(
	[PermissionsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[AllThePermissions] ADD  CONSTRAINT [Permissions_DateAdded]  DEFAULT (getdate()) FOR [DateAdded]
GO

ALTER TABLE [dbo].[AllThePermissions] ADD  CONSTRAINT [Permissions_IsDisabled]  DEFAULT ((0)) FOR [IsDisabled]
GO

ALTER TABLE [dbo].[AllThePermissions]  WITH CHECK ADD  CONSTRAINT [chk_AllThePermissions_permission_level] CHECK  (([PermissionLevel]='D' OR [PermissionLevel]='S' OR [PermissionLevel]='O'))
GO

ALTER TABLE [dbo].[AllThePermissions] CHECK CONSTRAINT [chk_AllThePermissions_permission_level]
GO


