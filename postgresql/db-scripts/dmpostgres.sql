--pre_schema
-- DROP DATABASE IF EXISTS ignite;
-- CREATE DATABASE "ignite";

\connect "ignite";

--hcp_services_db_create
DROP TYPE IF EXISTS GROUP_TYPE CASCADE;
CREATE TYPE GROUP_TYPE as ENUM ('NORMAL','CAMPAIGN');

CREATE TABLE IF NOT EXISTS "Device"
(
    "ID" bigserial NOT NULL,
    "HarmanID" character varying,
    "PassCode" character varying,
    "ActivationDate" timestamp with time zone,
    "UpdatedAt" timestamp with time zone,
    "RandomNumber" bigint NOT NULL,
    "IsActive" boolean,
    "registered_scope_id" character varying,
    CONSTRAINT "PK_ID" PRIMARY KEY ("ID"),
    CONSTRAINT "unique_Device_HarmanID" UNIQUE ("HarmanID")
);

CREATE TABLE IF NOT EXISTS "DeviceInfo"
(
    "HarmanID" character varying NOT NULL,
    "Name" character varying NOT NULL,
    "Value" character varying NOT NULL,
    CONSTRAINT "PK_DeviceInfo_All3PK" PRIMARY KEY ("HarmanID", "Name")
);

-- Create scripts for User-Role services - START

CREATE TABLE IF NOT EXISTS "User"
(
    "ID" bigserial NOT NULL,
    "UserID" character varying,
    "FirstName" character varying,
    "LastName" character varying,
    "Password" character varying,
    "DateCreated" timestamp with time zone,
    "DateUpdated" timestamp with time zone,
    "CreatedBy" bigint NOT NULL,
    "UpdatedBy" bigint,
    "IsValid" boolean,
    "Email" character varying,
    "ChangePasswordSerial" bigint DEFAULT 0,
    CONSTRAINT "pk_User_ID" PRIMARY KEY ("ID"),
    CONSTRAINT "unique_UserID" UNIQUE ("UserID")
);

