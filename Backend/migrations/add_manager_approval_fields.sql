-- Migration: Add Manager Approval Fields to Sessions Table
-- Date: 2025-01-08
-- Description: Add fields for tracking first bookings and manager approvals

-- 1. Update ENUM for status column to include new statuses
ALTER TABLE Sessions 
MODIFY COLUMN status ENUM(
  'Pending Manager Approval',
  'Pending Specialist Approval',
  'Approved',
  'Pending Payment',
  'Confirmed',
  'Scheduled',
  'Completed',
  'Cancelled',
  'Rejected',
  'Refunded'
) DEFAULT 'Pending Manager Approval';

-- 2. Add new columns for tracking first bookings and manager approvals
ALTER TABLE Sessions
ADD COLUMN is_first_booking BOOLEAN DEFAULT FALSE AFTER parent_notes,
ADD COLUMN approved_by_manager_id BIGINT UNSIGNED NULL AFTER is_first_booking,
ADD COLUMN manager_approval_date DATETIME NULL AFTER approved_by_manager_id,
ADD COLUMN manager_notes TEXT NULL AFTER manager_approval_date;

-- 3. Add foreign key constraint for manager approval
ALTER TABLE Sessions
ADD CONSTRAINT fk_sessions_manager
FOREIGN KEY (approved_by_manager_id) REFERENCES Users(user_id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- 4. Add index for performance on common queries
CREATE INDEX idx_sessions_status ON Sessions(status);
CREATE INDEX idx_sessions_first_booking ON Sessions(is_first_booking);
CREATE INDEX idx_sessions_manager_approval ON Sessions(approved_by_manager_id);

-- 5. Update existing sessions to have correct status
-- All existing pending sessions should be marked as needing specialist approval
UPDATE Sessions 
SET status = 'Pending Specialist Approval'
WHERE status = 'Pending Approval';

-- 6. Mark all existing approved/completed sessions as not first bookings
UPDATE Sessions 
SET is_first_booking = FALSE
WHERE status IN ('Approved', 'Completed', 'Confirmed', 'Scheduled');

COMMIT;
