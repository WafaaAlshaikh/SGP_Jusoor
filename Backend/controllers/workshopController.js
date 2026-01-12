const ParentWorkshop = require('../model/ParentWorkshop');
const ParentWorkshopRegistration = require('../model/ParentWorkshopRegistration');
const Manager = require('../model/Manager');
const Parent = require('../model/Parent');
const Child = require('../model/Child');
const ChildRegistrationRequest = require('../model/ChildRegistrationRequest');
const { Op } = require('sequelize');

// ============ Manager side ============

exports.createWorkshop = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const {
      title,
      description,
      mode,
      online_link,
      location_address,
      date,
      start_time,
      end_time,
      max_participants,
      status
    } = req.body;

    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'المستخدم غير مصرح له'
      });
    }

    const workshop = await ParentWorkshop.create({
      institution_id: manager.institution_id,
      title,
      description,
      mode,
      online_link,
      location_address,
      date,
      start_time,
      end_time,
      max_participants,
      status
    });

    res.status(201).json({
      success: true,
      message: 'تم إنشاء ورشة العمل بنجاح',
      data: workshop
    });
  } catch (error) {
    console.error('Error creating workshop:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في إنشاء ورشة العمل',
      error: error.message
    });
  }
};

exports.getManagerWorkshops = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'المستخدم غير مصرح له'
      });
    }

    const workshops = await ParentWorkshop.findAll({
      where: { institution_id: manager.institution_id },
      order: [['date', 'ASC'], ['start_time', 'ASC']]
    });

    res.status(200).json({
      success: true,
      data: workshops
    });
  } catch (error) {
    console.error('Error fetching manager workshops:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في جلب ورش العمل',
      error: error.message
    });
  }
};

// ============ Parent side ============

exports.getParentWorkshops = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const parent = await Parent.findOne({ where: { parent_id: parentId } });
    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found'
      });
    }

    const children = await Child.findAll({
      where: {
        parent_id: parentId,
        current_institution_id: { [Op.ne]: null }
      },
      attributes: ['current_institution_id'],
      raw: true
    });

    const currentInstitutionIds = children
      .map(c => c.current_institution_id)
      .filter(id => !!id);

    const approvedRequests = await ChildRegistrationRequest.findAll({
      where: {
        requested_by_parent_id: parentId,
        status: 'Approved'
      },
      attributes: ['institution_id'],
      raw: true
    });

    const approvedInstitutionIds = approvedRequests
      .map(r => r.institution_id)
      .filter(id => !!id);

    const allInstitutionIds = Array.from(
      new Set([...currentInstitutionIds, ...approvedInstitutionIds])
    );

    if (allInstitutionIds.length === 0) {
      return res.status(200).json({
        success: true,
        data: []
      });
    }

    const workshops = await ParentWorkshop.findAll({
      where: {
        institution_id: { [Op.in]: allInstitutionIds },
        status: 'published'
      },
      order: [['date', 'ASC'], ['start_time', 'ASC']]
    });

    res.status(200).json({
      success: true,
      data: workshops
    });
  } catch (error) {
    console.error('Error fetching parent workshops:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في جلب ورش العمل',
      error: error.message
    });
  }
};

exports.registerForWorkshop = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { workshop_id } = req.params;

    const parent = await Parent.findOne({ where: { parent_id: parentId } });
    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found'
      });
    }

    const workshop = await ParentWorkshop.findByPk(workshop_id);
    if (!workshop || workshop.status !== 'published') {
      return res.status(404).json({
        success: false,
        message: 'ورشة العمل غير موجودة أو غير متاحة'
      });
    }

    const existing = await ParentWorkshopRegistration.findOne({
      where: { workshop_id, parent_id: parentId }
    });
    if (existing) {
      return res.status(400).json({
        success: false,
        message: 'تم التسجيل مسبقاً في هذه الورشة'
      });
    }

    const registeredCount = await ParentWorkshopRegistration.count({
      where: { workshop_id, status: 'registered' }
    });

    const status = registeredCount < workshop.max_participants ? 'registered' : 'waitlist';

    const registration = await ParentWorkshopRegistration.create({
      workshop_id,
      parent_id: parentId,
      status
    });

    res.status(201).json({
      success: true,
      message: status === 'registered'
        ? 'تم التسجيل في الورشة بنجاح'
        : 'تمت إضافتك إلى قائمة الانتظار لهذه الورشة',
      data: registration
    });
  } catch (error) {
    console.error('Error registering for workshop:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في التسجيل في الورشة',
      error: error.message
    });
  }
};