CREATE TABLE IF NOT EXISTS "Role"
(
    "RoleName" character varying,
    "Desc" character varying,
    "RoleID" serial NOT NULL,
    "CreatedAt" timestamp with time zone,
    "ModifiedAt" timestamp with time zone,
    "UpdaterID" character varying,
    CONSTRAINT "PK_Role_RoleID" PRIMARY KEY ("RoleID"),
    CONSTRAINT "fk_UserID" FOREIGN KEY ("UpdaterID")
        REFERENCES "User" ("UserID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS "UserRole"
(
    "ID" bigserial NOT NULL,
    "UserID" bigint NOT NULL,
    "RoleID" bigint NOT NULL,
    "UpdatedBy" bigint,
    "Deleted" boolean,
    CONSTRAINT "pk_UserRole_userID_roleID" PRIMARY KEY ("UserID", "RoleID"),
    CONSTRAINT "fk_UserRole_roleID" FOREIGN KEY ("RoleID")
        REFERENCES "Role" ("RoleID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "fk_UserRole_userID" FOREIGN KEY ("UserID")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


-- Create scripts for User-Role services - END

-- Queries for Request Account setup - START

CREATE TABLE IF NOT EXISTS "APP"
(
    "APPID" bigserial NOT NULL,
    "APPNAME" character varying,
    CONSTRAINT "PK_APPID" PRIMARY KEY ("APPID"),
    CONSTRAINT "UNIQUE_APPNAME" UNIQUE ("APPNAME")
);

CREATE TABLE IF NOT EXISTS "APPROLE"
(
    "APPID" bigint,
    "ROLEID" bigint,
    CONSTRAINT "FK_APPID" FOREIGN KEY ("APPID")
        REFERENCES "APP" ("APPID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_ROLEID" FOREIGN KEY ("ROLEID")
        REFERENCES "Role" ("RoleID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "UNIQUE_APP_ROLE" UNIQUE ("APPID", "ROLEID")
);

CREATE TABLE IF NOT EXISTS "ROLEADMIN"
(
    "ADMINID" bigint NOT NULL,
    "ROLEID" bigint NOT NULL,
    CONSTRAINT "PK_ROLEADMIN_ADMINID_ROLEID" PRIMARY KEY ("ADMINID", "ROLEID"),
    CONSTRAINT "FK_ROLEADMIN_ADMINID" FOREIGN KEY ("ADMINID")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_ROLEADMIN_ROLEID" FOREIGN KEY ("ROLEID")
        REFERENCES "Role" ("RoleID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS "APPURL"
(
    "APPID" bigint,
    "URL" character varying,
    "ID" bigserial NOT NULL,
    CONSTRAINT "PK_APPURL_ID" PRIMARY KEY ("ID"),
    CONSTRAINT "FK_APPURL_APPID" FOREIGN KEY ("APPID")
        REFERENCES "APP" ("APPID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

-- Queries for Request Account setup - END

-- Notification script -- START
CREATE TABLE IF NOT EXISTS "Notification"
(
    "NotificationID" bigserial NOT NULL,
    "Type" character varying,
    "SubType" character varying,
    "Message" character varying NOT NULL,
    "ExpirationDate" timestamp with time zone,
    "Deleted" boolean NOT NULL,
    "UpdatedAt" timestamp with time zone,
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedBy" character varying NOT NULL,
    "UpdatedBy" character varying,
    "Name" character varying NOT NULL,
    CONSTRAINT "PK_Notification_NotificationID" PRIMARY KEY ("NotificationID"),
    CONSTRAINT "UK_Notification_Name_CreatedBy" UNIQUE ("Name", "CreatedBy")
);

CREATE TABLE IF NOT EXISTS "DeviceNotification"
(
    "DeviceNotificationID" bigserial NOT NULL,
    "HarmanID" character varying NOT NULL,
    "NotificationID" bigint NOT NULL,
    "ExpirationDate" timestamp with time zone,
    "CreatedBy" character varying NOT NULL,
    "UpdatedBy" character varying,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone,
    "CurrentStatus" character varying NOT NULL,
    "RequestID" bigint NOT NULL,
    CONSTRAINT "PK_DeviceNotification_DeviceNotificationID" PRIMARY KEY ("DeviceNotificationID"),
    CONSTRAINT "FK_DeviceNotification_HarmanID" FOREIGN KEY ("HarmanID")
        REFERENCES "Device" ("HarmanID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_DeviceNotification_NotificationID" FOREIGN KEY ("NotificationID")
        REFERENCES "Notification" ("NotificationID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "UK_DeviceNotification_HarmanID_NotificationID_RequestID" UNIQUE ("HarmanID", "NotificationID", "RequestID")
);

-- DeviceNotifictaionArchive table is now called the following --
CREATE TABLE IF NOT EXISTS "DeviceNotificationProcessed"
(
    "DeviceNotificationID" bigint NOT NULL,
    "HarmanID" character varying NOT NULL,
    "NotificationID" bigint NOT NULL,
    "CreatedBy" character varying NOT NULL,
    "UpdatedBy" character varying,
    "ExpirationDate" timestamp with time zone,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone,
    "CurrentStatus" character varying NOT NULL,
    "RequestID" bigint NOT NULL,
    CONSTRAINT "FK_DeviceNotificationProcessed_CreatedBy" FOREIGN KEY ("CreatedBy")
        REFERENCES "User" ("UserID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_DeviceNotificationProcessed_HarmanID" FOREIGN KEY ("HarmanID")
        REFERENCES "Device" ("HarmanID") MATCH FULL
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_DeviceNotificationProcessed_NotificationID" FOREIGN KEY ("NotificationID")
        REFERENCES "Notification" ("NotificationID") MATCH FULL
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_DeviceNotificationProcessed_UpdatedBy" FOREIGN KEY ("UpdatedBy")
        REFERENCES "User" ("UserID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS "NotificationState"
(
    "Status" character varying NOT NULL,
    "TimeStamp" timestamp with time zone NOT NULL,
    "DeviceNotificationID" bigint NOT NULL,
    "StateID" bigserial NOT NULL
);

CREATE TABLE IF NOT EXISTS "DeviceInfoFactoryData"
(
    "ID" bigserial NOT NULL,
    "manufacturing_date" timestamp with time zone NOT NULL,
    "model" character varying NOT NULL,
    "imei" character varying UNIQUE NOT NULL,
    "serial_number" character varying UNIQUE NOT NULL,
    "package_serial_number" character varying,
    "platform_version" character varying NOT NULL,
    "iccid" character varying UNIQUE NOT NULL,
    "ssid" character varying UNIQUE NOT NULL,
    "bssid" character varying UNIQUE NOT NULL,
    "msisdn" character varying UNIQUE NOT NULL,
    "imsi" character varying UNIQUE NOT NULL,
    "record_date" timestamp with time zone NOT NULL,
    "created_date" timestamp with time zone NOT NULL,
    "factory_admin" character varying NOT NULL,
    "state" character varying NOT NULL,
    "isstolen" boolean NOT NULL default FALSE,
    "isfaulty" boolean NOT NULL default FALSE,
    CONSTRAINT "PK_DeviceInfoFactoryData" PRIMARY KEY ("ID"),
    CONSTRAINT "UK_DeviceInfoFactoryData" UNIQUE ("imei", "iccid", "ssid", "serial_number", "bssid", "msisdn", "imsi")
);


CREATE TABLE IF NOT EXISTS "DeviceInfoFactoryDataHistory"
(
    "ID" bigserial NOT NULL,
    "factory_id" bigserial NOT NULL,
    "manufacturing_date" timestamp with time zone NOT NULL,
    "model" character varying NOT NULL,
    "imei" character varying NOT NULL,
    "serial_number" character varying NOT NULL,
    "package_serial_number" character varying,
    "platform_version" character varying NOT NULL,
    "iccid" character varying NOT NULL,
    "ssid" character varying NOT NULL,
    "bssid" character varying NOT NULL,
    "msisdn" character varying NOT NULL,
    "imsi" character varying NOT NULL,
    "record_date" timestamp with time zone NOT NULL,
    "factory_created_date" timestamp with time zone NOT NULL,
    "factory_admin" character varying NOT NULL,
    "state" character varying NOT NULL,
    "action" character varying NOT NULL,
    "created_timestamp" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_DeviceInfoFactoryDataHistory" PRIMARY KEY ("ID")
);

CREATE TABLE IF NOT EXISTS "HCPInfo"
(
    "ID" bigserial NOT NULL,
    "HarmanID" character varying NOT NULL,
    "VIN" character varying,
    "SerialNumber" character varying,
    "CreatedAt" timestamp with time zone,
    "UpdatedAt" timestamp with time zone,
    factory_data bigint,
    CONSTRAINT fk_factoryID FOREIGN KEY (factory_data) REFERENCES "DeviceInfoFactoryData" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "pk_HCPInfo_HarmanID" PRIMARY KEY ("HarmanID"),
    CONSTRAINT "unique_HCPInfo_factory_data" UNIQUE ("factory_data")
);

CREATE TABLE IF NOT EXISTS device_association(
                                   id                  bigserial primary key,
                                   serial_number       character varying not null,
                                   user_id             character varying not null,
                                   harman_id            character varying,
                                   association_status  character varying not null,
                                   associated_on       timestamp with time zone NOT NULL,
                                   associated_by       character varying NOT NULL,
                                   disassociated_on    timestamp with time zone,
                                   disassociated_by    character varying,
                                   modified_on         timestamp with time zone,
                                   modified_by         character varying,
                                   factory_data bigint,
                                   CONSTRAINT fk_factoryID FOREIGN KEY (factory_data) REFERENCES "DeviceInfoFactoryData" ("ID") MATCH SIMPLE
                                       ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS hcp_task_state(
                               "ID" bigserial NOT NULL,
                               task_id bigserial PRIMARY KEY,
                               task_type character varying NOT NULL,
                               task_status character varying NOT NULL,
                               start_time timestamp with time zone NOT NULL,
                               end_time timestamp with time zone,
                               task_input character varying NOT NULL,
                               result character varying NOT NULL
);

-- RequestID generating sequence --
CREATE SEQUENCE IF NOT EXISTS notification_request_id
    INCREMENT 1
  MINVALUE 1
  MAXVALUE 4294967295
  START 75
  CACHE 1;


-- Notification script -- END


-- Access RequestID generating sequence --
CREATE SEQUENCE IF NOT EXISTS "public"."access_request_id"
    INCREMENT 1
 MINVALUE 1
 MAXVALUE 4294967295
 START 1
 CACHE 1;

-- sequence common to for notification and configuration
CREATE SEQUENCE IF NOT EXISTS "public"."request_id"
    INCREMENT 1
 MINVALUE 1
 MAXVALUE 4294967295
 START 1
 CACHE 1;


-- Create scripts for Grouping - START

CREATE TABLE IF NOT EXISTS "Group"
(
    "GroupID" bigserial NOT NULL,
    "Name" text,
    "Description" text,
    "CreatedAt" timestamp with time zone,
    "LastUpdated" timestamp with time zone,
    "Deleted" boolean,
    "Type" group_type NOT NULL DEFAULT 'NORMAL'::GROUP_TYPE,
    /* "Type" character varying,*/
    "CreatedBy" bigint,
    "UpdatedBy" bigint,
    "ParentGroupID" bigint,
    CONSTRAINT pk_group_id PRIMARY KEY ("GroupID"),
    CONSTRAINT "fk_Group_CreatedBy" FOREIGN KEY ("CreatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "fk_Group_UpdatedBy" FOREIGN KEY ("UpdatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT unique_groupname UNIQUE ("Name")
)
    WITH (
        OIDS=FALSE
        );

CREATE TABLE IF NOT EXISTS "DeviceGroup"
(
    "ID" bigserial NOT NULL,
    "GroupID" bigint,
    "HarmanID" text,
    "CreatedAt" timestamp with time zone,
    "CreatedBy" bigint,
    "UpdatedBy" bigint,
    "UpdatedAt" timestamp with time zone,
    CONSTRAINT pk_devicegrouparchive_id PRIMARY KEY ("ID"),
    CONSTRAINT "fk_devicegroup_createdBy" FOREIGN KEY ("CreatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_devicegroup_updatedby FOREIGN KEY ("UpdatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_groupid_devicegrouparchive FOREIGN KEY ("GroupID")
        REFERENCES "Group" ("GroupID") MATCH FULL
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_harmanid_devicegrouparchive FOREIGN KEY ("HarmanID")
        REFERENCES "Device" ("HarmanID") MATCH FULL
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS "NotificationDeviceGroup"
(
    "ID" bigserial NOT NULL,
    "NotificationID" bigint NOT NULL,
    "HarmanID" character varying NOT NULL,
    "GroupID" bigint NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedBy" character varying NOT NULL,
    "UpdatedAt" timestamp with time zone,
    "UpdatedBy" character varying,
    "ExpiryDate" timestamp with time zone,
    "Deleted" boolean NOT NULL,
    CONSTRAINT "PK_NotificationDeviceGroupID" PRIMARY KEY ("ID"),
    CONSTRAINT "FK_NotificationDeviceGroup_CreatedBy" FOREIGN KEY ("CreatedBy")
        REFERENCES "User" ("UserID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_NotificationDeviceGroup_GroupID" FOREIGN KEY ("GroupID")
        REFERENCES "Group" ("GroupID") MATCH FULL
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_NotificationDeviceGroup_HarmanID" FOREIGN KEY ("HarmanID")
        REFERENCES "Device" ("HarmanID") MATCH FULL
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_NotificationDeviceGroup_NotificationID" FOREIGN KEY ("NotificationID")
        REFERENCES "Notification" ("NotificationID") MATCH FULL
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "FK_NotificationDeviceGroup_UpdatedBy" FOREIGN KEY ("UpdatedBy")
        REFERENCES "User" ("UserID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "UK_NotificationDeviceGroup_NotificationID_DeviceID_GroupID" UNIQUE ("NotificationID", "GroupID", "HarmanID")
);

-- Create scripts for Grouping - END

-- Sequence for TempDeviceGroup
CREATE SEQUENCE IF NOT EXISTS tempdevicegroup_id
    INCREMENT 1
  MINVALUE 1
  MAXVALUE 4294967295
  START 75
  CACHE 1;

-- TempDeviceGroup table temporarily stores harman ids during vin list upload
CREATE TABLE IF NOT EXISTS "TempDeviceGroup"
(
    "GroupID" bigserial NOT NULL,
    "HarmanID" character varying,
    "VIN" character varying,
    "CreatedAt" timestamp with time zone,
    "CreatedBy" bigint,
    "IsActive" boolean,
    "IsMatching" integer DEFAULT 0,
    CONSTRAINT fk_group_createdby FOREIGN KEY ("CreatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS "OEM"
(
    "ID" bigserial NOT NULL,
    "Name" character varying NOT NULL,
    "Description" character varying,
    "CreatedBy" bigint,
    "CreatedAt" timestamp without time zone,
    "UpdatedBy" bigint,
    "UpdatedAt" timestamp without time zone,
    CONSTRAINT "pk_OEM_ID" PRIMARY KEY ("ID"),
    CONSTRAINT "FK_OEM_User_CreatedBy_ID" FOREIGN KEY ("CreatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "fk_OEM_User_UpdatedBy-ID" FOREIGN KEY ("UpdatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "unique_OEM_Name" UNIQUE ("Name")
);

-- Function to get OEM ID of device
CREATE OR REPLACE FUNCTION getoemidofdevice(manufacturer character varying, hwserialnumber character varying)
  RETURNS bigint AS
$BODY$
DECLARE
hwSerialNumberPrefix VARCHAR(5);
	oemId bigint;
BEGIN
	oemId := -1;
select into oemId "ID" from "OEM" where "Name"=manufacturer;
IF oemId != -1 THEN
		RETURN oemId;
END IF;
	hwSerialNumberPrefix := substring(hwSerialNumber from 1 for 3);

	IF hwSerialNumberPrefix ='VP4' OR hwSerialNumberPrefix = 'VP5' THEN
select "ID" into oemId from "OEM" where "Name"='Chrysler';
ELSIF hwSerialNumberPrefix ='TEB' OR hwSerialNumberPrefix = 'TEM' THEN
select "ID" into oemId from "OEM" where "Name"='Toyota';
END IF;
	IF oemId is null THEN
select into oemId "ID" from "OEM" where "Name"='UNKNOWN';
END IF;
RETURN oemId;
END;
$BODY$
LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION getoemidofdevice(character varying, character varying)
    OWNER TO postgresql;


--  UserOEM table stores mapping between users and OEMs to separate OEM data for appropriately authorized users
CREATE TABLE IF NOT EXISTS "UserOEM"
(
    "ID" bigserial NOT NULL,
    "OEMID" bigint NOT NULL,
    "UserID" bigint NOT NULL,
    "CreatedBy" bigint NOT NULL,
    "CreatedAt" timestamp without time zone NOT NULL,
    CONSTRAINT "pk_UserOEM_ID" PRIMARY KEY ("ID"),
    CONSTRAINT "fk_UserOEM_CreatedBy" FOREIGN KEY ("CreatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "fk_UserOEM_UserID" FOREIGN KEY ("UserID")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "fk_UserOEM_OEMID" FOREIGN KEY ("OEMID")
        REFERENCES "OEM" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "unique_UserID_OemID" UNIQUE ("OEMID", "UserID")
);

CREATE TABLE IF NOT EXISTS "OEMHierarchy"
(
    "ID" bigserial NOT NULL,
    "CHILD_OEM_ID" bigint NOT NULL,
    "PARENT_OEM_ID" bigint NOT NULL,
    "CreatedBy" bigint NOT NULL,
    "CreatedAt" timestamp without time zone,
    CONSTRAINT "pk_OEMHierarchy_ID" PRIMARY KEY ("ID"),
    CONSTRAINT "fk_OEMHierarchy_ChildOemId" FOREIGN KEY ("CHILD_OEM_ID")
        REFERENCES "OEM" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "fk_OEMHierarchy_CreatedBy" FOREIGN KEY ("CreatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "fk_OEMHierarchy_ParentOemId" FOREIGN KEY ("PARENT_OEM_ID")
        REFERENCES "OEM" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS "OEMEmailDomain"
(
    "OEMID" bigint NOT NULL,
    "EmailDomain" character varying NOT NULL,
    CONSTRAINT "pk_OEMEmailDomain_oemIdEmailDomain" PRIMARY KEY ("OEMID", "EmailDomain"),
    CONSTRAINT "fk_OEMEmailDomain_OEMID_GroupID" FOREIGN KEY ("OEMID")
        REFERENCES "OEM"("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS "OEMAPP"
(
    "ID" bigserial NOT NULL,
    "OEMID" bigint NOT NULL,
    "APPID" bigint NOT NULL,
    "CreatedBy" bigint,
    "CreatedAt" timestamp without time zone,
    CONSTRAINT "pk_OEMAPP_ID" PRIMARY KEY ("ID"),
    CONSTRAINT "fk_OEMAPP_APPID" FOREIGN KEY ("APPID")
        REFERENCES "APP" ("APPID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "fk_OEMAPP_CreatedBy" FOREIGN KEY ("CreatedBy")
        REFERENCES "User" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT "fk_OEMAPP_OEMID" FOREIGN KEY ("OEMID")
        REFERENCES "OEM" ("ID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS "UserApprovalHistory"
(
    "ID" bigserial NOT NULL,
    "RequestID" bigint NOT NULL,
    "UserID" bigint NOT NULL,
    "RoleID" bigint NOT NULL,
    "Status" character varying NOT NULL,
    "Justification" character varying,
    "ApproverID" bigint NOT NULL,
    "ApproverName" character varying,
    "RequestedOn" timestamp with time zone,
    "IsLatest" smallint NOT NULL DEFAULT 0,
    CONSTRAINT "pk_User_Approval_Log_ID" PRIMARY KEY ("ID")
);


CREATE OR REPLACE FUNCTION get_device_list(whereList text)
  RETURNS text[] AS
$BODY$
DECLARE
harmanIds text [];
	model text;
year text;
	query text;
	harmanIdQuery text;
	harmanId text;

BEGIN

	harmanIdQuery := 'select ARRAY(select distinct  d."HarmanID"||''-separator-''||h."VIN"  from "DeviceInfo" d,"HCPInfo" h where
		h."HarmanID"=d."HarmanID" and
		d."Name" in (''Model'',''Year'') and
		d."HarmanID" IN ';

	harmanIdQuery :=  harmanIdQuery|| whereList||')';
EXECUTE  harmanIdQuery into harmanIds;

FOR i IN array_lower(harmanIds, 1)..array_upper(harmanIds, 1) LOOP
		harmanId := split_part(harmanIds[i],'-separator-',1);
select "Value" into model from "DeviceInfo" where "Name"='Model' and "HarmanID"=harmanId;
select "Value" into year from "DeviceInfo" where "Name"='Year' and "HarmanID"=harmanId;
harmanIds[i] := harmanIds[i] || '-separator-'||model||'-separator-'||year;
		RAISE NOTICE '---------------------';
		RAISE NOTICE '%',harmanIds[i];
END LOOP;
RETURN harmanIds;
END;
$BODY$
LANGUAGE plpgsql VOLATILE
  COST 100;




-- Tableau User ID table
CREATE TABLE IF NOT EXISTS tableau_users
(
    id bigserial NOT NULL,
    tableau_user_name character varying,
    created_by character varying,
    CONSTRAINT pk_tableau_users_id PRIMARY KEY (id),
    CONSTRAINT unique_tableauusername UNIQUE (tableau_user_name)
);
-- Tableau User-Aha User mapping table


CREATE TABLE IF NOT EXISTS aha_tableau_users
(
    aha_user_name character varying,
    tableau_user_id bigint,
    CONSTRAINT fk_aha_tableau_users_tableau_users_id FOREIGN KEY (tableau_user_id)
        REFERENCES tableau_users (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_aha_tableau_users_user FOREIGN KEY (aha_user_name)
        REFERENCES "User" ("UserID") MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT unique_ahausername_tableauuserid UNIQUE (aha_user_name, tableau_user_id)
);



CREATE TABLE IF NOT EXISTS user_approval_queue
(
    user_id character varying,
    first_name character varying,
    last_name character varying,
    approve_url character varying,
    admin_info character varying,
    apps_requested character varying,
    created_at timestamp with time zone
);


CREATE TABLE IF NOT EXISTS group_permission( group_id bigint,
                               user_id bigint,
                               permission_read boolean,
                               permission_write boolean,
                               created_at timestamp with time zone,
                               updated_at timestamp with time zone,

                               CONSTRAINT comp_pk_groupid_userid_permtype PRIMARY KEY (group_id,user_id),
                               CONSTRAINT fk_user_id FOREIGN KEY(user_id) REFERENCES "User"("ID"),
                               CONSTRAINT fk_group_id FOREIGN KEY(group_id) REFERENCES "Group"("GroupID")
);

CREATE TABLE IF NOT EXISTS device_activation_state(
                                        id bigserial primary key,
                                        serial_number character varying not null,
                                        activation_initiated_on timestamp with time zone not null,
                                        activation_initiated_by character varying not null,
                                        deactivation_initiated_on timestamp with time zone,
                                        deactivation_initiated_by character varying,
                                        activation_ready boolean default false,
                                        factory_data bigint,
                                        CONSTRAINT fk_factoryID FOREIGN KEY (factory_data) REFERENCES "DeviceInfoFactoryData" ("ID") MATCH SIMPLE
                                            ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS "device_activation"
(
	"id" bigserial NOT NULL ,
	"jitact_id" character varying UNIQUE NOT NULL,
	"harman_id" character varying UNIQUE,
	"passcode" character varying,
	"activation_date" timestamp with time zone,
	"device_type" character varying,
	"is_active" boolean,
	CONSTRAINT "PK_device_activation" PRIMARY KEY ("id")
);

CREATE OR REPLACE FUNCTION get_devices_in_group(groupId bigint)
  RETURNS text[] AS
$BODY$
DECLARE
harmanIds text [];
	model text;
year text;
	harmanIdQuery text;
	harmanId text;

BEGIN

	harmanIdQuery := 'select ARRAY(select distinct  d."HarmanID"||''-separator-''||h."VIN"  from "DeviceInfo" d,"HCPInfo" h where
		h."HarmanID"=d."HarmanID" and
		d."Name" in (''Model'',''Year'') and
		d."HarmanID" IN (select "HarmanID" from "DeviceGroup" where "GroupID"=';

	harmanIdQuery :=  harmanIdQuery|| groupId||'))';
EXECUTE  harmanIdQuery into harmanIds;

FOR i IN array_lower(harmanIds, 1)..array_upper(harmanIds, 1) LOOP
		harmanId := split_part(harmanIds[i],'-separator-',1);
select "Value" into model from "DeviceInfo" where "Name"='Model' and "HarmanID"=harmanId;
select "Value" into year from "DeviceInfo" where "Name"='Year' and "HarmanID"=harmanId;
harmanIds[i] := harmanIds[i] || '-separator-'||model||'-separator-'||year;
		RAISE NOTICE '---------------------';
		RAISE NOTICE '%',harmanIds[i];
END LOOP;
RETURN harmanIds;
END;
$BODY$
LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION get_devices_in_group(bigint)
    OWNER TO postgresql;



CREATE TABLE IF NOT EXISTS pii_info
(
    id bigserial,
    harman_id character varying NOT NULL,
    pii_key character varying(128) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    CONSTRAINT pk_pii_keys_id PRIMARY KEY (id),
    CONSTRAINT unique_pii_keys_harman_id UNIQUE ("harman_id")
);

--- ######################################################################################################
-- Create Read-only User

DO
$do$
BEGIN
IF NOT EXISTS (
SELECT
FROM pg_catalog.pg_roles
WHERE rolname = 'readonly') THEN
CREATE ROLE readonly LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION PASSWORD 'readonly';
END IF;
END
$do$;

ALTER ROLE readonly set default_transaction_read_only = on;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO readonly;

-- To create Sample Users and Roles
insert into public."User"("UserID","Password","FirstName","LastName","CreatedBy","DateCreated","DateUpdated","IsValid","Email","UpdatedBy") SELECT 'SuperAdmin','password','Super','Admin',1,now(),now(),true,'coreplatform_admin@harman.com',1 WHERE NOT EXISTS (SELECT "UserID" FROM public."User" WHERE "UserID" = 'SuperAdmin');

insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 1,'ROLE_SUPER_ADMIN','Super Admin roles with highest privileges','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 1);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 2,'ROLE_ADMIN','Super Admin roles with admin privileges','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 2);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 3,'ROLE_USER','Super Admin roles with normal user privileges','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 3);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 4,'ROLE_CAMPAIGN_MGR','Campaign Manager privileges','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 4);
--insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt")  values (5,'ROLE_HCPAPP_INSIGHT','Insight Access privileges','SuperAdmin',now(),now());
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 6,'ROLE_USER_ISIGHT','Isight Basic Access privileges','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 6);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 7,'ROLE_USER_ISIGHT_LOCATION','Isight Basic plus Location Access privileges','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 7);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 8,'ROLE_ISIGHT_USER_REQUEST_FILES','Isight User Request Files','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 8);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 101,'ROLE_DEV','Harman Developer','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 101);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 9,'ROLE_SUBARU_NOTIFY','Role with Notification privileges for Subaru POC','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 9);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 10,'ROLE_USER_ANALYTICS','Role for using Tableau Analytics privileges','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 10);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 11,'ROLE_GROUP_MGMT','Role for using grouping privileges','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 11);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 12,'ROLE_TOYOTA_NOTIF','role for allowing user to send map update notifications','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 12);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 13,'ROLE_ETL_SYSTEM','Role for ETL system to access service for Device ID and HarmanID info details','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 13);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 14,'ROLE_PII_USER','Role for allowing users to access PII data','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 14);
insert into public."Role"("RoleID","RoleName","Desc","UpdaterID","CreatedAt","ModifiedAt") SELECT 15,'ROLE_DEVICE_STATE_CONTROLLER','Role for allowing users to controll the device state','SuperAdmin',now(),now() WHERE NOT EXISTS (SELECT "RoleID" FROM public."Role" WHERE "RoleID" = 15);

insert into "APP"("APPID","APPNAME") SELECT 1, 'Micro portal - Basic' WHERE NOT EXISTS (SELECT "APPID" FROM "APP" WHERE "APPID" = 1);
insert into "APP"("APPID","APPNAME") SELECT 2, 'Micro portal - Location' WHERE NOT EXISTS (SELECT "APPID" FROM "APP" WHERE "APPID" = 2);

insert into "APPROLE"("APPID","ROLEID") SELECT 1,6 WHERE NOT EXISTS (SELECT "APPID" FROM "APPROLE" WHERE "APPID" = 1);
insert into "APPROLE"("APPID","ROLEID") SELECT 2,7 WHERE NOT EXISTS (SELECT "APPID" FROM "APPROLE" WHERE "APPID" = 2);

insert into "ROLEADMIN" ("ADMINID", "ROLEID") SELECT 1,4 WHERE NOT EXISTS ( SELECT "ROLEID" FROM "ROLEADMIN" WHERE "ROLEID" = 4);
insert into "ROLEADMIN" ("ADMINID", "ROLEID") SELECT 1,6 WHERE NOT EXISTS ( SELECT "ROLEID" FROM "ROLEADMIN" WHERE "ROLEID" = 6);
insert into "ROLEADMIN" ("ADMINID", "ROLEID") SELECT 1,7 WHERE NOT EXISTS ( SELECT "ROLEID" FROM "ROLEADMIN" WHERE "ROLEID" = 7);
insert into "ROLEADMIN" ("ADMINID", "ROLEID") SELECT 1,8 WHERE NOT EXISTS ( SELECT "ROLEID" FROM "ROLEADMIN" WHERE "ROLEID" = 8);
insert into "ROLEADMIN" ("ADMINID", "ROLEID") SELECT 1,10 WHERE NOT EXISTS ( SELECT "ROLEID" FROM "ROLEADMIN" WHERE "ROLEID" = 10);

insert into "APP" ("APPID","APPNAME") SELECT 5,'Macro portal' WHERE NOT EXISTS ( SELECT "APPID" FROM "APP" WHERE "APPID" = 5);
insert into "APP" ("APPID","APPNAME") SELECT 6,'Micro portal - Request Logs' WHERE NOT EXISTS ( SELECT "APPID" FROM "APP" WHERE "APPID" = 6);

insert into "APPROLE"("APPID","ROLEID") SELECT 5,10 WHERE NOT EXISTS ( SELECT "APPID" FROM "APPROLE" WHERE "APPID" = 5);
insert into "APPROLE"("APPID","ROLEID") SELECT 6,8 WHERE NOT EXISTS ( SELECT "APPID" FROM "APPROLE" WHERE "APPID" = 6);

insert into "UserRole"("UserID","RoleID","Deleted") SELECT 1,1,false WHERE NOT EXISTS ( SELECT "RoleID" FROM "UserRole" WHERE "RoleID" = 1);
insert into "UserRole"("UserID","RoleID","Deleted") SELECT 1,2,false WHERE NOT EXISTS ( SELECT "RoleID" FROM "UserRole" WHERE "RoleID" = 2);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_deviceinfo_harmanId ON "DeviceInfo" ("HarmanID");
CREATE INDEX IF NOT EXISTS idx_deviceinfo_name ON "DeviceInfo" ("Name");


CREATE INDEX IF NOT EXISTS idx_devicenotification_harmanId ON "DeviceNotification" ("HarmanID");
CREATE INDEX IF NOT EXISTS idx_devicenotification_requestId ON "DeviceNotification" ("RequestID");
CREATE INDEX IF NOT EXISTS idx_devicenotification_currentStatus ON "DeviceNotification" ("CurrentStatus");

CREATE INDEX IF NOT EXISTS idx_devicegroup_harmanId ON "DeviceGroup" ("HarmanID");
CREATE INDEX IF NOT EXISTS idx_devicegroup_groupId ON "DeviceGroup" ("GroupID");

CREATE INDEX IF NOT EXISTS idx_deviceassociation_snumber_user_id  ON device_association (serial_number,user_id);
CREATE INDEX IF NOT EXISTS idx_deviceassociation_status_serialnumber ON device_association (serial_number,association_status);
CREATE INDEX IF NOT EXISTS idx_deviceassociation_userid_assoc_on  ON device_association (user_id,associated_on);
CREATE INDEX IF NOT EXISTS idx_deviceassociation_factory_data  ON device_association (factory_data);
CREATE INDEX IF NOT EXISTS idx_deviceassociation_harmanid  ON device_association (harman_id);


CREATE INDEX IF NOT EXISTS idx_device_activation_state_serialnumber ON device_activation_state (serial_number);
CREATE INDEX IF NOT EXISTS idx_device_activation_state_factory_data ON device_activation_state (factory_data);


CREATE INDEX IF NOT EXISTS idx_hcpinfo_serial_number ON "HCPInfo" ("SerialNumber");
CREATE INDEX IF NOT EXISTS idx_hcpinfo_vin ON "HCPInfo" ("VIN");
CREATE INDEX IF NOT EXISTS idx_hcpinfo_factory_data ON "HCPInfo" ("factory_data");


--post_schema
insert into "OEM"("ID","Name","Description", "CreatedBy", "CreatedAt", "UpdatedBy", "UpdatedAt") SELECT 1,'Harman','Harman',1,now(),null,null WHERE NOT EXISTS (SELECT "ID" FROM "OEM" WHERE "ID" = 1);
insert into "OEMEmailDomain"("OEMID", "EmailDomain") SELECT 1,'harman.com' WHERE NOT EXISTS (SELECT "EmailDomain" FROM "OEMEmailDomain" WHERE "EmailDomain" = 'harman.com');
insert into "OEMEmailDomain" SELECT 1,'symphonyteleca.com' WHERE NOT EXISTS (SELECT "EmailDomain" FROM "OEMEmailDomain" WHERE "EmailDomain" = 'symphonyteleca.com');
insert into "UserOEM"("ID","OEMID","UserID","CreatedBy","CreatedAt") SELECT 1,1,1,1,now() WHERE NOT EXISTS (SELECT "ID" FROM "UserOEM" WHERE "ID" = 1);
insert into "OEMAPP"("ID", "OEMID", "APPID", "CreatedBy", "CreatedAt") SELECT 1,1,1,1,now() WHERE NOT EXISTS (SELECT "ID" FROM "OEMAPP" WHERE "ID" = 1);
insert into "OEMAPP"("ID", "OEMID", "APPID", "CreatedBy", "CreatedAt") SELECT 2,1,2,1,now() WHERE NOT EXISTS (SELECT "ID" FROM "OEMAPP" WHERE "ID" = 2);
insert into "OEMAPP"("ID", "OEMID", "APPID", "CreatedBy", "CreatedAt") SELECT 4,1,5,1,now() WHERE NOT EXISTS (SELECT "ID" FROM "OEMAPP" WHERE "ID" = 4);
insert into "OEMAPP"("ID", "OEMID", "APPID", "CreatedBy", "CreatedAt") SELECT 5,1,6,1,now() WHERE NOT EXISTS (SELECT "ID" FROM "OEMAPP" WHERE "ID" = 5);

DO
$do$
BEGIN
IF NOT EXISTS (
SELECT
FROM pg_catalog.pg_roles
WHERE rolname = 'hcpdb_application_group') THEN
CREATE ROLE hcpdb_application_group NOLOGIN;
END IF;
END
$do$;

DO
$do$
BEGIN
IF NOT EXISTS (
SELECT
FROM pg_catalog.pg_roles
WHERE rolname = 'hcpdb_application_user') THEN
CREATE ROLE hcpdb_application_user LOGIN PASSWORD 'GIA!ss=Jp^4H';
END IF;
END
$do$;

GRANT hcpdb_application_group TO hcpdb_application_user;

REVOKE ALL ON DATABASE "ignite" FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE "ignite" TO hcpdb_application_group;

-- for tables
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hcpdb_application_group;
ALTER DEFAULT PRIVILEGES FOR ROLE postgresql IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO hcpdb_application_group;

-- for sequence
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM public;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO hcpdb_application_group;
ALTER DEFAULT PRIVILEGES FOR ROLE postgresql IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO hcpdb_application_group;

-- for functions
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM public;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO hcpdb_application_group;
ALTER DEFAULT PRIVILEGES FOR ROLE postgresql IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO hcpdb_application_group;

-- Add column for Device table
ALTER TABLE "Device" DROP COLUMN "registered_scope_id";
alter table "Device" add column "registered_scope_id" varchar null;

-- for Package Serial Number
ALTER TABLE "DeviceInfoFactoryData" DROP COLUMN "package_serial_number";
alter table "DeviceInfoFactoryData" add column "package_serial_number" varchar null;
ALTER TABLE "DeviceInfoFactoryDataHistory" DROP COLUMN "package_serial_number";
alter table "DeviceInfoFactoryDataHistory" add column "package_serial_number" varchar null;

--Add isstolen and isfaulty flag
ALTER TABLE "DeviceInfoFactoryData" DROP COLUMN "isstolen";
alter table "DeviceInfoFactoryData" add column "isstolen" boolean NOT NULL default FALSE;
ALTER TABLE "DeviceInfoFactoryData" DROP COLUMN "isfaulty";
alter table "DeviceInfoFactoryData" add column "isfaulty" boolean NOT NULL default FALSE;

--Alter table to make columns null
alter table "DeviceInfoFactoryData" alter imei drop not null, alter iccid drop not null, alter ssid drop not null, alter bssid drop not null, alter msisdn drop not null, alter imsi drop not null, alter platform_version drop not null;
alter table "DeviceInfoFactoryDataHistory" alter imei drop not null, alter iccid drop not null, alter ssid drop not null, alter bssid drop not null, alter msisdn drop not null, alter imsi drop not null, alter platform_version drop not null;

--Alter table to add new columns for supporting Device Type (From Factory Feed)
ALTER TABLE "DeviceInfoFactoryData" ADD COLUMN IF NOT EXISTS device_type character varying;
ALTER TABLE "DeviceInfoFactoryDataHistory" ADD COLUMN IF NOT EXISTS device_type character varying;

--Alter table to add columns related to M2M feature
ALTER TABLE device_association ADD COLUMN IF NOT EXISTS association_type character varying, ADD COLUMN IF NOT EXISTS start_timestamp timestamp with time zone,ADD COLUMN IF NOT EXISTS end_timestamp timestamp with time zone ;

--Insert statement for wipe data enhancement
INSERT INTO public."DeviceInfoFactoryData" ("manufacturing_date","model","imei","serial_number","platform_version","iccid","ssid","bssid","msisdn","imsi","record_date","factory_admin","created_date","state","package_serial_number") VALUES (now(),'!@#?<$%>^&*','!@#?<$%>^&*','!@#?<$%>^&*','!@#?<$%>^&*','!@#?<$%>^&*','!@#?<$%>^&*','!@#?<$%>^&*','!@#?<$%>^&*','!@#?<$%>^&*',now(),'HCP SCRIPTS',now(),'DUMMY','!@#?<$%>^&*') ON CONFLICT ON CONSTRAINT "DeviceInfoFactoryData_bssid_key" DO NOTHING;

--Alter table to add new columns for supporting Device region (From Factory Feed)
ALTER TABLE "DeviceInfoFactoryData" ADD COLUMN IF NOT EXISTS region character varying;

CREATE TABLE IF NOT EXISTS "vin_details" (
"id" bigserial NOT NULL,
"region" character varying UNIQUE,
"vin" character varying UNIQUE NOT NULL,
"reference_id" bigint NOT NULL,
CONSTRAINT fk_factoryID FOREIGN KEY ("reference_id") REFERENCES "DeviceInfoFactoryData" ("ID")
MATCH SIMPLE ON UPDATE NO ACTION ON DELETE CASCADE ,
CONSTRAINT "PK_vin_details" PRIMARY KEY ("id"),
CONSTRAINT "UK_vin_details" UNIQUE ("region","vin"));

ALTER TABLE "DeviceInfoFactoryData"
DROP CONSTRAINT "UK_DeviceInfoFactoryData";

ALTER TABLE "DeviceInfoFactoryData"
DROP CONSTRAINT "DeviceInfoFactoryData_bssid_key";

ALTER TABLE "DeviceInfoFactoryData"
DROP CONSTRAINT "DeviceInfoFactoryData_iccid_key";

ALTER TABLE "DeviceInfoFactoryData"
DROP CONSTRAINT "DeviceInfoFactoryData_imei_key";

ALTER TABLE "DeviceInfoFactoryData"
DROP CONSTRAINT "DeviceInfoFactoryData_imsi_key";

ALTER TABLE "DeviceInfoFactoryData"
DROP CONSTRAINT "DeviceInfoFactoryData_msisdn_key";

ALTER TABLE "DeviceInfoFactoryData"
DROP CONSTRAINT "DeviceInfoFactoryData_ssid_key";
