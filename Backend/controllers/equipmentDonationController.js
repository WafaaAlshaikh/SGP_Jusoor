const {
  EquipmentDonation,
  EquipmentCategory,
  Institution,
  User,
  Manager,
  InstitutionEquipmentInventory,
  ChildEquipmentNeed,
  EquipmentAllocation,
  EquipmentItemHistory,
  EquipmentDonationCampaign
} = require('../model');
const sequelize = require('../config/db');
const { Op } = require('sequelize');
// const { sendNotification } = require('../utils/notifications');

// الحصول على فئات الأجهزة
exports.getEquipmentCategories = async (req, res) => {
  try {
    const categories = await EquipmentCategory.findAll({
      where: { is_active: true },
      attributes: ['category_id', 'name_ar', 'name_en', 'description', 'icon'],
      order: [['name_ar', 'ASC']]
    });

    return res.status(200).json({
      success: true,
      data: categories
    });
  } catch (error) {
    console.error('Error fetching equipment categories:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب فئات الأجهزة',
      error: error.message
    });
  }
};

// إنشاء طلب تبرع عيني
exports.createEquipmentDonation = async (req, res) => {
  try {
    const {
      institution_id,
      category_id,
      equipment_name,
      description,
      condition,
      estimated_value,
      delivery_type,
      preferred_date
    } = req.body;

    // التحقق من المدخلات الأساسية
    if (!institution_id || !equipment_name || !preferred_date) {
      return res.status(400).json({
        success: false,
        message: 'المؤسسة واسم الجهاز ووقت التسليم مطلوبة'
      });
    }

    // التحقق من المؤسسة
    const institution = await Institution.findByPk(institution_id, {
      attributes: ['institution_id', 'name', 'is_active']
    });

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة'
      });
    }

    if (!institution.is_active) {
      return res.status(400).json({
        success: false,
        message: 'المؤسسة غير نشطة حالياً'
      });
    }

    // تحديد بيانات المتبرع (من المستخدم المسجل دخول فقط)
    if (!req.user || !req.user.user_id) {
      return res.status(401).json({
        success: false,
        message: 'يجب تسجيل الدخول لتقديم طلب تبرع'
      });
    }

    const donorId = req.user.user_id;
    const user = await User.findByPk(donorId, {
      attributes: ['full_name', 'email', 'phone']
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    const contactInfo = {
      contact_person: user.full_name || null,
      contact_email: user.email || null,
      contact_phone: user.phone || null
    };

    // معالجة الصور إذا وجدت
    let images = null;
    const uploadedFiles = Array.isArray(req.files) ? req.files : (req.files && req.files.images ? req.files.images : null);
    if (uploadedFiles) {
      const imageFiles = Array.isArray(uploadedFiles) ? uploadedFiles : [uploadedFiles];
      images = imageFiles.map(file => ({
        url: `/uploads/equipment/${file.filename}`,
        filename: file.filename,
        size: file.size,
        mimetype: file.mimetype
      }));
    }

    const result = await sequelize.transaction(async (t) => {
      // إنشاء التبرع (بدون إلزام delivery_type/category/estimated_value) + موافقة مباشرة
      const equipmentDonation = await EquipmentDonation.create({
        donor_id: donorId,
        institution_id,
        category_id: category_id || null,
        equipment_name,
        description: description || null,
        condition: condition || 'used_good',
        estimated_value: estimated_value ? parseFloat(estimated_value) : null,
        delivery_type: delivery_type || 'pickup',
        preferred_date: new Date(preferred_date),
        ...contactInfo,
        images,
        status: 'approved'
      }, { transaction: t });

      // إضافة للمخزون مباشرة (بدون انتظار موافقة مدير/تسليم)
      const existingInventoryItem = await InstitutionEquipmentInventory.findOne({
        where: {
          institution_id,
          source_donation_id: equipmentDonation.equipment_donation_id,
        },
        transaction: t
      });

      const inventoryItem = existingInventoryItem || await InstitutionEquipmentInventory.create({
        institution_id,
        category_id: equipmentDonation.category_id || null,
        equipment_name: equipmentDonation.equipment_name,
        equipment_type: null,
        condition: equipmentDonation.condition,
        quantity_available: 1,
        quantity_reserved: 0,
        usage_type: 'available',
        internal_department: null,
        source_donation_id: equipmentDonation.equipment_donation_id,
        notes: equipmentDonation.description || null,
        created_at: new Date(),
        updated_at: new Date()
      }, { transaction: t });

      if (!existingInventoryItem) {
        await EquipmentItemHistory.create({
          institution_id,
          inventory_item_id: inventoryItem.inventory_item_id,
          event_type: 'inventory_added_from_donation',
          related_id: equipmentDonation.equipment_donation_id,
          actor_user_id: donorId,
          details: {
            equipment_name: equipmentDonation.equipment_name,
            donation_id: equipmentDonation.equipment_donation_id
          },
          created_at: new Date()
        }, { transaction: t });
      }

      // محاولة matching بسيطة مع احتياجات مفتوحة (اختياري)
      const needWhere = {
        institution_id,
        status: 'open'
      };
      if (equipmentDonation.category_id) {
        needWhere.category_id = equipmentDonation.category_id;
      }

      const normalizedDonationName = (equipmentDonation.equipment_name || '').trim();

      let need = null;
      if (normalizedDonationName.length > 0) {
        need = await ChildEquipmentNeed.findOne({
          where: {
            ...needWhere,
            [Op.or]: [
              { equipment_name: { [Op.like]: `%${normalizedDonationName}%` } },
              { equipment_type: { [Op.like]: `%${normalizedDonationName}%` } },
            ]
          },
          order: [['priority_score', 'DESC'], ['created_at', 'ASC']],
          transaction: t
        });
      }

      if (!need) {
        need = await ChildEquipmentNeed.findOne({
          where: needWhere,
          order: [['priority_score', 'DESC'], ['created_at', 'ASC']],
          transaction: t
        });
      }

      if (need) {
        if ((need.priority_score || 0) >= 70 && inventoryItem.quantity_available > 0) {
          await inventoryItem.update({
            quantity_available: Math.max(0, inventoryItem.quantity_available - 1),
            quantity_reserved: (inventoryItem.quantity_reserved || 0) + 1,
            usage_type: 'reserved',
            updated_at: new Date()
          }, { transaction: t });

          const allocation = await EquipmentAllocation.create({
            institution_id,
            inventory_item_id: inventoryItem.inventory_item_id,
            need_id: need.need_id,
            child_id: need.child_id,
            allocation_mode: 'auto',
            allocated_by_user_id: null,
            usage_type: 'child',
            status: 'pending_receipt',
            created_at: new Date(),
            updated_at: new Date()
          }, { transaction: t });

          await need.update({ status: 'allocated', updated_at: new Date() }, { transaction: t });

          const campaign = await EquipmentDonationCampaign.findOne({ where: { need_id: need.need_id }, transaction: t });
          if (campaign && !['fulfilled', 'closed'].includes(campaign.status)) {
            const nextFulfilled = Math.min(
              campaign.quantity_needed || 1,
              (campaign.quantity_fulfilled || 0) + 1
            );
            const nextStatus = nextFulfilled >= (campaign.quantity_needed || 1) ? 'fulfilled' : 'partially_fulfilled';
            await campaign.update({
              status: nextStatus,
              quantity_fulfilled: nextFulfilled,
              updated_at: new Date()
            }, { transaction: t });
          }

          await EquipmentItemHistory.create({
            institution_id,
            inventory_item_id: inventoryItem.inventory_item_id,
            event_type: 'auto_allocated',
            related_id: allocation.allocation_id,
            actor_user_id: null,
            details: { need_id: need.need_id, child_id: need.child_id, priority_score: need.priority_score },
            created_at: new Date()
          }, { transaction: t });
        } else {
          await need.update({ status: 'matched', updated_at: new Date() }, { transaction: t });

          await EquipmentItemHistory.create({
            institution_id,
            inventory_item_id: inventoryItem.inventory_item_id,
            event_type: 'match_suggested',
            related_id: need.need_id,
            actor_user_id: null,
            details: { need_id: need.need_id, priority_score: need.priority_score, child_id: need.child_id },
            created_at: new Date()
          }, { transaction: t });
        }
      }

      return { equipmentDonation, inventoryItem };
    });

    return res.status(201).json({
      success: true,
      message: 'تم تسجيل التبرع وإضافته لمخزون المؤسسة مباشرة',
      data: {
        equipment_donation_id: result.equipmentDonation.equipment_donation_id,
        status: result.equipmentDonation.status,
        next_steps: 'تم اعتماد التبرع مباشرة وسيتم التنسيق معك حسب وقت التسليم'
      }
    });

  } catch (error) {
    console.error('Error creating equipment donation:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في تقديم طلب التبرع',
      error: error.message
    });
  }
};

