SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."audit_log_entries" ("instance_id", "id", "payload", "created_at", "ip_address") VALUES
	('00000000-0000-0000-0000-000000000000', '92685a04-52b6-4fde-872c-8d5ea679fe24', '{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"bob@emailinator.app","user_id":"45e8f282-48a6-4b0b-beb7-f26617780b82","user_phone":""}}', '2025-09-06 22:59:00.476298+00', ''),
	('00000000-0000-0000-0000-000000000000', '668637ec-7e9a-4fb8-8d86-a01fee801414', '{"action":"login","actor_id":"be3cadf5-f4c3-4392-82d4-9af2c99217f8","actor_username":"alice@emailinator.app","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-09-06 23:01:44.17504+00', '');


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."users" ("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous") VALUES
	('00000000-0000-0000-0000-000000000000', 'be3cadf5-f4c3-4392-82d4-9af2c99217f8', 'authenticated', 'authenticated', 'alice@emailinator.app', '$2a$10$1C3dsRrPFrrPZF/iN82u2.a8F/T0Bd.wvulxsk.6vsC3fNncjPDp2', '2025-09-06 03:13:41.024141+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-09-06 23:01:44.178865+00', '{"provider": "email", "providers": ["email"]}', '{"email_verified": true}', NULL, '2025-09-06 03:13:41.024141+00', '2025-09-06 23:01:44.207318+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."identities" ("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id") VALUES
	('be3cadf5-f4c3-4392-82d4-9af2c99217f8', 'be3cadf5-f4c3-4392-82d4-9af2c99217f8', '{"sub": "be3cadf5-f4c3-4392-82d4-9af2c99217f8", "email": "alice@emailinator.app", "email_verified": false, "phone_verified": false}', 'email', '2025-09-06 03:13:41.024141+00', '2025-09-06 03:13:41.024141+00', '2025-09-06 03:13:41.024141+00', '1a9549e1-6dd7-4cf8-bf1a-4f6ffba7d42a');


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag") VALUES
	('2b73277c-2032-4245-84ba-0223ae6b4f34', 'be3cadf5-f4c3-4392-82d4-9af2c99217f8', '2025-09-06 23:01:44.180028+00', '2025-09-06 23:01:44.180028+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36', '142.250.191.42', NULL);


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") VALUES
	('2b73277c-2032-4245-84ba-0223ae6b4f34', '2025-09-06 23:01:44.211967+00', '2025-09-06 23:01:44.211967+00', 'password', 'ef98d4c2-f4ba-4a2d-81af-83091509cef2');


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."refresh_tokens" ("instance_id", "id", "token", "user_id", "revoked", "created_at", "updated_at", "parent", "session_id") VALUES
	('00000000-0000-0000-0000-000000000000', 1, 'rfeqdb6prrbz', 'be3cadf5-f4c3-4392-82d4-9af2c99217f8', false, '2025-09-06 23:01:44.188194+00', '2025-09-06 23:01:44.188194+00', NULL, '2b73277c-2032-4245-84ba-0223ae6b4f34');


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: ai_prompt_config; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."ai_prompt_config" ("id", "is_active", "model", "prompt", "temperature", "top_p", "seed", "input_cost_nano_per_token", "output_cost_nano_per_token", "cost_currency", "created_at") VALUES
	('6105a9ba-4a5d-43eb-a32b-695648cfb7e5', true, 'gpt-4.1-mini', 'You are a careful assistant for a busy parent.
You are given an existing list of tasks and a new email.
Extract ONLY NEW tasks from the email that are NOT duplicates of the existing tasks.
Do not include any existing tasks in your response - only return genuinely new actionable items.
Only include actionable items (forms, payments, events, purchases, transport, volunteering).
If an event requires attire, do not create a separate task for clothing; note attire inside `description`.
Return only valid JSON that conforms to the provided JSON Schema. No prose.', NULL, NULL, NULL, 400, 1600, 'USD', '2025-09-06 03:20:05.136323+00');


--
-- Data for Name: ai_invocations; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: email_aliases; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."email_aliases" ("id", "user_id", "alias", "active", "created_at") VALUES
	('fb35c3bb-5f6d-482c-909c-f030f6a2dd57', 'be3cadf5-f4c3-4392-82d4-9af2c99217f8', 'test@in.emailinator.app', true, '2025-09-06 04:48:55.446115+00');


--
-- Data for Name: forwarding_verifications; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: preferences; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."preferences" ("user_id", "parent_requirement_levels", "overdue_grace_days", "resolved_show_completed", "resolved_days", "resolved_show_dismissed", "upcoming_days") VALUES
	('be3cadf5-f4c3-4392-82d4-9af2c99217f8', '{}', 14, true, 60, false, 30);


--
-- Data for Name: processing_budgets; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."processing_budgets" ("user_id", "remaining_nano_usd", "inserted_at", "updated_at") VALUES
	('be3cadf5-f4c3-4392-82d4-9af2c99217f8', 100000000, '2025-09-06 03:13:41.024141+00', '2025-09-09 05:41:52.419603+00');


--
-- Data for Name: raw_emails; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: user_task_states; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: iceberg_namespaces; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: iceberg_tables; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: prefixes; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: hooks; Type: TABLE DATA; Schema: supabase_functions; Owner: supabase_functions_admin
--



--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: supabase_auth_admin
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 1, true);


--
-- Name: forwarding_verifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."forwarding_verifications_id_seq"', 1, false);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: supabase_functions_admin
--

SELECT pg_catalog.setval('"supabase_functions"."hooks_id_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

RESET ALL;
-- moved to test_integration directory
