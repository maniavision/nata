-- Migration to add trips and parcels tables to nata schema
-- These are required for the stats and wallet features in AuthService

-- 1. Create nata.trips table
CREATE TABLE IF NOT EXISTS nata.trips (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    traveler_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    origin text NOT NULL,
    destination text NOT NULL,
    travel_date timestamp with time zone NOT NULL,
    status text DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_transit', 'completed', 'cancelled')),
    created_at timestamp with time zone DEFAULT now()
);

-- 2. Create nata.parcels table
CREATE TABLE IF NOT EXISTS nata.parcels (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    description text,
    weight_kg numeric(10, 2),
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'shipped', 'delivered', 'cancelled')),
    created_at timestamp with time zone DEFAULT now()
);

-- 3. Create nata.payments table (for Escrow stats)
CREATE TABLE IF NOT EXISTS nata.payments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount numeric(15, 2) NOT NULL,
    status text NOT NULL DEFAULT 'held' CHECK (status IN ('held', 'released', 'refunded')),
    created_at timestamp with time zone DEFAULT now()
);

-- 4. Create nata.payouts table (for Available balance stats)
CREATE TABLE IF NOT EXISTS nata.payouts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    traveler_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount numeric(15, 2) NOT NULL,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
    created_at timestamp with time zone DEFAULT now()
);

-- Enable RLS
ALTER TABLE nata.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE nata.parcels ENABLE ROW LEVEL SECURITY;
ALTER TABLE nata.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE nata.payouts ENABLE ROW LEVEL SECURITY;

-- Basic RLS Policies
CREATE POLICY "Users can view their own trips" ON nata.trips FOR SELECT USING (auth.uid() = traveler_id);
CREATE POLICY "Users can view their own parcels" ON nata.parcels FOR SELECT USING (auth.uid() = sender_id);
CREATE POLICY "Users can view their own payments" ON nata.payments FOR SELECT USING (auth.uid() = sender_id);
CREATE POLICY "Users can view their own payouts" ON nata.payouts FOR SELECT USING (auth.uid() = traveler_id);
