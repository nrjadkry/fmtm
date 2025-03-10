--
-- PostgreSQL database dump
--

-- Dumped from database version 14.9
-- Dumped by pg_dump version 15.3 (Debian 15.3-0+deb12u1)

-- Started on 2023-10-05 12:55:27 UTC


-- Setup

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET TIME ZONE 'UTC';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER SCHEMA public OWNER TO fmtm;

-- PostGIS

CREATE SCHEMA IF NOT EXISTS tiger;
ALTER SCHEMA tiger OWNER TO fmtm;

CREATE SCHEMA IF NOT EXISTS tiger_data;
ALTER SCHEMA tiger_data OWNER TO fmtm;

CREATE SCHEMA IF NOT EXISTS topology;
ALTER SCHEMA topology OWNER TO fmtm;

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder WITH SCHEMA tiger;
CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;
-- Required for fmtm-splitter PostGIS StraightSkeleton usage
CREATE EXTENSION IF NOT EXISTS postgis_sfcgal WITH SCHEMA public;


-- Enums

CREATE TYPE public.backgroundtaskstatus AS ENUM (
    'PENDING',
    'FAILED',
    'RECEIVED',
    'SUCCESS'
);
ALTER TYPE public.backgroundtaskstatus OWNER TO fmtm;

CREATE TYPE public.mappinglevel AS ENUM (
    'BEGINNER',
    'INTERMEDIATE',
    'ADVANCED'
);
ALTER TYPE public.mappinglevel OWNER TO fmtm;

CREATE TYPE public.organisationtype AS ENUM (
    'FREE',
    'DISCOUNTED',
    'FULL_FEE'
);
ALTER TYPE public.organisationtype OWNER TO fmtm;

CREATE TYPE public.projectpriority AS ENUM (
    'MEDIUM',
    'LOW',
    'HIGH',
    'URGENT'
);
ALTER TYPE public.projectpriority OWNER TO fmtm;

CREATE TYPE public.projectstatus AS ENUM (
    'ARCHIVED',
    'PUBLISHED',
    'DRAFT'
);
ALTER TYPE public.projectstatus OWNER TO fmtm;

CREATE TYPE public.userrole AS ENUM (
    'READ_ONLY',
    'MAPPER',
    'ADMIN'
);
ALTER TYPE public.userrole OWNER TO fmtm;

CREATE TYPE public.projectrole AS ENUM (
    'MAPPER',
    'VALIDATOR',
    'FIELD_MANAGER',
    'ASSOCIATE_PROJECT_MANAGER',
    'PROJECT_MANAGER'
);
ALTER TYPE public.projectrole OWNER TO fmtm;

CREATE TYPE public.projectvisibility AS ENUM (
    'PUBLIC',
    'PRIVATE',
    'INVITE_ONLY'
);
ALTER TYPE public.projectvisibility OWNER TO fmtm;

CREATE TYPE public.tasksplittype AS ENUM (
    'DIVIDE_ON_SQUARE',
    'CHOOSE_AREA_AS_TASK',
    'TASK_SPLITTING_ALGORITHM'
);
ALTER TYPE public.tasksplittype OWNER TO fmtm;

CREATE TYPE public.communitytype AS ENUM (
    'OSM_COMMUNITY',
    'COMPANY',
    'NON_PROFIT',
    'UNIVERSITY',
    'OTHER'
);
ALTER TYPE public.communitytype OWNER TO fmtm;

CREATE TYPE public.taskevent AS ENUM (
    'MAP',
    'FINISH',
    'VALIDATE',
    'GOOD',
    'BAD',
    'CONFLATE',
    'SPLIT',
    'MERGE',
    'ASSIGN',
    'COMMENT',
    'RESET'
);
ALTER TYPE public.taskevent OWNER TO fmtm;

CREATE TYPE public.mappingstate AS ENUM (
    'UNLOCKED_TO_MAP',
    'LOCKED_FOR_MAPPING',
    'UNLOCKED_TO_VALIDATE',
    'LOCKED_FOR_VALIDATION',
    'UNLOCKED_DONE',
    'CONFLATED'
);
ALTER TYPE public.mappingstate OWNER TO fmtm;

CREATE TYPE public.entitystate AS ENUM (
    'READY',
    'OPENED_IN_ODK',
    'SURVEY_SUBMITTED',
    'NEW_GEOM',
    'VALIDATED',
    'MARKED_BAD'
);
ALTER TYPE public.entitystate OWNER TO fmtm;

CREATE TYPE public.geomstatus AS ENUM (
    'BAD',
    'NEW'
);
ALTER TYPE public.geomstatus OWNER TO fmtm;

