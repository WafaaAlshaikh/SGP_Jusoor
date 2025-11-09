const express = require('express');
const router = express.Router();
const { Child, Evaluation, Specialist, User, Parent, Session } = require('../model');
const authMiddleware = require('../middleware/authMiddleware');
const multer = require('multer');
const path = require('path');
const PDFDocument = require('pdfkit');

// ✅ استيراد sequelize من ملف config
const sequelize = require('../config/db');

const {
  getMyEvaluations,
  updateEvaluation,
  deleteEvaluation,
  getEvaluationById
} = require('../controllers/evaluationController');

// ✅ 1. API لارجاع الأطفال الذين لديهم جلسات مع الأخصائي الحالي
router.get('/children', authMiddleware, async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({
        success: false,
        error: 'Access denied. Only specialists can view children'
      });
    }

    // أولاً: جلب children IDs الذين لديهم جلسات مع الأخصائي
    const sessions = await Session.findAll({
      where: { 
        specialist_id: specialistId,
        status: ['Scheduled', 'Completed']
      },
      attributes: ['child_id'],
      raw: true
    });

    const childIds = [...new Set(sessions.map(s => s.child_id))];

    if (childIds.length === 0) {
      return res.json({
        success: true,
        data: []
      });
    }

    // ثانياً: جلب بيانات الأطفال
    const children = await Child.findAll({
      where: {
        child_id: childIds
      },
      attributes: ['child_id', 'full_name', 'date_of_birth', 'gender'],
      include: [
        {
          model: Parent,
          attributes: ['parent_id'],
          include: [{
            model: User,
            attributes: ['full_name']
          }]
        }
      ]
    });
    
    // تبسيط البيانات للفرونت
    const simplifiedChildren = children.map(child => ({
      id: child.child_id,
      name: child.full_name,
      dob: child.date_of_birth,
      gender: child.gender,
      parentName: child.Parent?.User?.full_name || 'Unknown'
    }));
    
    res.json({
      success: true,
      data: simplifiedChildren
    });
    
  } catch (error) {
    console.error('Error fetching children:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// ✅ 2. API لإضافة التقييم (باستخدام التوكن)
router.post('/add', authMiddleware, async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { child_id, evaluation_type, notes, progress_score, attachment, created_at } = req.body;
    
    // تحقق من البيانات المطلوبة
    if (!child_id || !evaluation_type) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: child_id and evaluation_type'
      });
    }
    
    // تحقق إذا كان المستخدم أخصائي
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({
        success: false,
        error: 'Access denied. Only specialists can add evaluations'
      });
    }

    // تحقق إذا كان الأخصائي موجود في جدول Specialists
    const specialist = await Specialist.findByPk(specialistId);
    if (!specialist) {
      return res.status(404).json({
        success: false,
        error: 'Specialist profile not found'
      });
    }

    // استخدام التاريخ المختار من المستخدم أو التاريخ الحالي إذا لم يتم اختيار تاريخ
    const evaluationDate = created_at ? new Date(created_at) : new Date();

    // أنشئ التقييم
    const newEvaluation = await Evaluation.create({
      child_id: parseInt(child_id),
      specialist_id: specialistId,
      evaluation_type,
      notes: notes || '',
      progress_score: progress_score || 0,
      attachment: attachment || null,
      created_at: evaluationDate
    });
    
    res.status(201).json({
      success: true,
      message: 'Evaluation added successfully!',
      data: newEvaluation
    });
    
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// إعداد multer لرفع الملفات
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/evaluations/');
  },
  filename: (req, file, cb) => {
    const uniqueName = Date.now() + '-' + Math.round(Math.random() * 1E9) + path.extname(file.originalname);
    cb(null, uniqueName);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }
});

