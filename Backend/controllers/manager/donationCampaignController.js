const { DonationCampaign, Donation, Manager, Institution, DonationAllocation, Invoice, Session, Child } = require('../../model');
const { Op } = require('sequelize');

async function getManagerInstitution(managerId) {
  const manager = await Manager.findOne({
    where: {
      manager_id: managerId,
      is_active: true
    },
    include: [{
      model: Institution,
      attributes: ['institution_id', 'name']
    }]
  });

  if (!manager || !manager.Institution) {
    return null;
  }

  return manager.Institution;
}

exports.getCampaigns = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const institution = await getManagerInstitution(managerId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const campaigns = await DonationCampaign.findAll({
      where: { institution_id: institution.institution_id },
      order: [['created_at', 'DESC']]
    });

    const campaignIds = campaigns.map(c => c.campaign_id);
    let sumsByCampaign = {};
    let donorsCountByCampaign = {};
    let donationsCountByCampaign = {};

    if (campaignIds.length > 0) {
      const sums = await Donation.findAll({
        where: {
          institution_id: institution.institution_id,
          campaign_id: {
            [Op.in]: campaignIds
          }
        },
        attributes: [
          'campaign_id',
          [Donation.sequelize.fn('SUM', Donation.sequelize.col('amount')), 'total'],
          [Donation.sequelize.fn('COUNT', Donation.sequelize.col('donation_id')), 'donations_count'],
          [Donation.sequelize.fn('COUNT', Donation.sequelize.fn('DISTINCT', Donation.sequelize.col('donor_id'))), 'donors_count']
        ],
        group: ['campaign_id'],
        raw: true
      });

      sumsByCampaign = sums.reduce((acc, item) => {
        acc[item.campaign_id] = parseFloat(item.total || 0);
        return acc;
      }, {});

      donorsCountByCampaign = sums.reduce((acc, item) => {
        acc[item.campaign_id] = parseInt(item.donors_count || 0, 10) || 0;
        return acc;
      }, {});

      donationsCountByCampaign = sums.reduce((acc, item) => {
        acc[item.campaign_id] = parseInt(item.donations_count || 0, 10) || 0;
        return acc;
      }, {});
    }

    const data = campaigns.map(campaign => {
      const total = sumsByCampaign[campaign.campaign_id] || 0;
      const donorsCount = donorsCountByCampaign[campaign.campaign_id] || 0;
      const donationsCount = donationsCountByCampaign[campaign.campaign_id] || 0;
      const target = parseFloat(campaign.target_amount || 0);
      const progress = target > 0 ? parseFloat(((total / target) * 100).toFixed(1)) : 0;

      return {
        campaign_id: campaign.campaign_id,
        institution_id: campaign.institution_id,
        name: campaign.name,
        description: campaign.description,
        target_amount: parseFloat(campaign.target_amount || 0),
        total_donations: total,
        donors_count: donorsCount,
        donations_count: donationsCount,
        progress_percentage: progress,
        start_date: campaign.start_date,
        end_date: campaign.end_date,
        status: campaign.status,
        created_at: campaign.created_at,
        updated_at: campaign.updated_at
      };
    });

    return res.status(200).json({
      success: true,
      data
    });

  } catch (error) {
    console.error('Error in getCampaigns:', error);
    return res.status(500).json({
      success: false,
      message: 'Error fetching donation campaigns',
      error: error.message
    });
  }
};

