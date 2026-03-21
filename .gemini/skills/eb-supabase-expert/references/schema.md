# Supabase Database Schema

## Tables Overview

### 1. `public.profiles` (Extends `auth.users`)
- `id`: `uuid` (references `auth.users.id`).
- `email`: `text`.
- `created_at`: `timestamp with time zone`.
- **RLS Policy**: `auth.uid() = id` (can only view/update own profile).

### 2. `public.accounts`
- `id`: `uuid` (primary key).
- `user_id`: `uuid` (references `public.profiles.id`).
- `name`: `text`.
- `balance`: `numeric(12, 2)`.
- `created_at`: `timestamp with time zone`.
- **RLS Policy**: `auth.uid() = user_id` (can only view/update/insert/delete own accounts).

## RLS Best Practices
- **Policies**: Use `FOR SELECT`, `FOR INSERT`, `FOR UPDATE`, `FOR DELETE`.
- **Check Condition**: Use `WITH CHECK ( auth.uid() = user_id )` for insertions.
- **Using auth.uid()**: Always filter by `user_id` to prevent data leakage.
- **Security Definer Functions**: Use `security definer` for functions that need to bypass RLS but should be executed with caution.

## Database Migrations
- Migration files are located in `backend/supabase/migrations/`.
- Use `supabase db reset` to apply all migrations and seed data locally.