// دالة مساعدة لإرسال إشعار للمدير
async function sendNotificationToManager(institutionId, donation) {
  try {
    // البحث عن مدير المؤسسة
    const manager = await Manager.findOne({
      where: { 
        institution_id: institutionId,
        is_active: true 
      },
      include: [{
        model: User,
        attributes: ['user_id', 'full_name', 'email']
      }]
    });

    if (!manager || !manager.User) return;

    // إرسال إشعار
    const notificationData = {
      user_id: manager.manager_id,
      title: 'طلب تبرع عيني جديد',
      message: `تم تقديم طلب تبرع بجهاز: ${donation.equipment_name}`,
      type: 'equipment_donation',
      data: {
        donation_id: donation.equipment_donation_id,
        equipment_name: donation.equipment_name,
        condition: donation.condition,
        donor_name: donation.contact_person
      }
    };

    // await sendNotification(notificationData);

  } catch (error) {
    console.error('Error sending manager notification:', error);
  }
}

// الحصول على طلبات التبرع العيني للمدير
exports.getManagerEquipmentDonations = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    // التحقق من أن المستخدم مدير
    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId,
        is_active: true 
      },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية الوصول'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const { status, page = 1, limit = 10 } = req.query;
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 10;
    const offset = (pageNum - 1) * limitNum;

    // بناء where clause
    const whereClause = { institution_id: institutionId };
    if (status) {
      whereClause.status = status;
    }

    const donations = await EquipmentDonation.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: EquipmentCategory,
          attributes: ['category_id', 'name_ar', 'name_en'],
          as: 'category',
          required: false
        },
        {
          model: User,
          as: 'donor',
          attributes: ['user_id', 'full_name', 'profile_picture'],
          required: false
        }
      ],
      order: [['created_at', 'DESC']],
      offset,
      limit: limitNum
    });

    return res.status(200).json({
      success: true,
      data: {
        donations: donations.rows,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: donations.count,
          pages: Math.ceil(donations.count / limitNum)
        }
      }
    });

  } catch (error) {
    console.error('Error fetching equipment donations:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب طلبات التبرع',
      error: error.message
    });
  }
};

