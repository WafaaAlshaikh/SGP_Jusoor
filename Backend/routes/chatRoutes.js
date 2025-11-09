const express = require('express');
const router = express.Router();
const { User, Session, Child, Specialist, Institution, sequelize } = require('../model/index');
const authMiddleware = require('../middleware/authMiddleware');
const { Op } = require('sequelize');

// 🔹 Get all users that the current user can chat with
router.get('/available-users', authMiddleware, async (req, res) => {
  try {
    const currentUser = req.user;
    let availableUsers = [];

    console.log(`🔄 Fetching available chat users for user: ${currentUser.user_id} (${currentUser.role})`);

    // Validate user data
    if (!currentUser || !currentUser.user_id) {
      return res.status(400).json({
        success: false,
        message: 'Invalid user data'
      });
    }

    switch (currentUser.role) {
      case 'Parent':
        availableUsers = await getUsersForParent(currentUser.user_id);
        break;
      case 'Specialist':
        availableUsers = await getUsersForSpecialist(currentUser.user_id);
        break;
      case 'Manager':
        availableUsers = await getUsersForManager(currentUser.user_id);
        break;
      case 'Admin':
        availableUsers = await getUsersForAdmin();
        break;
      default:
        console.warn(`⚠️ Unknown role: ${currentUser.role}`);
        availableUsers = [];
    }

    console.log(`✅ Successfully fetched ${availableUsers.length} users for chat`);
    
    res.json({
      success: true,
      data: availableUsers
    });

  } catch (error) {
    console.error('❌ Error fetching chat users:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch available chat users',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// 🔹 Helper function: Get users for Parent
async function getUsersForParent(parentId) {
  try {
    console.log(`👨‍👦 Fetching users for parent: ${parentId}`);

    // Direct query to get all approved specialists and managers
    const query = `
      SELECT 
        u.user_id as id,
        u.full_name as name,
        u.email,
        u.role,
        u.profile_picture as profileImage,
        i.name as institution,
        CASE 
          WHEN u.role = 'Specialist' THEN 'Specialist'
          WHEN u.role = 'Manager' THEN 'Manager'
        END as specialization
      FROM Users u
      LEFT JOIN Institutions i ON u.institution_id = i.institution_id
      WHERE u.role IN ('Specialist', 'Manager')
      AND u.status = 'Approved'
      ORDER BY u.role, u.full_name
    `;

    const [users] = await sequelize.query(query);
    
    console.log(`✅ Successfully fetched ${users.length} users for parent`);
    return users;

  } catch (error) {
    console.error('❌ Error in getUsersForParent:', error);
    throw error;
  }
}

// 🔹 Helper function: Get users for Specialist
async function getUsersForSpecialist(specialistId) {
  try {
    console.log(`👨‍⚕️ Fetching users for specialist: ${specialistId}`);
    
    // First: Get current specialist data from Specialist table
    const currentSpecialist = await Specialist.findOne({
      where: { specialist_id: specialistId },
      attributes: ['specialist_id', 'institution_id'],
      raw: true
    });
    
    if (!currentSpecialist) {
      throw new Error('Specialist not found');
    }

    const users = [];

    // 1. Other specialists in the same institution
    if (currentSpecialist.institution_id) {
      // Get other specialists in the same institution
      const sameInstitutionQuery = `
        SELECT 
          u.user_id as id,
          u.full_name as name,
          u.email,
          u.role,
          u.profile_picture as profileImage,
          i.name as institution,
          'Specialist' as specialization
        FROM Specialists s
        INNER JOIN Users u ON s.specialist_id = u.user_id
        LEFT JOIN Institutions i ON s.institution_id = i.institution_id
        WHERE s.institution_id = :institutionId
        AND s.specialist_id != :specialistId
        AND u.status = 'Approved'
        ORDER BY u.full_name
      `;

      const [sameInstitutionSpecialists] = await sequelize.query(sameInstitutionQuery, {
        replacements: { 
          institutionId: currentSpecialist.institution_id,
          specialistId: specialistId
        }
      });

      users.push(...sameInstitutionSpecialists);

      // 2. Manager in the same institution
      const managerQuery = `
        SELECT 
          u.user_id as id,
          u.full_name as name,
          u.email,
          u.role,
          u.profile_picture as profileImage,
          i.name as institution,
          'Manager' as specialization
        FROM Users u
        LEFT JOIN Institutions i ON u.institution_id = i.institution_id
        WHERE u.institution_id = :institutionId
        AND u.role = 'Manager'
        AND u.status = 'Approved'
      `;

      const [managers] = await sequelize.query(managerQuery, {
        replacements: { institutionId: currentSpecialist.institution_id }
      });

      users.push(...managers);
    }

    // 3. Parents of children who have sessions with the specialist
    const parentQuery = `
      SELECT DISTINCT
        u.user_id as id,
        u.full_name as name,
        u.email,
        u.role,
        u.profile_picture as profileImage,
        'Parent' as specialization
      FROM Sessions s
      INNER JOIN Children c ON s.child_id = c.child_id
      INNER JOIN Users u ON c.parent_id = u.user_id
      WHERE s.specialist_id = :specialistId
      AND s.status IN ('Scheduled', 'Completed', 'Confirmed')
      AND u.status = 'Approved'
      ORDER BY u.full_name
    `;

    const [parents] = await sequelize.query(parentQuery, {
      replacements: { specialistId }
    });

    parents.forEach(parent => {
      users.push({
        id: parent.id,
        name: parent.name,
        email: parent.email,
        role: parent.role,
        institution: null,
        profileImage: parent.profileImage,
        specialization: parent.specialization
      });
    });

    console.log(`✅ Successfully fetched ${users.length} users for specialist`);
    return users;

  } catch (error) {
    console.error('❌ Error in getUsersForSpecialist:', error);
    throw error;
  }
}

// 🔹 Helper function: Get users for Manager
async function getUsersForManager(managerId) {
  try {
    console.log(`👨‍💼 Fetching users for manager: ${managerId}`);
    
    // First: Get current manager data
    const currentManager = await User.findOne({
      where: { user_id: managerId },
      attributes: ['user_id', 'institution_id'],
      raw: true
    });
    
    if (!currentManager) {
      throw new Error('Manager not found');
    }

    const users = [];

    // 1. All specialists in manager's institution
    if (currentManager.institution_id) {
      const specialistsQuery = `
        SELECT 
          u.user_id as id,
          u.full_name as name,
          u.email,
          u.role,
          u.profile_picture as profileImage,
          i.name as institution,
          'Specialist' as specialization
        FROM Specialists s
        INNER JOIN Users u ON s.specialist_id = u.user_id
        LEFT JOIN Institutions i ON s.institution_id = i.institution_id
        WHERE s.institution_id = :institutionId
        AND u.status = 'Approved'
        ORDER BY u.full_name
      `;

      const [specialists] = await sequelize.query(specialistsQuery, {
        replacements: { institutionId: currentManager.institution_id }
      });

      users.push(...specialists);
    }

    // 2. All parents who have children in the institution
    const parentsQuery = `
      SELECT DISTINCT
        u.user_id as id,
        u.full_name as name,
        u.email,
        u.role,
        u.profile_picture as profileImage,
        'Parent' as specialization
      FROM Children c
      INNER JOIN Users u ON c.parent_id = u.user_id
      WHERE c.current_institution_id = :institutionId
      AND u.status = 'Approved'
      ORDER BY u.full_name
    `;

    if (currentManager.institution_id) {
      const [parents] = await sequelize.query(parentsQuery, {
        replacements: { institutionId: currentManager.institution_id }
      });

      users.push(...parents);
    }

    console.log(`✅ Successfully fetched ${users.length} users for manager`);
    return users;

  } catch (error) {
    console.error('❌ Error in getUsersForManager:', error);
    throw error;
  }
}

// 🔹 Helper function: Get all users (for Admin)
async function getUsersForAdmin() {
  try {
    console.log(`👑 Fetching all users for admin`);
    
    // Direct query to get all users
    const query = `
      SELECT 
        u.user_id as id,
        u.full_name as name,
        u.email,
        u.role,
        u.profile_picture as profileImage,
        i.name as institution,
        CASE 
          WHEN u.role = 'Specialist' THEN 'Specialist'
          WHEN u.role = 'Parent' THEN 'Parent'
          WHEN u.role = 'Manager' THEN 'Manager'
        END as specialization
      FROM Users u
      LEFT JOIN Institutions i ON u.institution_id = i.institution_id
      WHERE u.role IN ('Specialist', 'Manager', 'Parent')
      AND u.status = 'Approved'
      ORDER BY u.role, u.full_name
    `;

    const [users] = await sequelize.query(query);
    
    console.log(`✅ Successfully fetched ${users.length} users for admin`);
    return users;

  } catch (error) {
    console.error('❌ Error in getUsersForAdmin:', error);
    throw error;
  }
}

module.exports = router;