CREATE TYPE public.geomtype AS ENUM (
    'POINT',
    'POLYLINE',
    'POLYGON'
);
ALTER TYPE public.geomtype OWNER TO fmtm;

-- Extra

SET default_tablespace = '';
SET default_table_access_method = heap;


-- Tables

CREATE TABLE public._migrations (
    script_name text,
    date_executed timestamp with time zone
);
ALTER TABLE public._migrations OWNER TO fmtm;


-- Note we use UUID for interoperability with external databases,
-- such as PGLite or other microservices
CREATE TABLE public.background_tasks (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    name character varying,
    project_id integer,
    status public.backgroundtaskstatus NOT NULL DEFAULT 'PENDING',
    message character varying
);
ALTER TABLE public.background_tasks OWNER TO fmtm;


-- Note we use UUID for interoperability with external databases,
-- such as PGLite or other microservices
CREATE TABLE public.basemaps (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    project_id integer,
    status public.backgroundtaskstatus NOT NULL,
    url character varying,
    tile_source character varying,
    background_task_id character varying,
    created_at timestamp with time zone DEFAULT now()
);
ALTER TABLE public.basemaps OWNER TO fmtm;


CREATE TABLE public.organisation_managers (
    organisation_id integer NOT NULL,
    user_id integer NOT NULL
);
ALTER TABLE public.organisation_managers OWNER TO fmtm;


