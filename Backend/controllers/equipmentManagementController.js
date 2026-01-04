const {
  InstitutionEquipmentInventory,
  ChildEquipmentNeed,
  EquipmentAllocation,
  EquipmentItemHistory,
  EquipmentDonation,
  EquipmentCategory,
  Evaluation,
  Child,
  Parent,
  Manager,
  User,
  EquipmentDonationCampaign
} = require('../model');

const AIEquipmentNeedsService = require('../services/aiEquipmentNeedsService');

const { Op, Sequelize } = require('sequelize');

async function logHistory({ institution_id, inventory_item_id, event_type, related_id = null, actor_user_id = null, details = null }) {
  await EquipmentItemHistory.create({
    institution_id,
    inventory_item_id,
    event_type,
    related_id,
    actor_user_id,
    details,
    created_at: new Date()
  });
}

async function calculateNeedPriorityScore({ childId, institutionId, severity }) {
  const child = await Child.findByPk(childId, {
    include: [{
      model: Parent,
      attributes: ['parent_id', 'financial_score', 'financial_tier']
    }]
  });

  let financialScore = 0;
  if (child?.Parent) {
    const tier = child.Parent.financial_tier;
    if (tier === 'tier_1_critical') financialScore = 100;
    else if (tier === 'tier_2_high') financialScore = 80;
    else if (tier === 'tier_3_medium') financialScore = 60;
    else if (tier === 'tier_4_low') financialScore = 30;
    else financialScore = 0;
  }

  let medicalScore = 50;
  if (severity === 'high') medicalScore = 90;
  else if (severity === 'medium') medicalScore = 60;
  else medicalScore = 30;

  const score = Math.round((medicalScore * 0.6) + (financialScore * 0.4));
  return Math.max(0, Math.min(100, score));
}

async function findMatchingInventoryItem({ institutionId, categoryId, equipmentName, equipmentType }) {
  const where = {
    institution_id: institutionId,
    quantity_available: { [Op.gt]: 0 },
    usage_type: { [Op.in]: ['available', 'reserved'] }
  };

  if (categoryId) where.category_id = categoryId;

  const candidates = await InstitutionEquipmentInventory.findAll({
    where,
    order: [['created_at', 'ASC']]
  });

  if (!candidates.length) return null;

  const normalizedNeedName = (equipmentName || '').toLowerCase().trim();
  const normalizedNeedType = (equipmentType || '').toLowerCase().trim();

  const exact = candidates.find(c => (c.equipment_type || '').toLowerCase().trim() === normalizedNeedType && normalizedNeedType);
  if (exact) return exact;

  const nameMatch = candidates.find(c => (c.equipment_name || '').toLowerCase().includes(normalizedNeedName) && normalizedNeedName);
  if (nameMatch) return nameMatch;

  return candidates[0];
}

