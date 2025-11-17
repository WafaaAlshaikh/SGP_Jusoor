const { Sequelize } = require('sequelize');
const bcrypt = require('bcrypt');
const User = require('./model/User'); 
require('dotenv').config();

(async () => {
  try {
    const email = 'admin@jusoor.com'; 
    const newPassword = 'admin123';   

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    console.log('🔐 New hashed password:', hashedPassword);

    const adminUser = await User.findOne({ where: { email } });

    if (!adminUser) {
      console.log('❌ Admin not found!');
      return process.exit();
    }

    adminUser.password = hashedPassword;
    await adminUser.save();

    console.log('✅ Admin password updated successfully!');
    process.exit();
  } catch (err) {
    console.error('❌ Error updating admin password:', err);
    process.exit(1);
  }
})();
