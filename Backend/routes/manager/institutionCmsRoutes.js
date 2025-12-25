const express = require('express');
const router = express.Router();

const authMiddleware = require('../../middleware/authMiddleware');
const institutionCmsController = require('../../controllers/manager/institutionCmsController');

const isManager = (req, res, next) => {
  if (req.user.role !== 'Manager') {
    return res.status(403).json({
      success: false,
      message: 'غير مصرح - يجب أن تكون مدير مؤسسة',
    });
  }
  next();
};

router.use(authMiddleware);
router.use(isManager);

// Page content
router.get('/page-content', institutionCmsController.getPageContent);
router.put('/page-content/:key', institutionCmsController.upsertPageContentByKey);

// News
router.get('/news', institutionCmsController.listNews);
router.post('/news', institutionCmsController.createNews);
router.put('/news/:newsId', institutionCmsController.updateNews);
router.delete('/news/:newsId', institutionCmsController.deleteNews);

// Programs
router.get('/programs', institutionCmsController.listPrograms);
router.post('/programs', institutionCmsController.createProgram);
router.put('/programs/:programId', institutionCmsController.updateProgram);
router.delete('/programs/:programId', institutionCmsController.deleteProgram);

// Projects
router.get('/projects', institutionCmsController.listProjects);
router.post('/projects', institutionCmsController.createProject);
router.put('/projects/:projectId', institutionCmsController.updateProject);
router.delete('/projects/:projectId', institutionCmsController.deleteProject);

// FAQ
router.get('/faq', institutionCmsController.listFAQ);
router.post('/faq', institutionCmsController.createFAQ);
router.put('/faq/:faqId', institutionCmsController.updateFAQ);
router.delete('/faq/:faqId', institutionCmsController.deleteFAQ);

// Media
router.get('/media', institutionCmsController.listMedia);
router.post('/media', institutionCmsController.createMedia);
router.put('/media/:mediaId', institutionCmsController.updateMedia);
router.delete('/media/:mediaId', institutionCmsController.deleteMedia);

module.exports = router;
