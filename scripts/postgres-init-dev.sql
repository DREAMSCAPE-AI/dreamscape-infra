-- DreamScape Big Pods Development - PostgreSQL Initialization Script
-- DR-328: Test data for local development environment
-- Database: dreamscape_dev

\c dreamscape_dev;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===============================================
-- Users & Authentication Schema
-- ===============================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    avatar_url TEXT,
    role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'moderator')),
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) UNIQUE NOT NULL,
    refresh_token VARCHAR(500),
    expires_at TIMESTAMP NOT NULL,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- Voyages Schema
-- ===============================================

CREATE TABLE IF NOT EXISTS destinations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    country VARCHAR(100) NOT NULL,
    city VARCHAR(100),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    description TEXT,
    timezone VARCHAR(100),
    iata_code VARCHAR(3),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS voyages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    destination_id UUID REFERENCES destinations(id),
    departure_date DATE,
    return_date DATE,
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'planned', 'booked', 'in_progress', 'completed', 'cancelled')),
    budget DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'EUR',
    traveler_count INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    voyage_id UUID REFERENCES voyages(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL CHECK (type IN ('flight', 'hotel', 'activity', 'transport')),
    provider VARCHAR(100),
    confirmation_code VARCHAR(100),
    details JSONB,
    cost DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'EUR',
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- AI & Panorama Schema
-- ===============================================

CREATE TABLE IF NOT EXISTS ai_generations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    voyage_id UUID REFERENCES voyages(id) ON DELETE SET NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('itinerary', 'recommendation', 'panorama', 'description')),
    prompt TEXT NOT NULL,
    result JSONB,
    model VARCHAR(100),
    tokens_used INTEGER,
    generation_time_ms INTEGER,
    status VARCHAR(50) DEFAULT 'processing' CHECK (status IN ('processing', 'completed', 'failed')),
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS panoramas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    destination_id UUID REFERENCES destinations(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    image_url TEXT NOT NULL,
    thumbnail_url TEXT,
    type VARCHAR(50) CHECK (type IN ('360_photo', 'ai_generated', 'composite')),
    metadata JSONB,
    view_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- Payments Schema
-- ===============================================

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    voyage_id UUID REFERENCES voyages(id) ON DELETE SET NULL,
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',
    payment_method VARCHAR(50) CHECK (payment_method IN ('card', 'paypal', 'stripe', 'bank_transfer')),
    provider_payment_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'refunded')),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- Indexes for Performance
