---
name: eb-supabase-expert
description: Expert in Supabase backend development for the Excess-Budget-Management project. Use when working on database migrations, PostgreSQL, Row Level Security (RLS), and Deno Edge Functions.
---

# EB Supabase Expert

This skill provides specialized guidance for developing the Supabase backend of the Excess-Budget-Management application.

## Core Backend Components

The project uses Supabase for database, authentication, and serverless functions.

- `backend/supabase/migrations/`: SQL files for initializing and updating the schema.
- `backend/supabase/functions/`: Deno Edge Functions (e.g., `generate-suggestions`).
- `backend/supabase/config.toml`: Supabase configuration.

## Technical Stack

- **Database**: PostgreSQL with PostgREST.
- **Authentication**: Supabase Auth (Email/Password).
- **Edge Functions**: Deno (v2) for business logic.
- **RLS**: Row Level Security is enforced on all tables.

## Workflows

### 1. Modifying the Database Schema
1. Create a new migration file in `backend/supabase/migrations/` (format: `YYYYMMDDHHMMSS_name.sql`).
2. Add the SQL commands to modify tables, indices, or RLS policies.
3. Test the migration locally by running `supabase db reset`.

### 2. Developing Edge Functions
1. Use the `supabase functions new <name>` command if adding a new function.
2. Develop logic in `backend/supabase/functions/<name>/index.ts` using Deno.
3. Handle CORS and authentication (e.g., verifying user JWT if needed).
4. Serve locally with `supabase functions serve <name>`.

### 3. Managing RLS Policies
Always ensure that data is protected by RLS. Use `auth.uid()` to identify the logged-in user in policies.

## Reference Materials

- [Schema](references/schema.md): Overview of the database tables and RLS.
- [Functions](references/functions.md): Guide for developing and deploying Edge Functions.