exports.getCampaignImpact = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const campaignId = parseInt(req.params.id, 10);

    if (!campaignId || !Number.isFinite(campaignId)) {
      return res.status(400).json({
        success: false,
        message: 'Valid campaign id is required'
      });
    }

    const institution = await getManagerInstitution(managerId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const campaign = await DonationCampaign.findOne({
      where: {
        campaign_id: campaignId,
        institution_id: institution.institution_id
      }
    });

    if (!campaign) {
      return res.status(404).json({
        success: false,
        message: 'Campaign not found for this institution'
      });
    }

    const donationAgg = await Donation.findOne({
      where: {
        institution_id: institution.institution_id,
        campaign_id: campaignId
      },
      attributes: [
        [Donation.sequelize.fn('SUM', Donation.sequelize.col('amount')), 'total']
      ],
      raw: true
    });

    const totalDonations = parseFloat(donationAgg?.total || 0);
    const targetAmount = parseFloat(campaign.target_amount || 0);
    const progressPercentage = targetAmount > 0
      ? parseFloat(((totalDonations / targetAmount) * 100).toFixed(1))
      : 0;

    const donations = await Donation.findAll({
      where: {
        institution_id: institution.institution_id,
        campaign_id: campaignId
      },
      attributes: ['donation_id'],
      raw: true
    });

    const donationIds = donations.map(d => d.donation_id);

    let totalAllocatedFromCampaign = 0;
    let supportedSessionsCount = 0;
    let supportedChildrenCount = 0;

    if (donationIds.length > 0) {
      const allocations = await DonationAllocation.findAll({
        where: {
          donation_id: {
            [Op.in]: donationIds
          }
        },
        attributes: ['allocation_id', 'donation_id', 'invoice_id', 'amount_allocated'],
        raw: true
      });

      if (allocations.length > 0) {
        totalAllocatedFromCampaign = allocations.reduce(
          (sum, a) => sum + parseFloat(a.amount_allocated || 0),
          0
        );

        const invoiceIds = [...new Set(allocations.map(a => a.invoice_id).filter(id => !!id))];

        if (invoiceIds.length > 0) {
          const invoices = await Invoice.findAll({
            where: {
              invoice_id: {
                [Op.in]: invoiceIds
              }
            },
            attributes: ['invoice_id', 'session_id'],
            raw: true
          });

          const sessionIds = [...new Set(invoices.map(i => i.session_id).filter(id => !!id))];

          if (sessionIds.length > 0) {
            supportedSessionsCount = sessionIds.length;

            const sessions = await Session.findAll({
              where: {
                session_id: {
                  [Op.in]: sessionIds
                }
              },
              attributes: ['session_id', 'child_id'],
              raw: true
            });

            const childIds = [...new Set(sessions.map(s => s.child_id).filter(id => !!id))];
            supportedChildrenCount = childIds.length;
          }
        }
      }
    }

    return res.status(200).json({
      success: true,
      data: {
        campaign_id: campaign.campaign_id,
        institution_id: campaign.institution_id,
        name: campaign.name,
        target_amount: targetAmount,
        total_donations: totalDonations,
        progress_percentage: progressPercentage,
        total_allocated_from_campaign: totalAllocatedFromCampaign,
        supported_sessions_count: supportedSessionsCount,
        supported_children_count: supportedChildrenCount
      }
    });

  } catch (error) {
    console.error('Error in getCampaignImpact:', error);
    return res.status(500).json({
      success: false,
      message: 'Error fetching campaign impact',
      error: error.message
    });
  }
};

exports.createCampaign = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institution = await getManagerInstitution(managerId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const {
      name,
      description,
      target_amount,
      start_date,
      end_date,
      status
    } = req.body;

    if (!name || !target_amount) {
      return res.status(400).json({
        success: false,
        message: 'name and target_amount are required'
      });
    }

    const campaign = await DonationCampaign.create({
      institution_id: institution.institution_id,
      name,
      description: description || null,
      target_amount: parseFloat(target_amount) || 0,
      start_date: start_date || null,
      end_date: end_date || null,
      status: status || 'Upcoming'
    });

    return res.status(201).json({
      success: true,
      data: campaign
    });

  } catch (error) {
    console.error('Error in createCampaign:', error);
    return res.status(500).json({
      success: false,
      message: 'Error creating donation campaign',
      error: error.message
    });
  }
};

exports.updateCampaign = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institution = await getManagerInstitution(managerId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const { id } = req.params;

    const campaign = await DonationCampaign.findOne({
      where: {
        campaign_id: id,
        institution_id: institution.institution_id
      }
    });

    if (!campaign) {
      return res.status(404).json({
        success: false,
        message: 'Campaign not found'
      });
    }

    const {
      name,
      description,
      target_amount,
      start_date,
      end_date,
      status
    } = req.body;

    await campaign.update({
      name: name !== undefined ? name : campaign.name,
      description: description !== undefined ? description : campaign.description,
      target_amount: target_amount !== undefined ? parseFloat(target_amount) : campaign.target_amount,
      start_date: start_date !== undefined ? start_date : campaign.start_date,
      end_date: end_date !== undefined ? end_date : campaign.end_date,
      status: status !== undefined ? status : campaign.status,
      updated_at: new Date()
    });

    return res.status(200).json({
      success: true,
      data: campaign
    });

  } catch (error) {
    console.error('Error in updateCampaign:', error);
    return res.status(500).json({
      success: false,
      message: 'Error updating donation campaign',
      error: error.message
    });
  }
};