// تحديث حالة طلب التبرع (من قبل المدير)
exports.updateEquipmentDonationStatus = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { id } = req.params;
    const { status, admin_notes, rejection_reason, actual_delivery_date } = req.body;

    // التحقق من أن المستخدم مدير
    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId,
        is_active: true 
      },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية الوصول'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // البحث عن طلب التبرع
    const donation = await EquipmentDonation.findOne({
      where: {
        equipment_donation_id: id,
        institution_id: institutionId
      },
      include: [
        {
          model: User,
          as: 'donor',
          attributes: ['user_id', 'full_name', 'email']
        }
      ]
    });

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: 'طلب التبرع غير موجود'
      });
    }

    // التحقق من الحالة الجديدة
    const validStatuses = ['approved', 'rejected', 'scheduled', 'delivered', 'cancelled'];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'حالة غير صالحة'
      });
    }

    // البيانات للتحديث
    const updateData = {
      status: status || donation.status,
      admin_notes: admin_notes || donation.admin_notes,
      updated_at: new Date()
    };

    if (status === 'rejected' && rejection_reason) {
      updateData.rejection_reason = rejection_reason;
    }

    if (actual_delivery_date) {
      updateData.actual_delivery_date = new Date(actual_delivery_date);
    }

    // تحديث الطلب
    const oldStatus = donation.status;
    await donation.update(updateData);

    // عند التسليم: إنشاء عنصر بالمخزون + سجل History + محاولة matching مع الاحتياجات
    if (oldStatus !== 'delivered' && updateData.status === 'delivered') {
      const inventoryItem = await InstitutionEquipmentInventory.create({
        institution_id: institutionId,
        category_id: donation.category_id || null,
        equipment_name: donation.equipment_name,
        equipment_type: null,
        condition: donation.condition,
        quantity_available: 1,
        quantity_reserved: 0,
        usage_type: 'available',
        internal_department: null,
        source_donation_id: donation.equipment_donation_id,
        notes: donation.description || null,
        created_at: new Date(),
        updated_at: new Date()
      });

      await EquipmentItemHistory.create({
        institution_id: institutionId,
        inventory_item_id: inventoryItem.inventory_item_id,
        event_type: 'inventory_added_from_donation',
        related_id: donation.equipment_donation_id,
        actor_user_id: managerId,
        details: {
          equipment_name: donation.equipment_name,
          donation_id: donation.equipment_donation_id
        },
        created_at: new Date()
      });

      // Matching بسيط: نبحث عن أول احتياج مفتوح مناسب حسب category ثم أعلى priority
      const needWhere = {
        institution_id: institutionId,
        status: 'open'
      };
      if (donation.category_id) {
        needWhere.category_id = donation.category_id;
      }

      const need = await ChildEquipmentNeed.findOne({
        where: needWhere,
        order: [['priority_score', 'DESC'], ['created_at', 'ASC']]
      });

      if (need) {
        // إذا الأولوية عالية: تخصيص تلقائي
        if ((need.priority_score || 0) >= 70 && inventoryItem.quantity_available > 0) {
          await inventoryItem.update({
            quantity_available: Math.max(0, inventoryItem.quantity_available - 1),
            quantity_reserved: (inventoryItem.quantity_reserved || 0) + 1,
            usage_type: 'reserved',
            updated_at: new Date()
          });

          const allocation = await EquipmentAllocation.create({
            institution_id: institutionId,
            inventory_item_id: inventoryItem.inventory_item_id,
            need_id: need.need_id,
            child_id: need.child_id,
            allocation_mode: 'auto',
            allocated_by_user_id: null,
            usage_type: 'child',
            status: 'pending_receipt',
            created_at: new Date(),
            updated_at: new Date()
          });

          await need.update({ status: 'allocated', updated_at: new Date() });

          const campaign = await EquipmentDonationCampaign.findOne({ where: { need_id: need.need_id } });
          if (campaign && !['fulfilled', 'closed'].includes(campaign.status)) {
            await campaign.update({
              status: 'fulfilled',
              quantity_fulfilled: campaign.quantity_needed,
              updated_at: new Date()
            });
          }

          await EquipmentItemHistory.create({
            institution_id: institutionId,
            inventory_item_id: inventoryItem.inventory_item_id,
            event_type: 'auto_allocated',
            related_id: allocation.allocation_id,
            actor_user_id: null,
            details: { need_id: need.need_id, child_id: need.child_id, priority_score: need.priority_score },
            created_at: new Date()
          });
        } else {
          await need.update({ status: 'matched', updated_at: new Date() });
          await EquipmentItemHistory.create({
            institution_id: institutionId,
            inventory_item_id: inventoryItem.inventory_item_id,
            event_type: 'match_suggested',
            related_id: need.need_id,
            actor_user_id: managerId,
            details: { need_id: need.need_id, priority_score: need.priority_score },
            created_at: new Date()
          });
        }
      }
    }

    // إرسال إشعار للمتبرع إذا كان لديه حساب
    if (donation.donor_id && donation.donor) {
      await sendNotificationToDonor(donation, status);
    }

    return res.status(200).json({
      success: true,
      message: 'تم تحديث حالة الطلب بنجاح',
      data: donation
    });

  } catch (error) {
    console.error('Error updating equipment donation:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في تحديث حالة الطلب',
      error: error.message
    });
  }
};

