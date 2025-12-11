const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { User, Institution, Specialist } = require('../model/index');
const bcrypt = require('bcrypt');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ========== Multer Configuration for Profile Pictures ==========
const profileStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = 'uploads/profiles/';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const userId = req.user.user_id;
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `user_${userId}_${uniqueSuffix}${ext}`);
  }
});

const profileUpload = multer({
  storage: profileStorage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: function (req, file, cb) {
    const allowedTypes =[
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/gif',
      'image/webp',
      'image/bmp',
      'image/svg+xml',
      'application/octet-stream' // إضافة هذا!
    ];
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    const ext = path.extname(file.originalname).toLowerCase();
    
    if (allowedTypes.includes(file.mimetype) && allowedExtensions.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed (JPG, PNG, GIF, WEBP)'), false);
    }
  }
});

// ========== Upload Profile Picture ==========
router.post('/upload-profile-picture', 
  authMiddleware, 
  profileUpload.single('profile_picture'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ 
          success: false,
          message: 'No image file uploaded' 
        });
      }

      const userId = req.user.user_id;
      const user = await User.findByPk(userId);
      
      if (!user) {
        // Delete the uploaded file if user not found
        fs.unlinkSync(req.file.path);
        return res.status(404).json({ 
          success: false,
          message: 'User not found' 
        });
      }

      // Delete old profile picture if exists
      if (user.profile_picture) {
        try {
          const oldFilename = user.profile_picture.split('/').pop();
          const oldPath = path.join(__dirname, '../uploads/profiles/', oldFilename);
          if (fs.existsSync(oldPath)) {
            fs.unlinkSync(oldPath);
          }
        } catch (deleteError) {
          console.log('Could not delete old image:', deleteError.message);
        }
      }

      // Create the URL for the new profile picture
      const protocol = req.protocol;
      const host = req.get('host');
      const profilePictureUrl = `${protocol}://${host}/uploads/profiles/${req.file.filename}`;

      // Update user record
      await User.update({
        profile_picture: profilePictureUrl,
        updated_at: new Date()
      }, {
        where: { user_id: userId }
      });

      // Get updated user data
      const updatedUser = await User.findOne({
        where: { user_id: userId },
        attributes: ['user_id', 'full_name', 'email', 'phone', 'role', 'profile_picture', 'status', 'created_at']
      });

      res.json({
        success: true,
        message: 'Profile picture uploaded successfully',
        data: {
          profile_picture: profilePictureUrl,
          user: updatedUser
        }
      });

    } catch (error) {
      console.error('Error uploading profile picture:', error);
      
      // Delete uploaded file if error occurred
      if (req.file && req.file.path) {
        try {
          fs.unlinkSync(req.file.path);
        } catch (deleteError) {
          console.log('Could not delete uploaded file:', deleteError.message);
        }
      }
      
      res.status(500).json({ 
        success: false,
        message: 'Error uploading profile picture',
        error: error.message 
      });
    }
  }
);

// ========== Get User Profile ==========
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.user_id;

    const user = await User.findOne({
      where: { user_id: userId },
      include: [
        {
          model: Institution,
          as: 'institution',
          attributes: ['institution_id', 'name', 'location', 'contact_info']
        }
      ]
    });

    if (!user) {
      return res.status(404).json({ 
        success: false,
        message: 'User not found' 
      });
    }

    // Get specialist info if user is specialist
    let specialistInfo = null;
    if (user.role === 'Specialist') {
      specialistInfo = await Specialist.findOne({
        where: { specialist_id: userId },
        include: [
          {
            model: Institution,
            attributes: ['institution_id', 'name']
          }
        ]
      });
    }

    const userProfile = {
      user_id: user.user_id,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      profile_picture: user.profile_picture,
      status: user.status,
      created_at: user.created_at,
      institution: user.institution,
      specialist_info: specialistInfo
    };

    res.json({
      success: true,
      data: userProfile
    });

  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error',
      error: error.message 
    });
  }
});

// ========== Update User Profile ==========
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { full_name, phone, profile_picture } = req.body;

    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({ 
        success: false,
        message: 'User not found' 
      });
    }

    // Allowed updates
    const allowedUpdates = {};
    if (full_name !== undefined) allowedUpdates.full_name = full_name;
    if (phone !== undefined) allowedUpdates.phone = phone;
    if (profile_picture !== undefined) allowedUpdates.profile_picture = profile_picture;

    // Add updated_at
    allowedUpdates.updated_at = new Date();

    await User.update(allowedUpdates, {
      where: { user_id: userId }
    });

    // Return updated data
    const updatedUser = await User.findOne({
      where: { user_id: userId },
      include: [
        {
          model: Institution,
          as: 'institution',
          attributes: ['institution_id', 'name', 'location', 'contact_info']
        }
      ]
    });

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: updatedUser
    });

  } catch (error) {
    console.error('Error updating user profile:', error);
    res.status(500).json({ 
      success: false,
      message: 'Error updating data',
      error: error.message 
    });
  }
});

// ========== Update Specialist Info ==========
router.put('/specialist-info', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { specialization, years_experience, salary } = req.body;

    // Check if user is specialist
    const user = await User.findByPk(userId);
    if (!user || user.role !== 'Specialist') {
      return res.status(403).json({ 
        success: false,
        message: 'This service is for specialists only' 
      });
    }

    const specialist = await Specialist.findOne({ where: { specialist_id: userId } });
    if (!specialist) {
      return res.status(404).json({ 
        success: false,
        message: 'Specialist data not found' 
      });
    }

    const allowedUpdates = {};
    if (specialization !== undefined) allowedUpdates.specialization = specialization;
    if (years_experience !== undefined) allowedUpdates.years_experience = years_experience;
    if (salary !== undefined) allowedUpdates.salary = salary;

    await Specialist.update(allowedUpdates, {
      where: { specialist_id: userId }
    });

    const updatedSpecialist = await Specialist.findOne({
      where: { specialist_id: userId },
      include: [
        {
          model: Institution,
          attributes: ['institution_id', 'name']
        }
      ]
    });

    res.json({
      success: true,
      message: 'Specialist info updated successfully',
      data: updatedSpecialist
    });

  } catch (error) {
    console.error('Error updating specialist info:', error);
    res.status(500).json({ 
      success: false,
      message: 'Error updating data',
      error: error.message 
    });
  }
});

// ========== Change Password ==========
router.put('/change-password', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ 
        success: false,
        message: 'Current and new password are required' 
      });
    }

    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({ 
        success: false,
        message: 'User not found' 
      });
    }

    // Verify current password
    const isPasswordValid = await bcrypt.compare(currentPassword, user.password);
    if (!isPasswordValid) {
      return res.status(400).json({ 
        success: false,
        message: 'Current password is incorrect' 
      });
    }

    // Hash new password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);

    await User.update(
      { 
        password: hashedPassword,
        updated_at: new Date()
      },
      { where: { user_id: userId } }
    );

    res.json({
      success: true,
      message: 'Password changed successfully'
    });

  } catch (error) {
    console.error('Error changing password:', error);
    res.status(500).json({ 
      success: false,
      message: 'Error changing password',
      error: error.message 
    });
  }
});

module.exports = router;