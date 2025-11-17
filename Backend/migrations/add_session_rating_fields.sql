-- Migration: Add Session Rating and Cancellation Fields
-- Date: 2025-01-XX
-- Description: Add fields for parent rating, specialist rating, and cancellation reason

-- Add rating and review fields
ALTER TABLE Sessions
ADD COLUMN parent_rating DECIMAL(2, 1) NULL COMMENT 'Parent rating (1-5)' AFTER manager_notes,
ADD COLUMN parent_review TEXT NULL COMMENT 'Parent review text' AFTER parent_rating,
ADD COLUMN specialist_rating DECIMAL(2, 1) NULL COMMENT 'Specialist rating (calculated from parent ratings)' AFTER parent_review,
ADD COLUMN cancellation_reason TEXT NULL COMMENT 'Reason for cancellation' AFTER specialist_rating;

-- Add index for performance on rating queries
CREATE INDEX idx_sessions_parent_rating ON Sessions(parent_rating);
CREATE INDEX idx_sessions_specialist_rating ON Sessions(specialist_rating);