// دالة مساعدة لإرسال إشعار للمتبرع
async function sendNotificationToDonor(donation, newStatus) {
  try {
    const statusMessages = {
      'approved': 'تمت الموافقة على طلب تبرعك',
      'rejected': 'تم رفض طلب تبرعك',
      'scheduled': 'تم جدولة موعد استلام تبرعك',
      'delivered': 'تم تسليم تبرعك بنجاح',
      'cancelled': 'تم إلغاء طلب تبرعك'
    };

    const notificationData = {
      user_id: donation.donor_id,
      title: 'تحديث حالة تبرعك',
      message: `${statusMessages[newStatus]}: ${donation.equipment_name}`,
      type: 'equipment_donation_update',
      data: {
        donation_id: donation.equipment_donation_id,
        status: newStatus,
        equipment_name: donation.equipment_name
      }
    };

    // await sendNotification(notificationData);

  } catch (error) {
    console.error('Error sending donor notification:', error);
  }
}

// الحصول على تفاصيل طلب تبرع معين
exports.getEquipmentDonationDetails = async (req, res) => {
  try {
    const { id } = req.params;
    let whereClause = { equipment_donation_id: id };

    // إذا كان المستخدم ليس مديراً، نتحقق من أنه هو صاحب الطلب
    if (req.user && req.user.role !== 'Manager') {
      whereClause.donor_id = req.user.user_id;
    }

    const donation = await EquipmentDonation.findOne({
      where: whereClause,
      include: [
        {
          model: Institution,
          attributes: ['institution_id', 'name', 'city', 'location']
        },
        {
          model: EquipmentCategory,
          attributes: ['category_id', 'name_ar', 'name_en'],
          required: false
        },
        {
          model: User,
          as: 'donor',
          attributes: ['user_id', 'full_name', 'profile_picture', 'email'],
          required: false
        }
      ]
    });

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: 'طلب التبرع غير موجود'
      });
    }

    return res.status(200).json({
      success: true,
      data: donation
    });

  } catch (error) {
    console.error('Error fetching donation details:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب تفاصيل الطلب',
      error: error.message
    });
  }
};

