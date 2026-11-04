-- ====================================================================
-- ADHD BUDGET PLANNER – SUPABASE DATABASE SCHEMA & ROW LEVEL SECURITY
-- ====================================================================

-- 1. Enable UUID extension
create extension if not exists "uuid-ossp";

-- 2. Profiles Table (extends Supabase auth.users)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  username text unique not null,
  email text not null,
  currency text default '$',
  onboarded boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Monthly Budgets Table
create table if not exists public.monthly_budgets (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  month_year text not null, -- e.g. "2025-01" or "January 2025"
  total_budget numeric(12, 2) not null check (total_budget >= 0),
  currency text default '$',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, month_year)
);

-- 4. Budget Categories Table (Customizable)
create table if not exists public.budget_categories (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  budget_id uuid references public.monthly_budgets on delete cascade,
  name text not null,
  icon text default 'tag',
  monthly_limit numeric(12, 2) not null default 0 check (monthly_limit >= 0),
  planned_amount numeric(12, 2) not null default 0 check (planned_amount >= 0),
  spent_amount numeric(12, 2) not null default 0 check (spent_amount >= 0),
  sort_order int default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  archived_at timestamp with time zone
);

-- 5. Task Categories Table (Dedicated to Calendar & Tasks)
create table if not exists public.task_categories (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  color text default 'sage', -- e.g. sage, blue, amber, purple, rose, teal, orange, gray
  icon text default 'check-square',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 6. Calendar Tasks Table
create table if not exists public.calendar_tasks (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  category_id uuid references public.task_categories on delete set null,
  category_name text default 'Personal',
  title text not null,
  description text,
  task_date date not null,
  start_time text,
  end_time text,
  reminder text,
  repeat_type text default 'none' check (repeat_type in ('none', 'daily', 'weekly', 'monthly')),
  completed boolean default false not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. Expenses Table
create table if not exists public.expenses (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  category_id uuid references public.budget_categories on delete set null,
  category_name text not null,
  bill_id uuid references public.bills on delete set null, -- Optional link to original paid bill
  expense_name text not null,
  amount numeric(12, 2) not null check (amount > 0),
  expense_date date default current_date not null,
  note text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Ensure a paid bill cannot create duplicate payment expense records
create unique index if not exists idx_unique_bill_payment on public.expenses (bill_id) where bill_id is not null;

-- 8. Bills Table
create table if not exists public.bills (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  bill_name text not null,
  name text, -- Backwards-compatible alias for bill_name
  amount numeric(12, 2) not null check (amount > 0),
  category_id uuid references public.budget_categories on delete set null,
  category_name text,
  due_date text not null, -- e.g. "January 24" or date string
  status text default 'pending' check (status in ('pending', 'paid')),
  is_paid boolean default false not null,
  paid_at timestamp with time zone,
  recurring_frequency text default 'none' check (recurring_frequency in ('none', 'weekly', 'monthly', 'yearly')),
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 9. User Settings Table
create table if not exists public.user_settings (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade unique not null,
  theme text default 'light' check (theme in ('light', 'dark')),
  enable_confetti boolean default true,
  autofocus_inputs boolean default true,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Users may only view, insert, update, and delete their own rows.
-- ====================================================================

alter table public.profiles enable row level security;
alter table public.monthly_budgets enable row level security;
alter table public.budget_categories enable row level security;
alter table public.task_categories enable row level security;
alter table public.calendar_tasks enable row level security;
alter table public.expenses enable row level security;
alter table public.bills enable row level security;
alter table public.user_settings enable row level security;

-- Profiles Policies
create policy "Users can view own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);
-- Allow public username/email lookup so users can sign in using their unique username
create policy "Allow username lookup for login" on public.profiles for select using (true);

-- Monthly Budgets Policies
create policy "Users can view own budgets" on public.monthly_budgets for select using (auth.uid() = user_id);
create policy "Users can insert own budgets" on public.monthly_budgets for insert with check (auth.uid() = user_id);
create policy "Users can update own budgets" on public.monthly_budgets for update using (auth.uid() = user_id);
create policy "Users can delete own budgets" on public.monthly_budgets for delete using (auth.uid() = user_id);

-- Budget Categories Policies
create policy "Users can view own budget categories" on public.budget_categories for select using (auth.uid() = user_id);
create policy "Users can insert own budget categories" on public.budget_categories for insert with check (auth.uid() = user_id);
create policy "Users can update own budget categories" on public.budget_categories for update using (auth.uid() = user_id);
create policy "Users can delete own budget categories" on public.budget_categories for delete using (auth.uid() = user_id);

-- Task Categories Policies
create policy "Users can view own task categories" on public.task_categories for select using (auth.uid() = user_id);
create policy "Users can insert own task categories" on public.task_categories for insert with check (auth.uid() = user_id);
create policy "Users can update own task categories" on public.task_categories for update using (auth.uid() = user_id);
create policy "Users can delete own task categories" on public.task_categories for delete using (auth.uid() = user_id);

-- Calendar Tasks Policies
create policy "Users can view own tasks" on public.calendar_tasks for select using (auth.uid() = user_id);
create policy "Users can insert own tasks" on public.calendar_tasks for insert with check (auth.uid() = user_id);
create policy "Users can update own tasks" on public.calendar_tasks for update using (auth.uid() = user_id);
create policy "Users can delete own tasks" on public.calendar_tasks for delete using (auth.uid() = user_id);

-- Expenses Policies
create policy "Users can view own expenses" on public.expenses for select using (auth.uid() = user_id);
create policy "Users can insert own expenses" on public.expenses for insert with check (auth.uid() = user_id);
create policy "Users can update own expenses" on public.expenses for update using (auth.uid() = user_id);
create policy "Users can delete own expenses" on public.expenses for delete using (auth.uid() = user_id);

-- Bills Policies
create policy "Users can view own bills" on public.bills for select using (auth.uid() = user_id);
create policy "Users can insert own bills" on public.bills for insert with check (auth.uid() = user_id);
create policy "Users can update own bills" on public.bills for update using (auth.uid() = user_id);
create policy "Users can delete own bills" on public.bills for delete using (auth.uid() = user_id);

-- User Settings Policies
create policy "Users can view own settings" on public.user_settings for select using (auth.uid() = user_id);
create policy "Users can insert own settings" on public.user_settings for insert with check (auth.uid() = user_id);
create policy "Users can update own settings" on public.user_settings for update using (auth.uid() = user_id);

-- ====================================================================
-- AUTO-TRIGGER FOR DEFAULT PROFILE & TASK CATEGORIES ON USER SIGNUP
-- ====================================================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  -- 1. Create Profile
  insert into public.profiles (id, full_name, username, email, currency, onboarded)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'Mindful Friend'),
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    new.email,
    '$',
    false
  );
  
  -- 2. Create User Settings
  insert into public.user_settings (user_id, theme, enable_confetti, autofocus_inputs)
  values (new.id, 'light', true, true);

  -- 3. Seed Default Task Categories for the user
  insert into public.task_categories (user_id, name, color, icon) values
    (new.id, 'Personal', 'purple', 'heart'),
    (new.id, 'Work', 'blue', 'briefcase'),
    (new.id, 'Shopping', 'amber', 'shopping-cart'),
    (new.id, 'Coffee', 'amber', 'coffee'),
    (new.id, 'Picnic', 'emerald', 'sun'),
    (new.id, 'Family', 'rose', 'users'),
    (new.id, 'Health', 'teal', 'activity'),
    (new.id, 'Other', 'gray', 'check-circle');

  return new;
end;
$$ language plpgsql security definer;

-- Trigger execution
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ====================================================================
-- HELPER FUNCTIONS FOR USERNAME AUTHENTICATION & LOOKUPS
-- ====================================================================

-- 1. Helper to retrieve email given a username (used for username + password sign in)
create or replace function public.get_email_for_username(p_username text)
returns text as $$
  select email from public.profiles where lower(username) = lower(trim(p_username)) limit 1;
$$ language sql security definer;

-- 2. Helper to check if a username is available during registration
create or replace function public.is_username_available(p_username text)
returns boolean as $$
  select not exists (select 1 from public.profiles where lower(username) = lower(trim(p_username)));
$$ language sql security definer;
