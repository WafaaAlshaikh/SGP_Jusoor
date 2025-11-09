const { Evaluation, Child, Specialist, User, Parent } = require('../model');
const sequelize = require('../config/db');

// ✅ الحصول على جميع تقييمات الأخصائي الحالي باستخدام SQL مباشرة
const getMyEvaluations = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    console.log('🔍 Fetching evaluations for specialist:', specialistId);

    // استعلام SQL مباشر يتجنب مشاكل العلاقات
    const query = `
      SELECT 
        e.evaluation_id,
        e.child_id,
        e.specialist_id,
        e.evaluation_type,
        e.notes,
        e.progress_score,
        e.attachment,
        e.created_at,
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
      WHERE e.specialist_id = ?
      ORDER BY e.created_at DESC
    `;

    const [evaluations] = await sequelize.query(query, {
      replacements: [specialistId]
    });

    console.log('📊 Evaluations found:', evaluations.length);

    if (evaluations.length === 0) {
      return res.json({
        success: true,
        data: [],
        count: 0,
        message: 'No evaluations found'
      });
    }

    res.json({
      success: true,
      data: evaluations,
      count: evaluations.length
    });

  } catch (error) {
    console.error('❌ Get evaluations error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch evaluations: ' + error.message
    });
  }
};

// ✅ تحديث تقييم
const updateEvaluation = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { evaluation_id } = req.params;
    const { evaluation_type, notes, progress_score } = req.body;

    console.log('✏️ Update request:', { evaluation_id, specialistId, body: req.body });

    // استخدام SQL مباشرة
    const updateQuery = `
      UPDATE Evaluations 
      SET evaluation_type = ?, notes = ?, progress_score = ?
      WHERE evaluation_id = ? AND specialist_id = ?
    `;
    
    const [result] = await sequelize.query(updateQuery, {
      replacements: [
        evaluation_type,
        notes,
        progress_score ? parseFloat(progress_score) : null,
        parseInt(evaluation_id),
        specialistId
      ]
    });

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        error: 'Evaluation not found or access denied'
      });
    }

    res.json({
      success: true,
      message: 'Evaluation updated successfully',
      data: {
        evaluation_id: parseInt(evaluation_id),
        evaluation_type,
        notes,
        progress_score: progress_score ? parseFloat(progress_score) : null
      }
    });

  } catch (error) {
    console.error('❌ Update evaluation error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update evaluation: ' + error.message
    });
  }
};

// ✅ حذف تقييم
const deleteEvaluation = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { evaluation_id } = req.params;

    console.log('🗑️ Delete request:', { evaluation_id, specialistId });

    // استخدام SQL مباشرة
    const [result] = await sequelize.query(
      'DELETE FROM Evaluations WHERE evaluation_id = ? AND specialist_id = ?',
      {
        replacements: [parseInt(evaluation_id), specialistId]
      }
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        error: 'Evaluation not found or access denied'
      });
    }

    res.json({
      success: true,
      message: 'Evaluation deleted successfully'
    });

  } catch (error) {
    console.error('❌ Delete evaluation error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete evaluation: ' + error.message
    });
  }
};

// ✅ الحصول على تقييم محدد
const getEvaluationById = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { evaluation_id } = req.params;

    console.log('🔍 Get evaluation by ID:', { evaluation_id, specialistId });

    const query = `
      SELECT 
        e.evaluation_id,
        e.child_id,
        e.specialist_id,
        e.evaluation_type,
        e.notes,
        e.progress_score,
        e.attachment,
        e.created_at,
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

    res.json({
      success: true,
      data: evaluations[0]
    });

  } catch (error) {
    console.error('❌ Get evaluation by ID error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch evaluation: ' + error.message
    });
  }
};

module.exports = {
  getMyEvaluations,
  updateEvaluation,
  deleteEvaluation,
  getEvaluationById
};