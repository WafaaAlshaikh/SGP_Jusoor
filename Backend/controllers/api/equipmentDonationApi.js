const { EquipmentDonation, EquipmentCategory, Institution, EquipmentDonationCampaign } = require('../../model');
const { Op } = require('sequelize');

// API للحصول على المؤسسات التي تقبل تبرعات عينية
exports.getInstitutionsForEquipmentDonation = async (req, res) => {
  try {
    const institutions = await Institution.findAll({
      where: { 
        is_active: true,
        approval_status: 'Approved'
      },
      attributes: ['institution_id', 'name', 'city', 'location', 'contact_phone', 'contact_email'],
      order: [['name', 'ASC']]
    });

    return res.status(200).json({
      success: true,
      data: institutions
    });
  } catch (error) {
    console.error('Error fetching institutions:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب المؤسسات',
      error: error.message
    });
  }
};

// API للحصول على حملات تبرع المعدات لمؤسسة (لا تحتاج مصادقة)
exports.getInstitutionEquipmentCampaigns = async (req, res) => {
  try {
    const institutionId = parseInt(req.params.institutionId, 10);

    if (!institutionId || !Number.isFinite(institutionId)) {
      return res.status(400).json({
        success: false,
        message: 'Valid institution id is required'
      });
    }

    const institution = await Institution.findByPk(institutionId, {
      attributes: ['institution_id', 'name', 'city', 'is_active']
    });

    if (!institution) {
      return res.status(404).json({ success: false, message: 'المؤسسة غير موجودة' });
    }

    if (!institution.is_active) {
      return res.status(400).json({ success: false, message: 'المؤسسة غير نشطة حالياً' });
    }

    const campaigns = await EquipmentDonationCampaign.findAll({
      where: {
        institution_id: institutionId,
        status: { [Op.in]: ['open', 'partially_fulfilled'] }
      },
      order: [['priority_score_snapshot', 'DESC'], ['created_at', 'ASC']]
    });

    return res.status(200).json({
      success: true,
      data: campaigns
    });
  } catch (error) {
    console.error('Error fetching institution equipment campaigns:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب حملات المعدات',
      error: error.message
    });
  }
};

// API للحصول على تفاصيل حملة معدات (لا تحتاج مصادقة)
exports.getEquipmentCampaignDetails = async (req, res) => {
  try {
    const campaignId = parseInt(req.params.campaignId, 10);

    if (!campaignId || !Number.isFinite(campaignId)) {
      return res.status(400).json({
        success: false,
        message: 'Valid campaign id is required'
      });
    }

    const campaign = await EquipmentDonationCampaign.findByPk(campaignId);
    if (!campaign) {
      return res.status(404).json({ success: false, message: 'الحملة غير موجودة' });
    }

    return res.status(200).json({ success: true, data: campaign });
  } catch (error) {
    console.error('Error fetching equipment campaign details:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب تفاصيل الحملة',
      error: error.message
    });
  }
};

// API لإنشاء تبرع عيني بدون مصادقة
exports.createAnonymousEquipmentDonation = async (req, res) => {
  try {
    const {
      institution_id,
      category_id,
      equipment_name,
      description,
      condition,
      estimated_value,
      delivery_type,
      preferred_date,
      contact_person,
      contact_phone,
      contact_email
    } = req.body;

    // التحقق من البيانات المطلوبة
    if (!institution_id || !equipment_name || !contact_person || !contact_phone) {
      return res.status(400).json({
        success: false,
        message: 'البيانات المطلوبة: المؤسسة، اسم الجهاز، اسم الشخص، ورقم الهاتف'
      });
    }

    // إنشاء التبرع
    const donation = await EquipmentDonation.create({
      donor_id: null, // متبرع مجهول
      institution_id,
      category_id,
      equipment_name,
      description,
      condition: condition || 'used_good',
      estimated_value: estimated_value ? parseFloat(estimated_value) : null,
      delivery_type: delivery_type || 'pickup',
      preferred_date: preferred_date ? new Date(preferred_date) : null,
      contact_person,
      contact_phone,
      contact_email,
      status: 'pending'
    });

    return res.status(201).json({
      success: true,
      message: 'تم تقديم طلب التبرع بنجاح',
      data: {
        donation_id: donation.equipment_donation_id,
        tracking_code: `EQ${donation.equipment_donation_id.toString().padStart(6, '0')}`,
        status: donation.status
      }
    });

  } catch (error) {
    console.error('Error creating anonymous equipment donation:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في تقديم طلب التبرع',
      error: error.message
    });
  }
};

// API للتحقق من حالة التبرع
exports.checkEquipmentDonationStatus = async (req, res) => {
  try {
    const { donation_id, contact_phone } = req.query;

    if (!donation_id || !contact_phone) {
      return res.status(400).json({
        success: false,
        message: 'معرف التبرع ورقم الهاتف مطلوبان'
      });
    }

    const donation = await EquipmentDonation.findOne({
      where: {
        equipment_donation_id: donation_id,
        contact_phone
      },
      include: [
        {
          model: Institution,
          as: 'institution',
          attributes: ['name', 'city']
        }
      ]
    });

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: 'لم يتم العثور على التبرع. تأكد من البيانات المدخلة'
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        donation_id: donation.equipment_donation_id,
        equipment_name: donation.equipment_name,
        status: donation.status,
        institution_name: donation.Institution?.name,
        created_at: donation.created_at,
        tracking_code: `EQ${donation.equipment_donation_id.toString().padStart(6, '0')}`
      }
    });

  } catch (error) {
    console.error('Error checking donation status:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في التحقق من حالة التبرع',
      error: error.message
    });
  }
};