async function tryAutoMatchForNeed(need) {
  const inventoryItem = await findMatchingInventoryItem({
    institutionId: need.institution_id,
    categoryId: need.category_id,
    equipmentName: need.equipment_name,
    equipmentType: need.equipment_type
  });

  if (!inventoryItem) return { matched: false };

  if (need.priority_score < 70) {
    await need.update({ status: 'matched', updated_at: new Date() });
    await logHistory({
      institution_id: need.institution_id,
      inventory_item_id: inventoryItem.inventory_item_id,
      event_type: 'match_suggested',
      related_id: need.need_id,
      details: { need_id: need.need_id, priority_score: need.priority_score }
    });

    return { matched: true, autoAllocated: false, inventoryItemId: inventoryItem.inventory_item_id };
  }

  await inventoryItem.update({
    quantity_available: Math.max(0, inventoryItem.quantity_available - 1),
    quantity_reserved: (inventoryItem.quantity_reserved || 0) + 1,
    usage_type: 'reserved',
    updated_at: new Date()
  });

  const allocation = await EquipmentAllocation.create({
    institution_id: need.institution_id,
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

  await logHistory({
    institution_id: need.institution_id,
    inventory_item_id: inventoryItem.inventory_item_id,
    event_type: 'auto_allocated',
    related_id: allocation.allocation_id,
    details: { need_id: need.need_id, child_id: need.child_id, priority_score: need.priority_score }
  });

  return { matched: true, autoAllocated: true, allocationId: allocation.allocation_id, inventoryItemId: inventoryItem.inventory_item_id };
}

async function ensureEquipmentDonationCampaignForNeed(need) {
  if (!need || !need.need_id) return null;

  const [campaign] = await EquipmentDonationCampaign.findOrCreate({
    where: { need_id: need.need_id },
    defaults: {
      institution_id: need.institution_id,
      need_id: need.need_id,
      child_id: need.child_id,
      category_id: need.category_id || null,
      equipment_type: need.equipment_type || null,
      equipment_name: need.equipment_name,
      quantity_needed: need.quantity_needed || 1,
      quantity_fulfilled: 0,
      status: 'open',
      priority_score_snapshot: need.priority_score || 0,
      created_at: new Date(),
      updated_at: new Date()
    }
  });

  // Keep it in sync if the need was edited/created with different details
  await campaign.update({
    institution_id: need.institution_id,
    child_id: need.child_id,
    category_id: need.category_id || null,
    equipment_type: need.equipment_type || null,
    equipment_name: need.equipment_name,
    quantity_needed: need.quantity_needed || 1,
    priority_score_snapshot: need.priority_score || 0,
    status: ['fulfilled', 'closed'].includes(campaign.status) ? campaign.status : 'open',
    updated_at: new Date()
  });

  return campaign;
}

async function closeEquipmentCampaignForNeedIfAny(needId) {
  if (!needId) return;
  const campaign = await EquipmentDonationCampaign.findOne({ where: { need_id: needId } });
  if (!campaign) return;

  if (!['fulfilled', 'closed'].includes(campaign.status)) {
    await campaign.update({
      status: 'fulfilled',
      quantity_fulfilled: campaign.quantity_needed,
      updated_at: new Date()
    });
  }
}

exports.createNeedBySpecialist = async (req, res) => {
  try {
    const specialistUserId = req.user.user_id;
    const { child_id, institution_id, category_id, equipment_name, equipment_type, quantity_needed, severity, reason, created_from_evaluation_id } = req.body;

    if (!child_id || !equipment_name) {
      return res.status(400).json({ success: false, message: 'child_id و equipment_name مطلوبة' });
    }

    let resolvedInstitutionId = institution_id;
    if (!resolvedInstitutionId) {
      const child = await Child.findByPk(child_id);
      resolvedInstitutionId = child?.current_institution_id || null;
    }

    if (!resolvedInstitutionId) {
      return res.status(400).json({ success: false, message: 'institution_id غير متوفر (لا يوجد current_institution_id للطفل)' });
    }

    const priority_score = await calculateNeedPriorityScore({ childId: child_id, institutionId: resolvedInstitutionId, severity });

    const need = await ChildEquipmentNeed.create({
      institution_id: resolvedInstitutionId,
      child_id,
      category_id: category_id || null,
      equipment_type: equipment_type || null,
      equipment_name,
      quantity_needed: quantity_needed ? parseInt(quantity_needed) : 1,
      severity: severity || 'medium',
      reason: reason || null,
      source: 'specialist_manual',
      created_from_evaluation_id: created_from_evaluation_id || null,
      priority_score,
      status: 'open',
      created_at: new Date(),
      updated_at: new Date()
    });

    const matchResult = await tryAutoMatchForNeed(need);

    if (!matchResult?.matched) {
      await ensureEquipmentDonationCampaignForNeed(need);
    } else if (matchResult?.autoAllocated) {
      await closeEquipmentCampaignForNeedIfAny(need.need_id);
    }

    return res.status(201).json({
      success: true,
      data: { need, match: matchResult }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في إنشاء الاحتياج', error: error.message });
  }
};

exports.getManagerEquipmentCampaignStats = async (req, res) => {
  try {
    const institutionId = req.institution_id;
    const {
      status,
      category_id,
      child_id,
      need_id,
      startDate,
      endDate,
    } = req.query;

    const where = { institution_id: institutionId };
    if (status && String(status).trim()) where.status = String(status).trim();
    if (category_id && Number.isFinite(parseInt(category_id, 10))) where.category_id = parseInt(category_id, 10);
    if (child_id && Number.isFinite(parseInt(child_id, 10))) where.child_id = parseInt(child_id, 10);
    if (need_id && Number.isFinite(parseInt(need_id, 10))) where.need_id = parseInt(need_id, 10);
    if (startDate || endDate) {
      where.created_at = {};
      if (startDate) where.created_at[Op.gte] = new Date(startDate);
      if (endDate) where.created_at[Op.lte] = new Date(endDate);
    }

    const [
      totals,
      byStatus,
      byCategory,
      byChild,
      byNeed,
      recent,
    ] = await Promise.all([
      EquipmentDonationCampaign.findOne({
        where,
        attributes: [
          [Sequelize.fn('COUNT', Sequelize.col('campaign_id')), 'campaigns_count'],
          [Sequelize.fn('SUM', Sequelize.col('quantity_needed')), 'quantity_needed_total'],
          [Sequelize.fn('SUM', Sequelize.col('quantity_fulfilled')), 'quantity_fulfilled_total'],
        ],
        raw: true,
      }),
      EquipmentDonationCampaign.findAll({
        where,
        attributes: [
          'status',
          [Sequelize.fn('COUNT', Sequelize.col('campaign_id')), 'count'],
        ],
        group: ['status'],
        raw: true,
      }),
      EquipmentDonationCampaign.findAll({
        where: { ...where, category_id: { [Op.ne]: null } },
        attributes: [
          'category_id',
          [Sequelize.fn('COUNT', Sequelize.col('campaign_id')), 'count'],
          [Sequelize.fn('SUM', Sequelize.col('quantity_needed')), 'needed'],
          [Sequelize.fn('SUM', Sequelize.col('quantity_fulfilled')), 'fulfilled'],
        ],
        group: ['category_id'],
        raw: true,
      }),
      EquipmentDonationCampaign.findAll({
        where: { ...where, child_id: { [Op.ne]: null } },
        attributes: [
          'child_id',
          [Sequelize.fn('COUNT', Sequelize.col('campaign_id')), 'count'],
          [Sequelize.fn('SUM', Sequelize.col('quantity_needed')), 'needed'],
          [Sequelize.fn('SUM', Sequelize.col('quantity_fulfilled')), 'fulfilled'],
        ],
        group: ['child_id'],
        order: [[Sequelize.literal('needed'), 'DESC']],
        limit: 20,
        raw: true,
      }),
      EquipmentDonationCampaign.findAll({
        where: { ...where, need_id: { [Op.ne]: null } },
        attributes: [
          'need_id',
          [Sequelize.fn('COUNT', Sequelize.col('campaign_id')), 'count'],
          [Sequelize.fn('SUM', Sequelize.col('quantity_needed')), 'needed'],
          [Sequelize.fn('SUM', Sequelize.col('quantity_fulfilled')), 'fulfilled'],
        ],
        group: ['need_id'],
        order: [[Sequelize.literal('needed'), 'DESC']],
        limit: 20,
        raw: true,
      }),
      EquipmentDonationCampaign.findAll({
        where,
        attributes: {
          include: [[Sequelize.literal(`
  CASE 
    WHEN EquipmentDonationCampaign.quantity_needed > 0 
    THEN 
      (EquipmentDonationCampaign.quantity_fulfilled / EquipmentDonationCampaign.quantity_needed) * 100 
    ELSE 0 
  END
`)
, 'fulfillment_percentage']],
        },
        include: [
          { model: EquipmentCategory, as: 'category', attributes: ['category_id', 'name_ar', 'name_en'], required: false },
          { model: Child, as: 'child', attributes: ['child_id', 'full_name'], required: false },
          { model: ChildEquipmentNeed, as: 'need', attributes: ['need_id', 'equipment_name', 'equipment_type', 'severity', 'priority_score', 'status'], required: false },
        ],
        order: [['created_at', 'DESC']],
        limit: 10,
      }),
    ]);

    const quantityNeededTotal = parseInt(totals?.quantity_needed_total || 0, 10) || 0;
    const quantityFulfilledTotal = parseInt(totals?.quantity_fulfilled_total || 0, 10) || 0;
    const fulfillmentRate = quantityNeededTotal > 0
      ? parseFloat(((quantityFulfilledTotal / quantityNeededTotal) * 100).toFixed(1))
      : 0;

    const categoryIds = [...new Set((byCategory || []).map((x) => x.category_id).filter((x) => !!x))];
    const childIds = [...new Set((byChild || []).map((x) => x.child_id).filter((x) => !!x))];
    const needIds = [...new Set((byNeed || []).map((x) => x.need_id).filter((x) => !!x))];

    const [categories, children, needs] = await Promise.all([
      categoryIds.length
        ? EquipmentCategory.findAll({ where: { category_id: { [Op.in]: categoryIds } }, attributes: ['category_id', 'name_ar', 'name_en'], raw: true })
        : [],
      childIds.length
        ? Child.findAll({ where: { child_id: { [Op.in]: childIds } }, attributes: ['child_id', 'full_name'], raw: true })
        : [],
      needIds.length
        ? ChildEquipmentNeed.findAll({ where: { need_id: { [Op.in]: needIds } }, attributes: ['need_id', 'equipment_name', 'equipment_type', 'severity', 'priority_score', 'status', 'child_id'], raw: true })
        : [],
    ]);

    const categoryById = (categories || []).reduce((acc, c) => {
      acc[c.category_id] = c;
      return acc;
    }, {});
    const childById = (children || []).reduce((acc, c) => {
      acc[c.child_id] = c;
      return acc;
    }, {});
    const needById = (needs || []).reduce((acc, n) => {
      acc[n.need_id] = n;
      return acc;
    }, {});

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          campaigns_count: parseInt(totals?.campaigns_count || 0, 10) || 0,
          quantity_needed_total: quantityNeededTotal,
          quantity_fulfilled_total: quantityFulfilledTotal,
          fulfillment_rate: fulfillmentRate,
        },
        byStatus: (byStatus || []).reduce((acc, r) => {
          acc[r.status] = parseInt(r.count || 0, 10) || 0;
          return acc;
        }, {}),
        byCategory: (byCategory || []).map((r) => {
          const needed = parseInt(r.needed || 0, 10) || 0;
          const fulfilled = parseInt(r.fulfilled || 0, 10) || 0;
          return {
            category_id: r.category_id,
            category: categoryById[r.category_id] || null,
            campaigns_count: parseInt(r.count || 0, 10) || 0,
            quantity_needed: needed,
            quantity_fulfilled: fulfilled,
            fulfillment_rate: needed > 0 ? parseFloat(((fulfilled / needed) * 100).toFixed(1)) : 0,
          };
        }),
        byChild: (byChild || []).map((r) => {
          const needed = parseInt(r.needed || 0, 10) || 0;
          const fulfilled = parseInt(r.fulfilled || 0, 10) || 0;
          return {
            child_id: r.child_id,
            child: childById[r.child_id] || null,
            campaigns_count: parseInt(r.count || 0, 10) || 0,
            quantity_needed: needed,
            quantity_fulfilled: fulfilled,
            fulfillment_rate: needed > 0 ? parseFloat(((fulfilled / needed) * 100).toFixed(1)) : 0,
          };
        }),
        byNeed: (byNeed || []).map((r) => {
          const needed = parseInt(r.needed || 0, 10) || 0;
          const fulfilled = parseInt(r.fulfilled || 0, 10) || 0;
          return {
            need_id: r.need_id,
            need: needById[r.need_id] || null,
            campaigns_count: parseInt(r.count || 0, 10) || 0,
            quantity_needed: needed,
            quantity_fulfilled: fulfilled,
            fulfillment_rate: needed > 0 ? parseFloat(((fulfilled / needed) * 100).toFixed(1)) : 0,
          };
        }),
        recentCampaigns: recent,
      },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في جلب تحليلات حملات المعدات', error: error.message });
  }
};

exports.getManagerEquipmentCampaigns = async (req, res) => {
  try {
    const institutionId = req.institution_id;
    const {
      status,
      category_id,
      child_id,
      need_id,
      search,
      minFulfillment,
      maxFulfillment,
      minPriority,
      maxPriority,
      startDate,
      endDate,
      page = 1,
      limit = 20,
    } = req.query;
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 20;
    const offset = (pageNum - 1) * limitNum;

    const where = { institution_id: institutionId };
    if (status && String(status).trim()) where.status = String(status).trim();
    if (category_id && Number.isFinite(parseInt(category_id, 10))) where.category_id = parseInt(category_id, 10);
    if (child_id && Number.isFinite(parseInt(child_id, 10))) where.child_id = parseInt(child_id, 10);
    if (need_id && Number.isFinite(parseInt(need_id, 10))) where.need_id = parseInt(need_id, 10);
    if (minPriority && Number.isFinite(parseInt(minPriority, 10))) {
      where.priority_score_snapshot = {
        ...(where.priority_score_snapshot || {}),
        [Op.gte]: parseInt(minPriority, 10),
      };
    }
    if (maxPriority && Number.isFinite(parseInt(maxPriority, 10))) {
      where.priority_score_snapshot = {
        ...(where.priority_score_snapshot || {}),
        [Op.lte]: parseInt(maxPriority, 10),
      };
    }
    if (startDate || endDate) {
      where.created_at = {};
      if (startDate) where.created_at[Op.gte] = new Date(startDate);
      if (endDate) where.created_at[Op.lte] = new Date(endDate);
    }
    if (search && String(search).trim()) {
      const q = String(search).trim();
      where[Op.or] = [
        { equipment_name: { [Op.like]: `%${q}%` } },
        { equipment_type: { [Op.like]: `%${q}%` } },
      ];
    }

    const minF = minFulfillment !== undefined ? parseFloat(minFulfillment) : null;
    const maxF = maxFulfillment !== undefined ? parseFloat(maxFulfillment) : null;
    const hasFulfillmentFilter =
      (minF !== null && Number.isFinite(minF)) || (maxF !== null && Number.isFinite(maxF));

    const fulfillmentExpr = Sequelize.literal(`
  CASE 
    WHEN EquipmentDonationCampaign.quantity_needed > 0 
    THEN 
      (EquipmentDonationCampaign.quantity_fulfilled / EquipmentDonationCampaign.quantity_needed) * 100 
    ELSE 0 
  END
`);


    const campaigns = await EquipmentDonationCampaign.findAndCountAll({
      where,
      attributes: {
        include: [[fulfillmentExpr, 'fulfillment_percentage']],
      },
      include: [
        {
          model: EquipmentCategory,
          as: 'category',
          attributes: ['category_id', 'name_ar', 'name_en'],
          required: false,
        },
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'full_name'],
          required: false,
        },
        {
          model: ChildEquipmentNeed,
          as: 'need',
          attributes: ['need_id', 'equipment_name', 'equipment_type', 'severity', 'priority_score', 'status'],
          required: false,
        },
      ],
      having: hasFulfillmentFilter
        ? Sequelize.where(
            fulfillmentExpr,
            {
              ...(minF !== null && Number.isFinite(minF) ? { [Op.gte]: minF } : {}),
              ...(maxF !== null && Number.isFinite(maxF) ? { [Op.lte]: maxF } : {}),
            },
          )
        : undefined,
      order: [['status', 'ASC'], ['priority_score_snapshot', 'DESC'], ['created_at', 'ASC']],
      offset,
      limit: limitNum,
      subQuery: false,
    });

    const categories = await EquipmentCategory.findAll({
      where: { is_active: true },
      attributes: ['category_id', 'name_ar', 'name_en'],
      order: [['name_ar', 'ASC']],
    });

    return res.status(200).json({
      success: true,
      data: {
        campaigns: campaigns.rows,
        filters: {
          statuses: ['open', 'partially_fulfilled', 'fulfilled', 'closed'],
          categories,
        },
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: campaigns.count,
          pages: Math.ceil(campaigns.count / limitNum)
        }
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في جلب حملات المعدات', error: error.message });
  }
};

exports.updateManagerEquipmentCampaign = async (req, res) => {
  try {
    const institutionId = req.institution_id;
    const managerUserId = req.user.user_id;
    const { campaign_id } = req.params;
    const { status, quantity_fulfilled } = req.body;

    const campaign = await EquipmentDonationCampaign.findOne({
      where: {
        campaign_id,
        institution_id: institutionId
      }
    });

    if (!campaign) {
      return res.status(404).json({ success: false, message: 'الحملة غير موجودة' });
    }

    const update = { updated_at: new Date() };

    if (status) {
      const allowed = ['open', 'partially_fulfilled', 'fulfilled', 'closed'];
      if (!allowed.includes(status)) {
        return res.status(400).json({ success: false, message: 'status غير صالحة' });
      }
      update.status = status;
    }

    if (quantity_fulfilled !== undefined && quantity_fulfilled !== null) {
      const q = parseInt(quantity_fulfilled, 10);
      if (!Number.isFinite(q) || q < 0) {
        return res.status(400).json({ success: false, message: 'quantity_fulfilled غير صالحة' });
      }
      update.quantity_fulfilled = Math.min(q, campaign.quantity_needed);

      if (!update.status) {
        if (update.quantity_fulfilled >= campaign.quantity_needed) update.status = 'fulfilled';
        else if (update.quantity_fulfilled > 0) update.status = 'partially_fulfilled';
      }
    }

    await campaign.update(update);

    // If this campaign is tied to a need and marked fulfilled, update the need status as well (best-effort)
    if (campaign.need_id && update.status === 'fulfilled') {
      const need = await ChildEquipmentNeed.findOne({ where: { need_id: campaign.need_id } });
      if (need && !['allocated', 'delivered', 'cancelled'].includes(need.status)) {
        await need.update({ status: 'matched', updated_at: new Date() });
      }
    }

    return res.status(200).json({ success: true, data: campaign });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في تحديث حملة المعدات', error: error.message });
  }
};

exports.suggestNeedsFromEvaluationForSpecialist = async (req, res) => {
  try {
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({ success: false, message: 'Access denied. Only specialists can request AI suggestions' });
    }

    const { evaluation_id, notes } = req.body;

    let evaluationNotes = notes;
    let evaluation = null;

    if (!evaluationNotes && evaluation_id) {
      evaluation = await Evaluation.findByPk(parseInt(evaluation_id));
      evaluationNotes = evaluation?.notes || '';
    }

    if (!evaluationNotes || !evaluationNotes.trim()) {
      return res.status(400).json({ success: false, message: 'notes أو evaluation_id مطلوبة' });
    }

    const suggestions = await AIEquipmentNeedsService.suggestEquipmentNeeds(evaluationNotes);

    return res.status(200).json({
      success: true,
      data: {
        suggestions,
        evaluation_id: evaluation_id ? parseInt(evaluation_id) : null
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في توليد اقتراحات AI', error: error.message });
  }
};

exports.confirmAISuggestedNeeds = async (req, res) => {
  try {
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({ success: false, message: 'Access denied. Only specialists can confirm AI suggestions' });
    }

    const { child_id, institution_id, created_from_evaluation_id, items } = req.body;

    if (!child_id) {
      return res.status(400).json({ success: false, message: 'child_id مطلوبة' });
    }

    let resolvedInstitutionId = institution_id;
    if (!resolvedInstitutionId) {
      const child = await Child.findByPk(child_id);
      resolvedInstitutionId = child?.current_institution_id || null;
    }

    if (!resolvedInstitutionId) {
      return res.status(400).json({ success: false, message: 'institution_id غير متوفر (لا يوجد current_institution_id للطفل)' });
    }

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'items مطلوبة (array) وبحد أدنى عنصر واحد' });
    }

    const created = [];
    const matches = [];

    for (const it of items) {
      if (!it || !it.equipment_name) continue;

      const severity = ['low', 'medium', 'high'].includes(String(it.severity)) ? String(it.severity) : 'medium';
      const priority_score = await calculateNeedPriorityScore({ childId: child_id, institutionId: resolvedInstitutionId, severity });

      const need = await ChildEquipmentNeed.create({
        institution_id: resolvedInstitutionId,
        child_id,
        category_id: it.category_id || null,
        equipment_type: it.equipment_type || null,
        equipment_name: it.equipment_name,
        quantity_needed: it.quantity_needed ? parseInt(it.quantity_needed) : 1,
        severity,
        reason: it.reason || null,
        source: 'ai',
        created_from_evaluation_id: created_from_evaluation_id || null,
        priority_score,
        status: 'open',
        created_at: new Date(),
        updated_at: new Date()
      });

      created.push(need);

      const matchResult = await tryAutoMatchForNeed(need);
      matches.push({ need_id: need.need_id, match: matchResult });

      if (!matchResult?.matched) {
        await ensureEquipmentDonationCampaignForNeed(need);
      } else if (matchResult?.autoAllocated) {
        await closeEquipmentCampaignForNeedIfAny(need.need_id);
      }
    }

    return res.status(201).json({
      success: true,
      data: {
        created,
        matches
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في تأكيد اقتراحات AI', error: error.message });
  }
};

exports.getChildNeedsForSpecialist = async (req, res) => {
  try {
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({ success: false, message: 'Access denied. Only specialists can view needs' });
    }

    const { child_id } = req.query;
    if (!child_id) {
      return res.status(400).json({ success: false, message: 'child_id مطلوب' });
    }

    const child = await Child.findByPk(child_id);
    if (!child) {
      return res.status(404).json({ success: false, message: 'الطفل غير موجود' });
    }

    const institutionId = child.current_institution_id;
    if (!institutionId) {
      return res.status(400).json({ success: false, message: 'لا يوجد مؤسسة مرتبطة بالطفل' });
    }

    const needs = await ChildEquipmentNeed.findAll({
      where: { child_id: child.child_id, institution_id: institutionId },
      include: [{ model: EquipmentCategory, as: 'category', required: false }],
      order: [['created_at', 'DESC']]
    });

    return res.status(200).json({ success: true, data: needs });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في جلب احتياجات الطفل', error: error.message });
  }
};

exports.getManagerInventory = async (req, res) => {
  try {
    const institutionId = req.institution_id;
    const { usage_type, page = 1, limit = 10 } = req.query;
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 10;
    const offset = (pageNum - 1) * limitNum;

    const where = { institution_id: institutionId };
    if (usage_type) where.usage_type = usage_type;

    const items = await InstitutionEquipmentInventory.findAndCountAll({
      where,
      include: [{ model: EquipmentCategory, as: 'category', required: false }],
      order: [['created_at', 'DESC']],
      offset,
      limit: limitNum
    });

    return res.status(200).json({
      success: true,
      data: {
        items: items.rows,
        pagination: { page: pageNum, limit: limitNum, total: items.count, pages: Math.ceil(items.count / limitNum) }
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في جلب المخزون', error: error.message });
  }
};

exports.getManagerNeeds = async (req, res) => {
  try {
    const institutionId = req.institution_id;
    const { status, page = 1, limit = 10 } = req.query;
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 10;
    const offset = (pageNum - 1) * limitNum;

    const where = { institution_id: institutionId };
    if (status) where.status = status;

    const needs = await ChildEquipmentNeed.findAndCountAll({
      where,
      include: [{ model: Child, as: 'child', required: false }],
      order: [['priority_score', 'DESC'], ['created_at', 'DESC']],
      offset,
      limit: limitNum
    });

    return res.status(200).json({
      success: true,
      data: {
        needs: needs.rows,
        pagination: { page: pageNum, limit: limitNum, total: needs.count, pages: Math.ceil(needs.count / limitNum) }
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في جلب الاحتياجات', error: error.message });
  }
};

exports.allocateManuallyToChild = async (req, res) => {
  try {
    const institutionId = req.institution_id;
    const managerUserId = req.user.user_id;
    const { inventory_item_id, need_id, child_id, delivery_notes } = req.body;

    if (!inventory_item_id || !child_id) {
      return res.status(400).json({ success: false, message: 'inventory_item_id و child_id مطلوبة' });
    }

    const inventoryItem = await InstitutionEquipmentInventory.findOne({
      where: { inventory_item_id, institution_id: institutionId }
    });

    if (!inventoryItem || inventoryItem.quantity_available <= 0) {
      return res.status(400).json({ success: false, message: 'العنصر غير متاح في المخزون' });
    }

    await inventoryItem.update({
      quantity_available: Math.max(0, inventoryItem.quantity_available - 1),
      quantity_reserved: (inventoryItem.quantity_reserved || 0) + 1,
      usage_type: 'reserved',
      updated_at: new Date()
    });

    const allocation = await EquipmentAllocation.create({
      institution_id: institutionId,
      inventory_item_id: inventoryItem.inventory_item_id,
      need_id: need_id || null,
      child_id,
      allocation_mode: 'manual',
      allocated_by_user_id: managerUserId,
      usage_type: 'child',
      status: 'pending_receipt',
      delivery_notes: delivery_notes || null,
      created_at: new Date(),
      updated_at: new Date()
    });

    if (need_id) {
      const need = await ChildEquipmentNeed.findOne({ where: { need_id, institution_id: institutionId } });
      if (need) {
        await need.update({ status: 'allocated', updated_at: new Date() });
      }
    }

    await logHistory({
      institution_id: institutionId,
      inventory_item_id: inventoryItem.inventory_item_id,
      event_type: 'manual_allocated',
      related_id: allocation.allocation_id,
      actor_user_id: managerUserId,
      details: { need_id: need_id || null, child_id }
    });

    return res.status(201).json({ success: true, data: allocation });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في التخصيص', error: error.message });
  }
};

exports.setInventoryInternalUse = async (req, res) => {
  try {
    const institutionId = req.institution_id;
    const managerUserId = req.user.user_id;
    const { inventory_item_id, internal_department, notes } = req.body;

    if (!inventory_item_id || !internal_department) {
      return res.status(400).json({ success: false, message: 'inventory_item_id و internal_department مطلوبة' });
    }

    const item = await InstitutionEquipmentInventory.findOne({
      where: { inventory_item_id, institution_id: institutionId }
    });

    if (!item) {
      return res.status(404).json({ success: false, message: 'العنصر غير موجود' });
    }

    await item.update({
      usage_type: 'internal',
      internal_department,
      notes: notes || item.notes,
      updated_at: new Date()
    });

    await logHistory({
      institution_id: institutionId,
      inventory_item_id: item.inventory_item_id,
      event_type: 'set_internal_use',
      actor_user_id: managerUserId,
      details: { internal_department }
    });

    return res.status(200).json({ success: true, data: item });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في تحديث الاستخدام الداخلي', error: error.message });
  }
};

exports.getInventoryHistory = async (req, res) => {
  try {
    const institutionId = req.institution_id;
    const { inventory_item_id } = req.params;

    const item = await InstitutionEquipmentInventory.findOne({
      where: { inventory_item_id, institution_id: institutionId }
    });

    if (!item) {
      return res.status(404).json({ success: false, message: 'العنصر غير موجود' });
    }

    const history = await EquipmentItemHistory.findAll({
      where: { institution_id: institutionId, inventory_item_id },
      order: [['created_at', 'DESC']]
    });

    return res.status(200).json({ success: true, data: history });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في جلب السجل', error: error.message });
  }
};

exports.parentConfirmReceipt = async (req, res) => {
  try {
    const parentUserId = req.user.user_id;
    const { allocation_id } = req.params;

    const allocation = await EquipmentAllocation.findOne({
      where: { allocation_id },
      include: [{
        model: Child,
        as: 'child',
        include: [{ model: Parent }]
      }, {
        model: InstitutionEquipmentInventory,
        as: 'inventoryItem'
      }]
    });

    if (!allocation || allocation.usage_type !== 'child') {
      return res.status(404).json({ success: false, message: 'التخصيص غير موجود' });
    }

    if (!allocation.child || !allocation.child.Parent || allocation.child.Parent.parent_id !== parentUserId) {
      return res.status(403).json({ success: false, message: 'ليس لديك صلاحية تأكيد الاستلام' });
    }

    await allocation.update({
      status: 'delivered',
      parent_confirmed_at: new Date(),
      updated_at: new Date()
    });

    if (allocation.inventoryItem) {
      await allocation.inventoryItem.update({
        quantity_reserved: Math.max(0, (allocation.inventoryItem.quantity_reserved || 0) - 1),
        usage_type: 'assigned',
        updated_at: new Date()
      });

      await logHistory({
        institution_id: allocation.institution_id,
        inventory_item_id: allocation.inventory_item_id,
        event_type: 'parent_confirmed_receipt',
        related_id: allocation.allocation_id,
        actor_user_id: parentUserId,
        details: { child_id: allocation.child_id }
      });
    }

    if (allocation.need_id) {
      const need = await ChildEquipmentNeed.findOne({ where: { need_id: allocation.need_id } });
      if (need) await need.update({ status: 'delivered', updated_at: new Date() });
    }

    return res.status(200).json({ success: true, data: allocation });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في تأكيد الاستلام', error: error.message });
  }
};

exports.getParentAllocations = async (req, res) => {
  try {
    const parentUserId = req.user.user_id;
    const { child_id, status } = req.query;

    const childWhere = {
      parent_id: parentUserId,
      deleted_at: null
    };
    if (child_id) childWhere.child_id = child_id;

    const children = await Child.findAll({ where: childWhere, attributes: ['child_id'] });
    const childIds = children.map(c => c.child_id);

    if (!childIds || childIds.length === 0) {
      return res.status(200).json({ success: true, data: [] });
    }

    const allocWhere = {
      usage_type: 'child',
      child_id: childIds
    };
    if (status) allocWhere.status = status;

    const allocations = await EquipmentAllocation.findAll({
      where: allocWhere,
      include: [{
        model: Child,
        as: 'child'
      }, {
        model: InstitutionEquipmentInventory,
        as: 'inventoryItem'
      }],
      order: [['created_at', 'DESC']]
    });

    return res.status(200).json({ success: true, data: allocations });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'خطأ في جلب التخصيصات للأهل', error: error.message });
  }
};

exports._internal = {
  logHistory,
  tryAutoMatchForNeed,
  calculateNeedPriorityScore
};
