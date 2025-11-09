// routes/vacationRoutes.js
const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const vacationController = require('../controllers/VacationController');

// Specialist actions
router.post('/', auth, vacationController.createVacation);
router.get('/', auth, vacationController.getMyVacations);
router.put('/:id', auth, vacationController.updateVacation);
router.delete('/:id', auth, vacationController.deleteVacation);

// Manager actions
router.get('/institution/all', auth, vacationController.getInstitutionVacations);
router.put('/institution/:id', auth, vacationController.updateVacationStatus);
router.get('/unavailable', auth, vacationController.getUnavailableDates);
// في ملف routes/vacationRoutes.js
router.get('/manager/notifications', auth, vacationController.getManagerVacationNotifications);
module.exports = router;