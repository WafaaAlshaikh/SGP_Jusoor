-- ========================================
-- Test Data for Booking System
-- All data in English
-- ========================================

USE jusoor;

-- Clean up existing test data (optional)
-- DELETE FROM Sessions WHERE session_id > 0;
-- DELETE FROM SpecialistSchedule WHERE schedule_id > 0;
-- DELETE FROM SessionType WHERE session_type_id > 0;
-- DELETE FROM Specialists WHERE specialist_id > 0;
-- DELETE FROM Children WHERE child_id > 0;
-- DELETE FROM Users WHERE user_id > 100;
-- DELETE FROM Institutions WHERE institution_id > 100;

-- ========================================
-- 1. INSERT INSTITUTION
-- ========================================
INSERT INTO Institutions (
    institution_id, 
    name, 
    description, 
    location, 
    city,
    region,
    location_lat,
    location_lng,
    location_address,
    contact_info, 
    website
) VALUES (
    101,
    'Hope Therapy Center',
    'Specialized center for children with special needs, providing behavioral therapy, speech therapy, and occupational therapy',
    'Damascus',
    'Damascus',
    'Mazzeh',
    33.5138,
    36.2765,
    'Mazzeh Street, Building 15, Damascus',
    '+963-11-1234567',
    'www.hopetherapy.sy'
);

-- ========================================
-- 2. INSERT DIAGNOSIS
-- ========================================
INSERT INTO Diagnoses (diagnosis_id, name, description) VALUES
(1, 'Autism Spectrum Disorder', 'ASD is a developmental disorder affecting communication and behavior'),
(2, 'ADHD', 'Attention Deficit Hyperactivity Disorder'),
(3, 'Down Syndrome', 'Genetic disorder caused by extra chromosome 21'),
(4, 'Speech Delay', 'Delayed development of speech and language skills')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- ========================================
-- 3. INSERT USERS (Parent, Manager, Specialists)
-- ========================================

-- Parent User
INSERT INTO Users (
    user_id,
    full_name,
    email,
    password,
    phone,
    role,
    institution_id,
    status,
    city,
    region
) VALUES (
    201,
    'Ahmad Ibrahim',
    'ahmad.parent@example.com',
    '$2b$10$rQZ5YqJ5YqJ5YqJ5YqJ5YeJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5Y', -- password: 123456
    '+963-944-123456',
    'Parent',
    NULL,
    'Approved',
    'Damascus',
    'Mazzeh'
);

-- Manager User (for institution 101)
INSERT INTO Users (
    user_id,
    full_name,
    email,
    password,
    phone,
    role,
    institution_id,
    status,
    city,
    region
) VALUES (
    202,
    'Dr. Sarah Manager',
    'sarah.manager@hopetherapy.sy',
    '$2b$10$rQZ5YqJ5YqJ5YqJ5YqJ5YeJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5Y', -- password: 123456
    '+963-944-234567',
    'Manager',
    101,
    'Approved',
    'Damascus',
    'Mazzeh'
);

-- Specialist 1: Behavioral Therapist
INSERT INTO Users (
    user_id,
    full_name,
    email,
    password,
    phone,
    role,
    institution_id,
    status,
    city,
    region
) VALUES (
    203,
    'Dr. John Smith',
    'john.therapist@hopetherapy.sy',
    '$2b$10$rQZ5YqJ5YqJ5YqJ5YqJ5YeJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5Y', -- password: 123456
    '+963-944-345678',
    'Specialist',
    101,
    'Approved',
    'Damascus',
    'Mazzeh'
);

-- Specialist 2: Speech Therapist
INSERT INTO Users (
    user_id,
    full_name,
    email,
    password,
    phone,
    role,
    institution_id,
    status,
    city,
    region
) VALUES (
    204,
    'Dr. Emily Watson',
    'emily.speech@hopetherapy.sy',
    '$2b$10$rQZ5YqJ5YqJ5YqJ5YqJ5YeJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5Y', -- password: 123456
    '+963-944-456789',
    'Specialist',
    101,
    'Approved',
    'Damascus',
    'Mazzeh'
);

-- Specialist 3: Occupational Therapist
INSERT INTO Users (
    user_id,
    full_name,
    email,
    password,
    phone,
    role,
    institution_id,
    status,
    city,
    region
) VALUES (
    205,
    'Dr. Michael Brown',
    'michael.ot@hopetherapy.sy',
    '$2b$10$rQZ5YqJ5YqJ5YqJ5YqJ5YeJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5YqJ5Y', -- password: 123456
    '+963-944-567890',
    'Specialist',
    101,
    'Approved',
    'Damascus',
    'Mazzeh'
);

-- ========================================
-- 4. INSERT SPECIALISTS
-- ========================================
INSERT INTO Specialists (
    specialist_id,
    user_id,
    institution_id,
    specialization,
    bio,
    years_experience,
    approval_status,
    start_date
) VALUES 
(301, 203, 101, 'Behavioral Therapy', 'Experienced behavioral therapist specializing in ASD and ADHD treatment', 8, 'Approved', '2020-01-15'),
(302, 204, 101, 'Speech Therapy', 'Certified speech therapist with focus on early intervention', 6, 'Approved', '2021-03-20'),
(303, 205, 101, 'Occupational Therapy', 'Occupational therapist helping children develop daily living skills', 5, 'Approved', '2021-09-10');