-- ===============================================

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_voyages_user_id ON voyages(user_id);
CREATE INDEX IF NOT EXISTS idx_voyages_status ON voyages(status);
CREATE INDEX IF NOT EXISTS idx_bookings_voyage_id ON bookings(voyage_id);
CREATE INDEX IF NOT EXISTS idx_ai_generations_user_id ON ai_generations(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_generations_voyage_id ON ai_generations(voyage_id);
CREATE INDEX IF NOT EXISTS idx_panoramas_destination_id ON panoramas(destination_id);
CREATE INDEX IF NOT EXISTS idx_panoramas_user_id ON panoramas(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- ===============================================
-- Test Data - Development Only
-- ===============================================

-- Test Users (password: password123)
INSERT INTO users (id, email, password_hash, first_name, last_name, verified, role) VALUES
    ('11111111-1111-1111-1111-111111111111', 'dev@dreamscape.ai', crypt('password123', gen_salt('bf')), 'Dev', 'User', TRUE, 'admin'),
    ('22222222-2222-2222-2222-222222222222', 'john@example.com', crypt('password123', gen_salt('bf')), 'John', 'Doe', TRUE, 'user'),
    ('33333333-3333-3333-3333-333333333333', 'alice@example.com', crypt('password123', gen_salt('bf')), 'Alice', 'Smith', TRUE, 'user')
ON CONFLICT (email) DO NOTHING;

-- Test Destinations
INSERT INTO destinations (id, name, country, city, latitude, longitude, iata_code, description) VALUES
    ('d1111111-1111-1111-1111-111111111111', 'Paris, France', 'France', 'Paris', 48.8566, 2.3522, 'CDG', 'The City of Light - iconic landmarks and romantic atmosphere'),
    ('d2222222-2222-2222-2222-222222222222', 'Tokyo, Japan', 'Japan', 'Tokyo', 35.6762, 139.6503, 'NRT', 'Modern metropolis blending tradition and innovation'),
    ('d3333333-3333-3333-3333-333333333333', 'New York, USA', 'USA', 'New York', 40.7128, -74.0060, 'JFK', 'The Big Apple - vibrant culture and endless opportunities'),
    ('d4444444-4444-4444-4444-444444444444', 'Barcelona, Spain', 'Spain', 'Barcelona', 41.3851, 2.1734, 'BCN', 'Mediterranean charm with stunning architecture'),
    ('d5555555-5555-5555-5555-555555555555', 'Kyoto, Japan', 'Japan', 'Kyoto', 35.0116, 135.7681, 'KIX', 'Ancient temples and traditional Japanese culture')
ON CONFLICT (id) DO NOTHING;

-- Test Voyages
INSERT INTO voyages (id, user_id, title, description, destination_id, departure_date, return_date, status, budget, traveler_count) VALUES
    ('v1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'Paris Adventure', 'Romantic getaway to Paris', 'd1111111-1111-1111-1111-111111111111', '2025-06-15', '2025-06-22', 'planned', 2500.00, 2),
    ('v2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'Tokyo Explorer', 'Exploring modern and traditional Tokyo', 'd2222222-2222-2222-2222-222222222222', '2025-09-01', '2025-09-10', 'draft', 3500.00, 1),
    ('v3333333-3333-3333-3333-333333333333', '33333333-3333-3333-3333-333333333333', 'Barcelona Beach Week', 'Beach vacation in Barcelona', 'd4444444-4444-4444-4444-444444444444', '2025-07-20', '2025-07-27', 'planned', 1800.00, 2)
ON CONFLICT (id) DO NOTHING;

-- Test Bookings
INSERT INTO bookings (id, voyage_id, type, provider, confirmation_code, cost, status) VALUES
    ('b1111111-1111-1111-1111-111111111111', 'v1111111-1111-1111-1111-111111111111', 'flight', 'Air France', 'AF12345', 600.00, 'confirmed'),
    ('b2222222-2222-2222-2222-222222222222', 'v1111111-1111-1111-1111-111111111111', 'hotel', 'Hotel de Paris', 'HDR78901', 1200.00, 'confirmed'),
    ('b3333333-3333-3333-3333-333333333333', 'v3333333-3333-3333-3333-333333333333', 'flight', 'Vueling', 'VY56789', 400.00, 'confirmed')
ON CONFLICT (id) DO NOTHING;

-- Test Panoramas
INSERT INTO panoramas (id, user_id, destination_id, title, description, image_url, type, is_public, view_count) VALUES
    ('p1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'd1111111-1111-1111-1111-111111111111', 'Eiffel Tower Sunset', 'Beautiful 360° view of Eiffel Tower at sunset', 'https://storage.dreamscape.ai/panoramas/eiffel-sunset-360.jpg', '360_photo', TRUE, 1250),
    ('p2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'd2222222-2222-2222-2222-222222222222', 'Shibuya Crossing', 'Iconic Tokyo intersection in 360°', 'https://storage.dreamscape.ai/panoramas/shibuya-360.jpg', '360_photo', TRUE, 890),
    ('p3333333-3333-3333-3333-333333333333', '33333333-3333-3333-3333-333333333333', 'd4444444-4444-4444-4444-444444444444', 'Sagrada Familia Interior', 'AI-enhanced interior panorama', 'https://storage.dreamscape.ai/panoramas/sagrada-interior-360.jpg', 'ai_generated', TRUE, 567)
ON CONFLICT (id) DO NOTHING;

-- Test AI Generations
INSERT INTO ai_generations (id, user_id, voyage_id, type, prompt, status, model, tokens_used) VALUES
    ('a1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'v1111111-1111-1111-1111-111111111111', 'itinerary', 'Create 7-day Paris itinerary for romance', 'completed', 'gpt-4', 1500),
    ('a2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'v2222222-2222-2222-2222-222222222222', 'recommendation', 'Best sushi restaurants in Tokyo under $50', 'completed', 'gpt-4', 800)
ON CONFLICT (id) DO NOTHING;

-- Test Payments
INSERT INTO payments (id, user_id, voyage_id, amount, payment_method, status, provider_payment_id) VALUES
    ('pay11111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'v1111111-1111-1111-1111-111111111111', 1800.00, 'stripe', 'succeeded', 'pi_1234567890abcdef'),
    ('pay22222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'v3333333-3333-3333-3333-333333333333', 400.00, 'card', 'succeeded', 'ch_9876543210fedcba')
ON CONFLICT (id) DO NOTHING;

-- ===============================================
-- Functions & Triggers
-- ===============================================

-- Update timestamp function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to all tables with updated_at
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN
        SELECT table_name FROM information_schema.columns
        WHERE column_name = 'updated_at'
        AND table_schema = 'public'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS update_%I_updated_at ON %I', t, t);
        EXECUTE format('CREATE TRIGGER update_%I_updated_at
            BEFORE UPDATE ON %I
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column()', t, t);
    END LOOP;
END;
$$;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dev;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO dev;

-- Summary
DO $$
BEGIN
    RAISE NOTICE '✅ DreamScape Big Pods Development Database Initialized';
    RAISE NOTICE '📊 Test data loaded: % users, % destinations, % voyages',
        (SELECT COUNT(*) FROM users),
        (SELECT COUNT(*) FROM destinations),
        (SELECT COUNT(*) FROM voyages);
END;
$$;
