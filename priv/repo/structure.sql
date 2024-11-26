--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: livebeats_acts_fdw; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA livebeats_acts_fdw;


--
-- Name: postgres_fdw; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgres_fdw WITH SCHEMA public;


--
-- Name: EXTENSION postgres_fdw; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgres_fdw IS 'foreign-data wrapper for remote PostgreSQL servers';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: acts_server; Type: SERVER; Schema: -; Owner: -
--

CREATE SERVER acts_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (
    dbname 'acts_dev',
    host 'localhost',
    port '5432'
);


--
-- Name: USER MAPPING postgres SERVER acts_server; Type: USER MAPPING; Schema: -; Owner: -
--

CREATE USER MAPPING FOR postgres SERVER acts_server OPTIONS (
    password 'postgres',
    "user" 'postgres'
);


--
-- Name: users; Type: FOREIGN TABLE; Schema: livebeats_acts_fdw; Owner: -
--

CREATE FOREIGN TABLE livebeats_acts_fdw.users (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(255),
    last_name character varying(255),
    confirmed_at timestamp(0) without time zone,
    role character varying(255),
    settings jsonb,
    banned_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
)
SERVER acts_server
OPTIONS (
    schema_name 'public',
    table_name 'users'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN id OPTIONS (
    column_name 'id'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN email OPTIONS (
    column_name 'email'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN password_hash OPTIONS (
    column_name 'password_hash'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN first_name OPTIONS (
    column_name 'first_name'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN last_name OPTIONS (
    column_name 'last_name'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN confirmed_at OPTIONS (
    column_name 'confirmed_at'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN role OPTIONS (
    column_name 'role'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN settings OPTIONS (
    column_name 'settings'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN banned_at OPTIONS (
    column_name 'banned_at'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN inserted_at OPTIONS (
    column_name 'inserted_at'
);
ALTER FOREIGN TABLE livebeats_acts_fdw.users ALTER COLUMN updated_at OPTIONS (
    column_name 'updated_at'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: genres; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.genres (
    id uuid NOT NULL,
    title text NOT NULL,
    slug text NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: shops; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shops (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    owner_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: songs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.songs (
    id uuid NOT NULL,
    album_artist character varying(255),
    artist character varying(255) NOT NULL,
    duration integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    played_at timestamp(0) without time zone,
    paused_at timestamp(0) without time zone,
    title character varying(255) NOT NULL,
    attribution character varying(255),
    mp3_url character varying(255) NOT NULL,
    mp3_filename character varying(255) NOT NULL,
    mp3_filepath character varying(255) NOT NULL,
    date_recorded timestamp(0) without time zone,
    date_released timestamp(0) without time zone,
    user_id uuid,
    genre_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    server_ip character varying(255),
    mp3_filesize integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    transcript jsonb DEFAULT '{"segments": []}'::jsonb NOT NULL
);


--
-- Name: users; Type: FOREIGN TABLE; Schema: public; Owner: -
--

CREATE FOREIGN TABLE public.users (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(255),
    last_name character varying(255),
    confirmed_at timestamp(0) without time zone,
    role character varying(255),
    settings jsonb,
    banned_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
)
SERVER acts_server
OPTIONS (
    schema_name 'public',
    table_name 'users'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN id OPTIONS (
    column_name 'id'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN email OPTIONS (
    column_name 'email'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN password_hash OPTIONS (
    column_name 'password_hash'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN first_name OPTIONS (
    column_name 'first_name'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN last_name OPTIONS (
    column_name 'last_name'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN confirmed_at OPTIONS (
    column_name 'confirmed_at'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN role OPTIONS (
    column_name 'role'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN settings OPTIONS (
    column_name 'settings'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN banned_at OPTIONS (
    column_name 'banned_at'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN inserted_at OPTIONS (
    column_name 'inserted_at'
);
ALTER FOREIGN TABLE public.users ALTER COLUMN updated_at OPTIONS (
    column_name 'updated_at'
);


--
-- Name: genres genres_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genres
    ADD CONSTRAINT genres_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: shops shops_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shops
    ADD CONSTRAINT shops_pkey PRIMARY KEY (id);


--
-- Name: songs songs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.songs
    ADD CONSTRAINT songs_pkey PRIMARY KEY (id);


--
-- Name: genres_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX genres_slug_index ON public.genres USING btree (slug);


--
-- Name: genres_title_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX genres_title_index ON public.genres USING btree (title);


--
-- Name: shops_owner_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shops_owner_id_index ON public.shops USING btree (owner_id);


--
-- Name: songs_genre_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX songs_genre_id_index ON public.songs USING btree (genre_id);


--
-- Name: songs_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX songs_status_index ON public.songs USING btree (status);


--
-- Name: songs_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX songs_user_id_index ON public.songs USING btree (user_id);


--
-- Name: songs_user_id_title_artist_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX songs_user_id_title_artist_index ON public.songs USING btree (user_id, title, artist);


--
-- Name: songs songs_genre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.songs
    ADD CONSTRAINT songs_genre_id_fkey FOREIGN KEY (genre_id) REFERENCES public.genres(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20210908150612);
INSERT INTO public."schema_migrations" (version) VALUES (20211027201102);
INSERT INTO public."schema_migrations" (version) VALUES (20211117144505);
INSERT INTO public."schema_migrations" (version) VALUES (20220127172551);
INSERT INTO public."schema_migrations" (version) VALUES (20230126132130);
INSERT INTO public."schema_migrations" (version) VALUES (20230314150807);
INSERT INTO public."schema_migrations" (version) VALUES (20240100000001);
INSERT INTO public."schema_migrations" (version) VALUES (20240100000002);
INSERT INTO public."schema_migrations" (version) VALUES (20240124000002);
