// routes/testRoutes.js 
//file for testing 
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');

router.get('/testauth', authMiddleware, (req, res) => {
  res.json({ message: 'Token valid!', user: req.user });
});

module.exports = router;