// ✅ API لرفع الملف (باستخدام التوكن)
router.post('/upload', authMiddleware, upload.single('attachment'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No file uploaded'
      });
    }
    
    res.json({
      success: true,
      message: 'File uploaded successfully',
      filename: req.file.filename,
      originalName: req.file.originalname,
      path: req.file.path
    });
    
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// ✅ API لتصدير التقييم إلى PDF - الإصدار المصحح
router.get('/:evaluation_id/export-pdf', authMiddleware, async (req, res) => {
  try {
    const { evaluation_id } = req.params;
    const specialistId = req.user.user_id;

    console.log('🔍 Exporting PDF for evaluation:', evaluation_id, 'specialist:', specialistId);

    // استعلام مصحح
    const query = `
      SELECT 
        e.evaluation_id,
        e.evaluation_type,
        e.notes,
        e.progress_score,
        e.created_at,
        e.attachment,
        c.full_name as child_name,
        c.date_of_birth as child_dob,
        c.gender as child_gender,
        u_parent.full_name as parent_name,
        u_spec.full_name as specialist_name
      FROM Evaluations e
      LEFT JOIN Children c ON e.child_id = c.child_id
      LEFT JOIN Parents p ON c.parent_id = p.parent_id
      LEFT JOIN Users u_parent ON p.parent_id = u_parent.user_id
      LEFT JOIN Users u_spec ON e.specialist_id = u_spec.user_id
      WHERE e.evaluation_id = ? AND e.specialist_id = ?
    `;

    const [evaluations] = await sequelize.query(query, {
      replacements: [parseInt(evaluation_id), specialistId]
    });

    if (evaluations.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Evaluation not found'
      });
    }

    const evaluation = evaluations[0];

    // إنشاء مستند PDF
    const doc = new PDFDocument();
    
    // إعداد رأس الاستجابة - مهم للتحميل
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=evaluation-${evaluation_id}.pdf`);
    res.setHeader('Cache-Control', 'no-cache');

    // إرسال PDF كاستجابة
    doc.pipe(res);

    // إضافة محتوى PDF
    _generatePDFContent(doc, evaluation);

    // إنهاء المستند
    doc.end();

  } catch (error) {
    console.error('❌ PDF export error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to export PDF: ' + error.message
    });
  }
});

// دالة مساعدة لإنشاء محتوى PDF
function _generatePDFContent(doc, evaluation) {
  // العنوان الرئيسي
  doc.fontSize(20)
     .font('Helvetica-Bold')
     .fillColor('#2c5aa0')
     .text('EVALUATION REPORT', 50, 50, { align: 'center' });

  // خط فاصل
  doc.moveTo(50, 80)
     .lineTo(550, 80)
     .strokeColor('#2c5aa0')
     .lineWidth(2)
     .stroke();

  let yPosition = 100;

  // معلومات الطفل
  doc.fontSize(14)
     .font('Helvetica-Bold')
     .fillColor('#333333')
     .text('Child Information:', 50, yPosition);
  
  yPosition += 25;
  doc.fontSize(12)
     .font('Helvetica')
     .text(`Name: ${evaluation.child_name || 'N/A'}`, 50, yPosition);
  
  yPosition += 20;
  doc.text(`Date of Birth: ${evaluation.child_dob ? new Date(evaluation.child_dob).toLocaleDateString() : 'N/A'}`, 50, yPosition);
  
  yPosition += 20;
  doc.text(`Gender: ${evaluation.child_gender || 'N/A'}`, 50, yPosition);
  
  yPosition += 20;
  doc.text(`Parent: ${evaluation.parent_name || 'N/A'}`, 50, yPosition);

  yPosition += 40;

  // معلومات التقييم
  doc.fontSize(14)
     .font('Helvetica-Bold')
     .text('Evaluation Details:', 50, yPosition);
  
  yPosition += 25;
  doc.fontSize(12)
     .font('Helvetica')
     .text(`Evaluation ID: ${evaluation.evaluation_id}`, 50, yPosition);
  
  yPosition += 20;
  doc.text(`Type: ${evaluation.evaluation_type}`, 50, yPosition);
  
  yPosition += 20;
  doc.text(`Date: ${new Date(evaluation.created_at).toLocaleDateString()}`, 50, yPosition);
  
  yPosition += 20;
  doc.text(`Specialist: ${evaluation.specialist_name || 'N/A'}`, 50, yPosition);

  yPosition += 40;

  // درجة التقدم
  doc.fontSize(14)
     .font('Helvetica-Bold')
     .text('Progress Score:', 50, yPosition);
  
  yPosition += 25;
  const progressScore = evaluation.progress_score || 0;
  const progressWidth = (progressScore / 100) * 200;
  
  // شريط التقدم
  doc.rect(50, yPosition, 200, 15)
     .fillColor('#e0e0e0')
     .fill();
  
  doc.rect(50, yPosition, progressWidth, 15)
     .fillColor(progressScore < 40 ? '#ff4444' : progressScore < 70 ? '#ffaa00' : '#00c851')
     .fill();
  
  doc.fontSize(10)
     .font('Helvetica-Bold')
     .fillColor('#333333')
     .text(`${progressScore}%`, 260, yPosition + 3);

  yPosition += 40;

  // الملاحظات
  doc.fontSize(14)
     .font('Helvetica-Bold')
     .text('Notes & Observations:', 50, yPosition);
  
  yPosition += 25;
  const notes = evaluation.notes || 'No notes provided.';
  doc.fontSize(11)
     .font('Helvetica')
     .fillColor('#555555')
     .text(notes, 50, yPosition, {
       width: 500,
       align: 'left'
     });

  // تذييل الصفحة
  const pageHeight = doc.page.height;
  doc.fontSize(8)
     .font('Helvetica-Oblique')
     .fillColor('#888888')
     .text(`Generated on ${new Date().toLocaleDateString()}`, 50, pageHeight - 50);
}

// ✅ الحصول على جميع تقييمات الأخصائي الحالي
router.get('/my-evaluations', authMiddleware, getMyEvaluations);

// ✅ الحصول على تقييم محدد
router.get('/:evaluation_id', authMiddleware, getEvaluationById);

// ✅ تحديث تقييم
router.put('/:evaluation_id', authMiddleware, updateEvaluation);

// ✅ حذف تقييم
router.delete('/:evaluation_id', authMiddleware, deleteEvaluation);

module.exports = router;