// routes/auth.js
const express = require('express');
const router = express.Router();
const { signupInitial, verifySignup } = require('../controllers/signUpController');

// ✅ الطريقة الصحيحة - تأكد أن الـ functions مستوردة بشكل صحيح
router.post('/signup', signupInitial);
router.post('/verify-signup', verifySignup);

module.exports = router;