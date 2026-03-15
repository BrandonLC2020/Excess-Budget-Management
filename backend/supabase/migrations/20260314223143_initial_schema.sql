-- Enable the UUID extension to generate unique IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. ACCOUNTS TABLE
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    name TEXT NOT NULL,
    current_balance NUMERIC(12, 2) DEFAULT 0.00 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS and create policy for Accounts
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own accounts" 
ON accounts FOR ALL 
USING (auth.uid() = user_id);

-- 2. CATEGORIES TABLE
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    name TEXT NOT NULL,
    monthly_limit NUMERIC(12, 2) DEFAULT 0.00 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS and create policy for Categories
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own categories" 
ON categories FOR ALL 
USING (auth.uid() = user_id);

-- 3. GOALS TABLE
CREATE TABLE goals (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    name TEXT NOT NULL,
    target_amount NUMERIC(12, 2) NOT NULL,
    current_amount NUMERIC(12, 2) DEFAULT 0.00 NOT NULL,
    deadline_date DATE,
    type TEXT CHECK (type IN ('short_term', 'long_term')) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS and create policy for Goals
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own goals" 
ON goals FOR ALL 
USING (auth.uid() = user_id);

-- 4. TRANSACTIONS TABLE
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    account_id UUID REFERENCES accounts(id) NOT NULL,
    category_id UUID REFERENCES categories(id), -- Nullable because income might not have a budget category
    amount NUMERIC(12, 2) NOT NULL,
    type TEXT CHECK (type IN ('income', 'expense')) NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS and create policy for Transactions
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own transactions" 
ON transactions FOR ALL 
USING (auth.uid() = user_id);