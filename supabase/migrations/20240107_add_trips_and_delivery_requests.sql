-- Migration to add trips and delivery_requests tables to nata schema
-- These match the official schema provided by the user.

-- 1. Create nata.trips table
CREATE TABLE IF NOT EXISTS nata.trips (
  id uuid not null default gen_random_uuid (),
  traveler_id uuid not null,
  departure_city_id integer not null,
  departure_date date not null,
  arrival_city_id integer not null,
  arrival_date date not null,
  price numeric(10, 2) not null,
  currency character(3) not null default 'USD'::bpchar,
  max_weight_kg numeric(6, 2) null,
  max_size text null,
  ticket_receipt_path text not null,
  status text not null default 'pending_review'::text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint trips_pkey primary key (id),
  constraint trips_arrival_city_id_fkey foreign KEY (arrival_city_id) references nata.cities (id),
  constraint trips_departure_city_id_fkey foreign KEY (departure_city_id) references nata.cities (id),
  constraint trips_traveler_id_fkey foreign KEY (traveler_id) references nata.profiles (id) on delete CASCADE,
  constraint trips_max_weight_kg_check check ((max_weight_kg > (0)::numeric)),
  constraint trips_check check ((arrival_date >= departure_date)),
  constraint trips_price_check check ((price >= (0)::numeric)),
  constraint trips_check1 check ((departure_city_id <> arrival_city_id)),
  constraint trips_status_check check (
    (
      status = any (
        array[
          'pending_review'::text,
          'live'::text,
          'completed'::text,
          'cancelled'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS trips_traveler_idx on nata.trips using btree (traveler_id);
CREATE INDEX IF NOT EXISTS trips_search_idx on nata.trips using btree (departure_city_id, arrival_city_id, arrival_date, status);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION nata.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON nata.trips;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON nata.trips FOR EACH ROW EXECUTE FUNCTION nata.set_updated_at();

-- 2. Create nata.delivery_requests table
CREATE TABLE IF NOT EXISTS nata.delivery_requests (
  id uuid not null default gen_random_uuid (),
  trip_id uuid not null,
  sender_id uuid not null,
  item_description text not null,
  item_weight_kg numeric(6, 2) null,
  item_size text null,
  recipient_name text not null,
  recipient_phone text not null,
  delivery_code_hash text null,
  status text not null default 'pending'::text,
  responded_at timestamp with time zone null,
  delivered_at timestamp with time zone null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint delivery_requests_pkey primary key (id),
  constraint delivery_requests_sender_id_fkey foreign KEY (sender_id) references nata.profiles (id) on delete CASCADE,
  constraint delivery_requests_trip_id_fkey foreign KEY (trip_id) references nata.trips (id) on delete CASCADE,
  constraint delivery_requests_item_weight_kg_check check ((item_weight_kg > (0)::numeric)),
  constraint delivery_requests_status_check check (
    (
      status = any (
        array[
          'pending'::text,
          'accepted'::text,
          'declined'::text,
          'expired'::text,
          'paid'::text,
          'handed_off'::text,
          'delivered'::text,
          'cancelled'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS delivery_requests_trip_idx on nata.delivery_requests using btree (trip_id);
CREATE INDEX IF NOT EXISTS delivery_requests_sender_idx on nata.delivery_requests using btree (sender_id);

DROP TRIGGER IF EXISTS set_updated_at ON nata.delivery_requests;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON nata.delivery_requests FOR EACH ROW EXECUTE FUNCTION nata.set_updated_at();

-- 3. Create nata.payments table (for Escrow stats in AuthService)
CREATE TABLE IF NOT EXISTS nata.payments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id uuid NOT NULL REFERENCES nata.profiles(id) ON DELETE CASCADE,
    amount numeric(15, 2) NOT NULL,
    status text NOT NULL DEFAULT 'held' CHECK (status IN ('held', 'released', 'refunded')),
    created_at timestamp with time zone DEFAULT now()
);

-- 4. Create nata.payouts table (for Available balance stats in AuthService)
CREATE TABLE IF NOT EXISTS nata.payouts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    traveler_id uuid NOT NULL REFERENCES nata.profiles(id) ON DELETE CASCADE,
    amount numeric(15, 2) NOT NULL,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
    created_at timestamp with time zone DEFAULT now()
);

-- Enable RLS
ALTER TABLE nata.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE nata.delivery_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE nata.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE nata.payouts ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own trips" ON nata.trips FOR SELECT USING (auth.uid() = traveler_id);
CREATE POLICY "Users can view their own delivery requests" ON nata.delivery_requests FOR SELECT USING (auth.uid() = sender_id);
CREATE POLICY "Users can view their own payments" ON nata.payments FOR SELECT USING (auth.uid() = sender_id);
CREATE POLICY "Users can view their own payouts" ON nata.payouts FOR SELECT USING (auth.uid() = traveler_id);