// إحصائيات التبرعات العينية للمدير
exports.getEquipmentDonationStats = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId,
        is_active: true 
      },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية الوصول'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // إحصائيات حسب الحالة
    const statusStats = await EquipmentDonation.findAll({
      where: { institution_id: institutionId },
      attributes: [
        'status',
        [sequelize.fn('COUNT', sequelize.col('equipment_donation_id')), 'count']
      ],
      group: ['status'],
      raw: true
    });

    // إحصائيات حسب حالة الجهاز
    const conditionStats = await EquipmentDonation.findAll({
      where: { institution_id: institutionId },
      attributes: [
        'condition',
        [sequelize.fn('COUNT', sequelize.col('equipment_donation_id')), 'count']
      ],
      group: ['condition'],
      raw: true
    });

    // إحصائيات زمنية (آخر 30 يوم)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const recentDonations = await EquipmentDonation.count({
      where: {
        institution_id: institutionId,
        created_at: { [Op.gte]: thirtyDaysAgo }
      }
    });

    // إجمالي التبرعات المقدمة
    const totalDonations = await EquipmentDonation.count({
      where: { institution_id: institutionId }
    });

    // التبرعات المسلمة
    const deliveredDonations = await EquipmentDonation.count({
      where: {
        institution_id: institutionId,
        status: 'delivered'
      }
    });

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          totalDonations,
          deliveredDonations,
          recentDonations30Days: recentDonations
        },
        byStatus: statusStats.reduce((acc, stat) => {
          acc[stat.status] = parseInt(stat.count);
          return acc;
        }, {}),
        byCondition: conditionStats.reduce((acc, stat) => {
          acc[stat.condition] = parseInt(stat.count);
          return acc;
        }, {})
      }
    });

  } catch (error) {
    console.error('Error fetching equipment donation stats:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب الإحصائيات',
      error: error.message
    });
  }
};

// الحصول على سجل التبرعات للمستخدم
exports.getUserEquipmentDonations = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { page = 1, limit = 10 } = req.query;
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 10;
    const offset = (pageNum - 1) * limitNum;

    const donations = await EquipmentDonation.findAndCountAll({
      where: { donor_id: userId },
      include: [
        {
          model: Institution,
          attributes: ['institution_id', 'name', 'city']
        },
        {
          model: EquipmentCategory,
          attributes: ['category_id', 'name_ar', 'name_en'],
          required: false
        }
      ],
      order: [['created_at', 'DESC']],
      offset,
      limit: limitNum
    });

    return res.status(200).json({
      success: true,
      data: {
        donations: donations.rows,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: donations.count,
          pages: Math.ceil(donations.count / limitNum)
        }
      }
    });

  } catch (error) {
    console.error('Error fetching user equipment donations:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب سجل تبرعاتك',
      error: error.message
    });
  }
};