-- ========================================
-- 5. INSERT CHILD (Registered and Approved)
-- ========================================
INSERT INTO Children (
    child_id,
    parent_id,
    full_name,
    date_of_birth,
    diagnosis_id,
    current_institution_id,
    registration_status,
    registration_date,
    approval_date
) VALUES (
    401,
    201,
    'Omar Ahmad',
    '2018-05-15',
    1, -- ASD
    101, -- Hope Therapy Center
    'Approved',
    '2024-12-01',
    '2024-12-02'
);

-- ========================================
-- 6. INSERT SESSION TYPES
-- ========================================
INSERT INTO SessionType (
    session_type_id,
    institution_id,
    name,
    duration,
    price,
    category,
    specialist_specialization,
    target_conditions
) VALUES 
(
    501,
    101,
    'Behavioral Therapy Session',
    60,
    50.00,
    'Therapy',
    'Behavioral Therapy',
    '["Autism Spectrum Disorder", "ADHD"]'
),
(
    502,
    101,
    'Speech Therapy Session',
    45,
    45.00,
    'Therapy',
    'Speech Therapy',
    '["Autism Spectrum Disorder", "Speech Delay", "Down Syndrome"]'
),
(
    503,
    101,
    'Occupational Therapy Session',
    60,
    55.00,
    'Therapy',
    'Occupational Therapy',
    '["Autism Spectrum Disorder", "ADHD", "Down Syndrome"]'
),
(
    504,
    101,
    'Initial Assessment',
    90,
    80.00,
    'Assessment',
    'Behavioral Therapy',
    '[]' -- Available for all conditions
);

-- ========================================
-- 7. INSERT SPECIALIST SCHEDULES
-- ========================================

-- Dr. John Smith (Behavioral Therapist) - Monday to Thursday
INSERT INTO SpecialistSchedule (specialist_id, day_of_week, start_time, end_time, is_available) VALUES
(301, 'Monday', '09:00:00', '17:00:00', TRUE),
(301, 'Tuesday', '09:00:00', '17:00:00', TRUE),
(301, 'Wednesday', '09:00:00', '17:00:00', TRUE),
(301, 'Thursday', '09:00:00', '17:00:00', TRUE);

-- Dr. Emily Watson (Speech Therapist) - Sunday to Wednesday
INSERT INTO SpecialistSchedule (specialist_id, day_of_week, start_time, end_time, is_available) VALUES
(302, 'Sunday', '10:00:00', '16:00:00', TRUE),
(302, 'Monday', '10:00:00', '16:00:00', TRUE),
(302, 'Tuesday', '10:00:00', '16:00:00', TRUE),
(302, 'Wednesday', '10:00:00', '16:00:00', TRUE);

-- Dr. Michael Brown (Occupational Therapist) - Monday to Friday
INSERT INTO SpecialistSchedule (specialist_id, day_of_week, start_time, end_time, is_available) VALUES
(303, 'Monday', '08:00:00', '15:00:00', TRUE),
(303, 'Tuesday', '08:00:00', '15:00:00', TRUE),
(303, 'Wednesday', '08:00:00', '15:00:00', TRUE),
(303, 'Thursday', '08:00:00', '15:00:00', TRUE),
(303, 'Friday', '08:00:00', '15:00:00', TRUE);

-- ========================================
-- SUMMARY OF TEST DATA
-- ========================================
/*
CREDENTIALS FOR LOGIN:
=====================

Parent Account:
- Email: ahmad.parent@example.com
- Password: 123456
- Child: Omar Ahmad (Registered & Approved in Hope Therapy Center)

Manager Account:
- Email: sarah.manager@hopetherapy.sy
- Password: 123456
- Institution: Hope Therapy Center

Specialists:
1. Dr. John Smith (Behavioral Therapy)
   - Email: john.therapist@hopetherapy.sy
   - Password: 123456

2. Dr. Emily Watson (Speech Therapy)
   - Email: emily.speech@hopetherapy.sy
   - Password: 123456

3. Dr. Michael Brown (Occupational Therapy)
   - Email: michael.ot@hopetherapy.sy
   - Password: 123456

INSTITUTION:
============
- ID: 101
- Name: Hope Therapy Center
- Location: Damascus, Mazzeh

CHILD:
======
- ID: 401
- Name: Omar Ahmad
- Diagnosis: Autism Spectrum Disorder
- Status: Approved in Hope Therapy Center

SESSION TYPES AVAILABLE:
========================
1. Behavioral Therapy Session (60 min, $50)
2. Speech Therapy Session (45 min, $45)
3. Occupational Therapy Session (60 min, $55)
4. Initial Assessment (90 min, $80)

TESTING FLOW:
=============
1. Login as Parent (ahmad.parent@example.com / 123456)
2. Go to "Book Session" page
3. Select child: Omar Ahmad
4. Select session type (e.g., Behavioral Therapy)
5. Select date (any Monday-Thursday for Dr. John)
6. Select available time slot
7. Book session
8. FIRST BOOKING: Goes to Manager for approval
9. Login as Manager (sarah.manager@hopetherapy.sy / 123456)
10. Review and approve the session
11. Book another session as Parent
12. SECOND BOOKING: Approved automatically!
*/

COMMIT;