CREATE TABLE public.organisations (
    id integer NOT NULL,
    name character varying(512) NOT NULL,
    slug character varying(255) NOT NULL,
    logo character varying,
    description character varying,
    url character varying,
    type public.organisationtype DEFAULT 'FREE',
    community_type public.communitytype DEFAULT 'OSM_COMMUNITY',
    created_by integer,
    associated_email character varying,
    approved BOOLEAN DEFAULT false,
    odk_central_url character varying,
    odk_central_user character varying,
    odk_central_password character varying,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.organisations OWNER TO fmtm;
CREATE SEQUENCE public.organisations_id_seq
AS integer
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;
ALTER TABLE public.organisations_id_seq OWNER TO fmtm;
ALTER SEQUENCE public.organisations_id_seq OWNED BY public.organisations.id;


CREATE TABLE public.projects (
    id integer NOT NULL,
    organisation_id integer,
    odkid integer,
    author_id integer,
    name character varying,
    short_description character varying,
    description character varying,
    per_task_instructions character varying,
    slug character varying,
    location_str character varying,
    outline public.GEOMETRY (POLYGON, 4326),
    status public.projectstatus NOT NULL DEFAULT 'DRAFT',
    total_tasks integer,
    osm_category character varying,
    xlsform_content bytea,
    odk_form_id character varying,
    visibility public.projectvisibility NOT NULL DEFAULT 'PUBLIC',
    mapper_level public.mappinglevel NOT NULL DEFAULT 'INTERMEDIATE',
    priority public.projectpriority DEFAULT 'MEDIUM',
    featured boolean DEFAULT false,
    due_date timestamp with time zone,
    changeset_comment character varying,
    odk_central_url character varying,
    odk_central_user character varying,
    odk_central_password character varying,
    odk_token character varying,
    data_extract_url character varying,
    task_split_type public.tasksplittype,
    task_split_dimension smallint,
    task_num_buildings smallint,
    hashtags character varying [],
    custom_tms_url character varying,
    geo_restrict_force_error boolean DEFAULT false,
    geo_restrict_distance_meters int2 DEFAULT 50 CHECK (
        geo_restrict_distance_meters >= 0
    ),
    primary_geom_type public.geomtype DEFAULT 'POLYGON',
    new_geom_type public.geomtype DEFAULT 'POLYGON',
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
ALTER TABLE public.projects OWNER TO fmtm;
CREATE SEQUENCE public.projects_id_seq
AS integer
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;
ALTER TABLE public.projects_id_seq OWNER TO fmtm;
ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


-- Note we use UUID for interoperability with external databases,
-- such as PGLite or other microservices
CREATE TABLE public.task_events (
    event_id UUID NOT NULL DEFAULT gen_random_uuid(),
    event public.taskevent NOT NULL,
    task_id integer NOT NULL,
    project_id integer,
    user_id integer,
    username character varying,
    state public.mappingstate,
    comment text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.task_events OWNER TO fmtm;


CREATE TABLE public.tasks (
    id integer NOT NULL,
    project_id integer NOT NULL,
    project_task_index integer,
    outline public.GEOMETRY (POLYGON, 4326),
    feature_count integer
);
ALTER TABLE public.tasks OWNER TO fmtm;
CREATE SEQUENCE public.tasks_id_seq
AS integer
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;
ALTER TABLE public.tasks_id_seq OWNER TO fmtm;
ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


CREATE TABLE public.user_roles (
    user_id integer NOT NULL,
    project_id integer NOT NULL,
    role public.projectrole NOT NULL DEFAULT 'MAPPER'
);
ALTER TABLE public.user_roles OWNER TO fmtm;


CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying,
    role public.userrole NOT NULL DEFAULT 'MAPPER',
    name character varying,
    city character varying,
    country character varying,
    profile_img character varying,
    email_address character varying,
    is_email_verified boolean DEFAULT false,
    is_expert boolean DEFAULT false,
    mapping_level public.mappinglevel NOT NULL DEFAULT 'BEGINNER',
    tasks_mapped integer NOT NULL DEFAULT 0,
    tasks_validated integer NOT NULL DEFAULT 0,
    tasks_invalidated integer NOT NULL DEFAULT 0,
    projects_mapped integer [],
    api_key character varying,
    registered_at timestamp with time zone DEFAULT now(),
    last_login_at timestamp with time zone DEFAULT now()
);
ALTER TABLE public.users OWNER TO fmtm;

CREATE TABLE public.odk_entities (
    entity_id UUID NOT NULL,
    status public.entitystate NOT NULL,
    project_id integer NOT NULL,
    task_id integer
);
ALTER TABLE public.odk_entities OWNER TO fmtm;

CREATE TABLE public.xlsforms (
    id integer NOT NULL,
    title character varying,
    xls bytea
);
ALTER TABLE public.xlsforms OWNER TO fmtm;
CREATE SEQUENCE public.xlsforms_id_seq
AS integer
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;
ALTER TABLE public.xlsforms_id_seq OWNER TO fmtm;
ALTER SEQUENCE public.xlsforms_id_seq OWNED BY public.xlsforms.id;

CREATE TABLE public.geometrylog (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    geojson JSONB NOT NULL,
    status public.geomstatus,
    project_id int,
    task_id int
);
ALTER TABLE public.geometrylog OWNER TO fmtm;

-- nextval for primary keys (autoincrement)

ALTER TABLE ONLY public.organisations ALTER COLUMN id SET DEFAULT nextval(
    'public.organisations_id_seq'::regclass
);
ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval(
    'public.projects_id_seq'::regclass
);
ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval(
    'public.tasks_id_seq'::regclass
);
ALTER TABLE ONLY public.xlsforms ALTER COLUMN id SET DEFAULT nextval(
    'public.xlsforms_id_seq'::regclass
);


-- Constraints for primary keys

ALTER TABLE public._migrations
ADD CONSTRAINT _migrations_pkey PRIMARY KEY (script_name);

ALTER TABLE ONLY public.background_tasks
ADD CONSTRAINT background_tasks_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.basemaps
ADD CONSTRAINT basemaps_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.organisation_managers
ADD CONSTRAINT organisation_user_key UNIQUE (organisation_id, user_id);

ALTER TABLE ONLY public.organisations
ADD CONSTRAINT organisations_name_key UNIQUE (name);

ALTER TABLE ONLY public.organisations
ADD CONSTRAINT organisations_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.organisations
ADD CONSTRAINT organisations_slug_key UNIQUE (slug);

ALTER TABLE ONLY public.projects
ADD CONSTRAINT projects_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.task_events
ADD CONSTRAINT task_events_pkey PRIMARY KEY (event_id);

ALTER TABLE ONLY public.tasks
ADD CONSTRAINT tasks_pkey PRIMARY KEY (id, project_id);

ALTER TABLE ONLY public.user_roles
ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, project_id);

ALTER TABLE ONLY public.users
ADD CONSTRAINT users_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.users
ADD CONSTRAINT users_username_key UNIQUE (username);

ALTER TABLE ONLY public.odk_entities
ADD CONSTRAINT odk_entities_pkey PRIMARY KEY (entity_id);

ALTER TABLE ONLY public.xlsforms
ADD CONSTRAINT xlsforms_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.xlsforms
ADD CONSTRAINT xlsforms_title_key UNIQUE (title);

ALTER TABLE ONLY public.geometrylog
ADD CONSTRAINT geometrylog_pkey PRIMARY KEY (id);

-- Indexing

CREATE INDEX idx_projects_outline ON public.projects USING gist (outline);
CREATE INDEX idx_projects_mapper_level
ON public.projects USING btree (
    mapper_level
);
CREATE INDEX idx_projects_organisation_id
ON public.projects USING btree (
    organisation_id
);
CREATE INDEX idx_tasks_outline ON public.tasks USING gist (outline);
CREATE INDEX idx_tasks_composite
ON public.tasks USING btree (
    id, project_id
);
CREATE INDEX idx_user_roles ON public.user_roles USING btree (
    project_id, user_id
);
CREATE INDEX idx_org_managers ON public.organisation_managers USING btree (
    user_id, organisation_id
);
CREATE INDEX idx_task_event_composite
ON public.task_events USING btree (
    task_id, project_id
);
CREATE INDEX idx_task_event_project_user
ON public.task_events USING btree (
    user_id, project_id
);
CREATE INDEX idx_task_event_project_id
ON public.task_events USING btree (
    task_id, project_id
);
CREATE INDEX idx_task_event_user_id
ON public.task_events USING btree (
    task_id, user_id
);
CREATE INDEX idx_entities_project_id
ON public.odk_entities USING btree (
    entity_id, project_id
);
CREATE INDEX idx_entities_task_id
ON public.odk_entities USING btree (
    entity_id, task_id
);
CREATE INDEX idx_geometrylog_geojson
ON public.geometrylog USING gin (geojson);


-- Foreign keys

ALTER TABLE ONLY public.projects
ADD CONSTRAINT fk_organisations FOREIGN KEY (
    organisation_id
) REFERENCES public.organisations (id);

ALTER TABLE ONLY public.projects
ADD CONSTRAINT fk_users FOREIGN KEY (author_id) REFERENCES public.users (id);

ALTER TABLE ONLY public.organisation_managers
ADD CONSTRAINT organisation_managers_organisation_id_fkey FOREIGN KEY (
    organisation_id
) REFERENCES public.organisations (id);

ALTER TABLE ONLY public.organisation_managers
ADD CONSTRAINT organisation_managers_user_id_fkey FOREIGN KEY (
    user_id
) REFERENCES public.users (id);

ALTER TABLE ONLY public.tasks
ADD CONSTRAINT tasks_project_id_fkey FOREIGN KEY (
    project_id
) REFERENCES public.projects (id);

ALTER TABLE ONLY public.task_events
ADD CONSTRAINT fk_projects FOREIGN KEY (
    project_id
) REFERENCES public.projects (id);

ALTER TABLE ONLY public.task_events
ADD CONSTRAINT fk_project_task_id FOREIGN KEY (
    task_id, project_id
) REFERENCES public.tasks (id, project_id);

ALTER TABLE ONLY public.task_events
ADD CONSTRAINT fk_users FOREIGN KEY (
    user_id
) REFERENCES public.users (id);

ALTER TABLE ONLY public.user_roles
ADD CONSTRAINT user_roles_project_id_fkey FOREIGN KEY (
    project_id
) REFERENCES public.projects (id);

ALTER TABLE ONLY public.user_roles
ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (
    user_id
) REFERENCES public.users (id);

-- Triggers

CREATE OR REPLACE FUNCTION public.set_task_state()
RETURNS TRIGGER AS $$
BEGIN
    CASE NEW.event
        WHEN 'MAP' THEN
            NEW.state := 'LOCKED_FOR_MAPPING';
        WHEN 'FINISH' THEN
            NEW.state := 'UNLOCKED_TO_VALIDATE';
        WHEN 'VALIDATE' THEN
            NEW.state := 'LOCKED_FOR_VALIDATION';
        WHEN 'GOOD' THEN
            NEW.state := 'UNLOCKED_DONE';
        WHEN 'BAD' THEN
            NEW.state := 'UNLOCKED_TO_MAP';
        WHEN 'SPLIT' THEN
            NEW.state := 'UNLOCKED_DONE';
        WHEN 'MERGE' THEN
            NEW.state := 'UNLOCKED_DONE';
        WHEN 'ASSIGN' THEN
            NEW.state := 'LOCKED_FOR_MAPPING';
        WHEN 'COMMENT' THEN
            NEW.state := OLD.state;
        WHEN 'RESET' THEN
            NEW.state := 'UNLOCKED_TO_MAP';
        ELSE
            RAISE EXCEPTION 'Unknown task event type: %', NEW.event;
    END CASE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER task_event_state_trigger
BEFORE INSERT ON public.task_events
FOR EACH ROW
EXECUTE FUNCTION public.set_task_state();

-- Finalise

REVOKE USAGE ON SCHEMA public FROM public;
GRANT ALL ON SCHEMA public TO public;
