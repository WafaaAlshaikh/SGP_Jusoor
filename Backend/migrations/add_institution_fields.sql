-- Migration: Add new fields to Institutions table
-- Date: 2025-11-10
-- Description: Add services_offered, conditions_supported, rating, price_range, capacity, available_slots

ALTER TABLE Institutions
ADD COLUMN IF NOT EXISTS services_offered TEXT COMMENT 'Comma-separated services like: Speech Therapy, Occupational Therapy, etc.',
ADD COLUMN IF NOT EXISTS conditions_supported TEXT COMMENT 'Comma-separated conditions like: Autism, ADHD, Down Syndrome, etc.',
ADD COLUMN IF NOT EXISTS rating DECIMAL(3, 2) DEFAULT 0.0 COMMENT 'Rating from 0.0 to 5.0',
ADD COLUMN IF NOT EXISTS price_range VARCHAR(50) COMMENT 'e.g., "50-100 JD" or "Free-500 JD"',
ADD COLUMN IF NOT EXISTS capacity INT COMMENT 'Maximum number of children',
ADD COLUMN IF NOT EXISTS available_slots INT COMMENT 'Current available slots';

-- Add sample data for existing institutions
UPDATE Institutions 
SET 
  services_offered = 'Speech Therapy, Occupational Therapy, Behavioral Therapy, Physical Therapy',
  conditions_supported = 'Autism, ADHD, Down Syndrome, Speech Delay, Learning Disabilities',
  rating = 4.5,
  price_range = '50-150 JD',
  capacity = 100,
  available_slots = 25
WHERE institution_id = 1 AND name = 'Yasmeen Charity';

UPDATE Institutions 
SET 
  services_offered = 'Behavioral Therapy, Educational Support, Psychological Counseling, Speech Therapy',
  conditions_supported = 'ADHD, Behavioral Issues, Learning Disabilities, Autism',
  rating = 4.2,
  price_range = '40-120 JD',
  capacity = 80,
  available_slots = 15
WHERE institution_id = 2 AND name = 'Sanad Center';

-- You can add more updates for other institutions as needed

-- Verify the changes
SELECT institution_id, name, services_offered, conditions_supported, rating, price_range, capacity, available_slots
FROM Institutions;
