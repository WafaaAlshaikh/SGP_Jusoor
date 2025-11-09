// routes/diagnosisRoutes.js
const express = require('express');
const router = express.Router();
const Diagnosis = require('../model/Diagnosis');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/', authMiddleware, async (req, res) => {
  try {
    const diagnoses = await Diagnosis.findAll({ attributes: ['diagnosis_id', 'name'] });
    res.status(200).json(diagnoses);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
