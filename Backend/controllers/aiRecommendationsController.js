const axios = require('axios');
const sequelize = require('../config/db');

async function fetchDonorContext(userId) {
  const [user] = await sequelize.query(
    `SELECT user_id, city, region, location_address
     FROM Users
     WHERE user_id = :userId
     LIMIT 1`,
    {
      replacements: { userId },
      type: sequelize.QueryTypes.SELECT
    }
  );

  const donations = await sequelize.query(
    `SELECT institution_id, COUNT(*) AS cnt, SUM(amount) AS total_amount
     FROM Donations
     WHERE donor_id = :userId AND status = 'completed'
     GROUP BY institution_id`,
    {
      replacements: { userId },
      type: sequelize.QueryTypes.SELECT
    }
  );

  const equipmentDonations = await sequelize.query(
    `SELECT institution_id, COUNT(*) AS cnt
     FROM EquipmentDonations
     WHERE donor_id = :userId
     GROUP BY institution_id`,
    {
      replacements: { userId },
      type: sequelize.QueryTypes.SELECT
    }
  );

  const donatedInstitutionIds = new Set([
    ...(donations || []).map(d => Number(d.institution_id)),
    ...(equipmentDonations || []).map(d => Number(d.institution_id))
  ].filter(x => Number.isFinite(x)));

  return {
    user: user || null,
    donations: donations || [],
    equipmentDonations: equipmentDonations || [],
    donatedInstitutionIds
  };
}

function deriveCityRegionFromAddress(locationAddress) {
  const raw = (locationAddress || '').toString().trim();
  if (!raw) return { city: null, region: null };

  const parts = raw
    .split(',')
    .map(x => x.trim())
    .filter(Boolean);

  if (!parts.length) return { city: null, region: null };

  const city = parts[0] || null;
  const region = (parts.length >= 2 ? parts[1] : null);
  return { city, region };
}

async function fetchInstitutionNeedSignals() {
  const institutions = await sequelize.query(
    `SELECT institution_id, name, city, location, rating, is_active, approval_status
     FROM Institutions
     WHERE name IS NOT NULL AND is_active = 1 AND approval_status = 'Approved'`,
    { type: sequelize.QueryTypes.SELECT }
  );

  const donationCampaignSignals = await sequelize.query(
    `SELECT institution_id,
            COUNT(*) AS active_campaigns,
            SUM(GREATEST(target_amount - amount_raised, 0)) AS remaining_amount
     FROM DonationCampaigns
     WHERE status = 'Active'
     GROUP BY institution_id`,
    { type: sequelize.QueryTypes.SELECT }
  );

  const equipmentCampaignSignals = await sequelize.query(
    `SELECT institution_id,
            COUNT(*) AS open_campaigns
     FROM EquipmentDonationCampaigns
     WHERE status IN ('open', 'partially_fulfilled')
     GROUP BY institution_id`,
    { type: sequelize.QueryTypes.SELECT }
  );

  const donationMap = new Map(
    (donationCampaignSignals || []).map(r => [Number(r.institution_id), r])
  );
  const equipmentMap = new Map(
    (equipmentCampaignSignals || []).map(r => [Number(r.institution_id), r])
  );

  return (institutions || []).map(inst => {
    const id = Number(inst.institution_id);
    const d = donationMap.get(id) || { active_campaigns: 0, remaining_amount: 0 };
    const e = equipmentMap.get(id) || { open_campaigns: 0 };

    return {
      institution_id: id,
      name: inst.name,
      city: inst.city,
      location: inst.location,
      rating: inst.rating,
      active_campaigns: Number(d.active_campaigns || 0),
      remaining_amount: Number(d.remaining_amount || 0),
      open_equipment_campaigns: Number(e.open_campaigns || 0)
    };
  });
}

function buildDonorRecommendationReasons({ inst, donorCity, donorRegion, hasDonatedBefore }) {
  const reasons = [];
  if (donorCity && inst.city && String(inst.city).toLowerCase() === String(donorCity).toLowerCase()) {
    reasons.push('قريبة من منطقتك');
  } else if (
    donorRegion &&
    (
      (inst.city && String(inst.city).toLowerCase().includes(String(donorRegion).toLowerCase())) ||
      (inst.location && String(inst.location).toLowerCase().includes(String(donorRegion).toLowerCase()))
    )
  ) {
    reasons.push('ضمن نطاق منطقتك');
  }

  if (hasDonatedBefore) {
    reasons.push('أنت دعمت هذه المؤسسة سابقاً');
  }

  if (inst.active_campaigns > 0) {
    reasons.push(`لديها ${inst.active_campaigns} حملة تبرع مالية نشطة`);
  }
  if (inst.open_equipment_campaigns > 0) {
    reasons.push(`لديها ${inst.open_equipment_campaigns} حملة معدات مفتوحة`);
  }

  if (!reasons.length) {
    reasons.push('مؤسسة فعّالة ومناسبة للتبرع');
  }
  return reasons;
}

function scoreInstitutionForDonor({ inst, donorCity, donorRegion, hasDonatedBefore }) {
  let score = 0;

  // Need signals
  score += Math.min(40, inst.active_campaigns * 10);
  score += Math.min(35, inst.open_equipment_campaigns * 8);
  if (inst.remaining_amount && inst.remaining_amount > 0) {
    score += Math.min(15, Math.log10(inst.remaining_amount + 1) * 4);
  }

  // Location match
  if (donorCity && inst.city && String(inst.city).toLowerCase() === String(donorCity).toLowerCase()) score += 20;
  else if (
    donorRegion &&
    (
      (inst.city && String(inst.city).toLowerCase().includes(String(donorRegion).toLowerCase())) ||
      (inst.location && String(inst.location).toLowerCase().includes(String(donorRegion).toLowerCase()))
    )
  ) {
    score += 10;
  }

  // Loyalty
  if (hasDonatedBefore) score += 15;

  // Rating (soft)
  if (inst.rating) score += Math.min(10, (Number(inst.rating) / 5) * 10);

  return Math.round(score);
}

async function generateDonorAIEnhancement({ donorContext, ranked, limit }) {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) return null;

  const donorCity = donorContext.user?.city || '';
  const donorRegion = donorContext.user?.region || '';

  const prompt = `You are a donor personalization assistant for a charity platform.

Donor profile:
- city: ${donorCity || 'unknown'}
- region: ${donorRegion || 'unknown'}

Candidate institutions (JSON):
${JSON.stringify(ranked.slice(0, Math.min(10, ranked.length)), null, 2)}

Return ONLY valid JSON with this structure:
{
  "summary": "...",
  "recommended_actions": ["..."],
  "institutions": [
    {
      "institution_id": 1,
      "ai_reason": "...",
      "donation_focus": "money|equipment|both"
    }
  ]
}

Rules:
- Keep it short.
- Arabic output.
- Do not invent institutions not in the candidate list.
`;

  try {
    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'llama-3.1-8b-instant',
        messages: [
          { role: 'system', content: 'Return ONLY valid JSON. No explanations.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.3,
        max_tokens: 700
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const txt = response.data.choices[0]?.message?.content || '{}';
    const jsonMatch = txt.match(/\{[\s\S]*\}/);
    const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : txt);
    if (!parsed || typeof parsed !== 'object') return null;

    const instMap = new Map(
      (parsed.institutions || []).map(x => [Number(x.institution_id), x])
    );

    return {
      summary: parsed.summary,
      recommended_actions: Array.isArray(parsed.recommended_actions) ? parsed.recommended_actions.slice(0, 6) : [],
      institutions: ranked.slice(0, limit).map(r => {
        const extra = instMap.get(Number(r.institution_id));
        return {
          institution_id: r.institution_id,
          ai_reason: extra?.ai_reason || null,
          donation_focus: extra?.donation_focus || null
        };
      })
    };
  } catch (e) {
    return null;
  }
}

// Get AI-powered institution recommendations
exports.getRecommendations = async (req, res) => {
  try {
    const { childConditions, childAge, location, budget } = req.query;

    if (!childConditions) {
      return res.status(400).json({
        success: false,
        message: 'Child conditions are required'
      });
    }

    // Get all active institutions
    const institutions = await sequelize.query(`
      SELECT 
        institution_id,
        name,
        description,
        location,
        services_offered,
        conditions_supported,
        rating,
        price_range,
        capacity,
        available_slots
      FROM Institutions
      WHERE name IS NOT NULL
      ORDER BY rating DESC
      LIMIT 20
    `, {
      type: sequelize.QueryTypes.SELECT
    });

    // Use Groq AI to generate smart recommendations
    const aiRecommendations = await generateAIRecommendations({
      childConditions,
      childAge: childAge || 'not specified',
      location: location || 'not specified',
      budget: budget || 'not specified',
      institutions
    });

    // Calculate match scores
    const rankedInstitutions = institutions.map(inst => {
      const matchScore = calculateMatchScore(inst, {
        childConditions: childConditions.split(','),
        location,
        budget
      });

      return {
        ...inst,
        match_score: matchScore,
        ai_reasoning: findAIReasoning(inst.name, aiRecommendations)
      };
    });

    // Sort by match score
    rankedInstitutions.sort((a, b) => b.match_score - a.match_score);

    res.status(200).json({
      success: true,
      recommendations: rankedInstitutions.slice(0, 10),
      ai_summary: aiRecommendations.summary || 'Based on your child\'s profile, here are the top recommended centers.'
    });
  } catch (error) {
    console.error('Error generating recommendations:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

exports.getDonorRecommendations = async (req, res) => {
  try {
    const userId = req.user?.user_id;
    if (!userId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const limitRaw = req.query.limit;
    const limit = Math.max(1, Math.min(15, parseInt(limitRaw, 10) || 8));

    const donorContext = await fetchDonorContext(userId);
    let donorCity = donorContext.user?.city || null;
    let donorRegion = donorContext.user?.region || null;

    if (!donorCity && !donorRegion) {
      const derived = deriveCityRegionFromAddress(donorContext.user?.location_address);
      donorCity = derived.city;
      donorRegion = derived.region;
    }

    const institutions = await fetchInstitutionNeedSignals();

    const ranked = institutions
      .map(inst => {
        const hasDonatedBefore = donorContext.donatedInstitutionIds.has(Number(inst.institution_id));
        const match_score = scoreInstitutionForDonor({
          inst,
          donorCity,
          donorRegion,
          hasDonatedBefore
        });

        const reasons = buildDonorRecommendationReasons({
          inst,
          donorCity,
          donorRegion,
          hasDonatedBefore
        });

        const donationFocus = (inst.active_campaigns > 0 && inst.open_equipment_campaigns > 0)
          ? 'both'
          : (inst.open_equipment_campaigns > 0 ? 'equipment' : 'money');

        return {
          institution_id: inst.institution_id,
          name: inst.name,
          city: inst.city,
          location: inst.location,
          rating: inst.rating,
          match_score,
          donation_focus: donationFocus,
          reasons,
          signals: {
            active_donation_campaigns: inst.active_campaigns,
            remaining_amount: inst.remaining_amount,
            open_equipment_campaigns: inst.open_equipment_campaigns,
            donated_before: hasDonatedBefore
          }
        };
      })
      .sort((a, b) => b.match_score - a.match_score);

    const top = ranked.slice(0, limit);
    const aiEnhancement = await generateDonorAIEnhancement({ donorContext, ranked, limit });

    const recommendedActions = [
      'اختر مؤسسة قريبة منك لتسهيل التواصل والمتابعة',
      'نوّع التبرع بين المصاري والمعدات حسب الحملات المتاحة',
      'تابع حالة الحملة بعد التبرع لمعرفة الأثر'
    ];

    return res.status(200).json({
      success: true,
      ai_summary: aiEnhancement?.summary || 'توصيات ذكية مبنية على منطقتك وسجل تبرعاتك واحتياج المؤسسات.',
      recommended_actions: aiEnhancement?.recommended_actions?.length ? aiEnhancement.recommended_actions : recommendedActions,
      recommendations: top.map(r => ({
        ...r,
        ai_reason: (aiEnhancement?.institutions || []).find(x => x.institution_id === r.institution_id)?.ai_reason || null,
        donation_focus: (aiEnhancement?.institutions || []).find(x => x.institution_id === r.institution_id)?.donation_focus || r.donation_focus
      })),
      donor_context: {
        city: donorCity,
        region: donorRegion,
        donated_institutions_count: donorContext.donatedInstitutionIds.size
      }
    });
  } catch (error) {
    console.error('Error generating donor recommendations:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Generate AI-powered recommendations using Groq
async function generateAIRecommendations(data) {
  try {
    const apiKey = process.env.GROQ_API_KEY;
    if (!apiKey) {
      console.log('⚠️ GROQ_API_KEY not found, using fallback recommendations');
      return { summary: 'Smart recommendations based on your criteria.', recommendations: [] };
    }

    const prompt = `You are an expert in special needs education and therapy centers. 

Child Profile:
- Conditions: ${data.childConditions}
- Age: ${data.childAge}
- Location: ${data.location}
- Budget: ${data.budget}

Available Centers:
${data.institutions.slice(0, 10).map((inst, idx) => 
  `${idx + 1}. ${inst.name} - ${inst.location}
   Services: ${inst.services_offered || 'General therapy'}
   Conditions: ${inst.conditions_supported || 'Various'}
   Rating: ${inst.rating || 'N/A'}/5
   Price: ${inst.price_range || 'Contact for pricing'}`
).join('\n\n')}

Please provide:
1. A brief summary (2-3 sentences) of the best approach for this child
2. Top 3 recommended centers with brief reasoning (1 sentence each)

Format your response as JSON:
{
  "summary": "your summary here",
  "recommendations": [
    {"center": "Center Name", "reasoning": "why this center"}
  ]
}`;

    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'llama-3.1-8b-instant',
        messages: [
          {
            role: 'system',
            content: 'You are a helpful assistant that provides concise, expert recommendations for special needs therapy centers. Always respond in valid JSON format.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 500
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const aiResponse = response.data.choices[0]?.message?.content || '{}';
    
    // Try to parse JSON from response
    try {
      const parsed = JSON.parse(aiResponse);
      return parsed;
    } catch (parseError) {
      // If not valid JSON, extract info manually
      return {
        summary: aiResponse.substring(0, 200),
        recommendations: []
      };
    }
  } catch (error) {
    console.error('Error calling Groq AI:', error.message);
    return {
      summary: 'Smart recommendations based on your child\'s profile and needs.',
      recommendations: []
    };
  }
}

// Calculate match score based on multiple factors
function calculateMatchScore(institution, criteria) {
  let score = 0;

  // Check conditions match
  if (institution.conditions_supported && criteria.childConditions) {
    const instConditions = institution.conditions_supported.toLowerCase();
    const childConditions = criteria.childConditions.map(c => c.toLowerCase());
    
    const matchingConditions = childConditions.filter(cond => 
      instConditions.includes(cond.trim())
    );
    
    score += (matchingConditions.length / childConditions.length) * 40;
  }

  // Check location match
  if (institution.location && criteria.location) {
    if (institution.location.toLowerCase().includes(criteria.location.toLowerCase())) {
      score += 25;
    }
  }

  // Rating factor
  if (institution.rating) {
    score += (institution.rating / 5) * 20;
  }

  // Availability factor
  if (institution.available_slots && institution.available_slots > 0) {
    score += 10;
  }

  // Price factor
  if (institution.price_range && criteria.budget) {
    const budgetMatch = matchBudget(institution.price_range, criteria.budget);
    score += budgetMatch * 5;
  }

  return Math.round(score);
}

function matchBudget(priceRange, budget) {
  const rangeLower = priceRange.toLowerCase();
  const budgetLower = budget.toLowerCase();

  if (rangeLower.includes('low') && budgetLower.includes('low')) return 1;
  if (rangeLower.includes('medium') && budgetLower.includes('medium')) return 1;
  if (rangeLower.includes('high') && budgetLower.includes('high')) return 1;
  
  return 0.5; // Partial match
}

function findAIReasoning(centerName, aiRecommendations) {
  if (!aiRecommendations.recommendations) return null;
  
  const match = aiRecommendations.recommendations.find(rec => 
    rec.center && centerName.includes(rec.center)
  );
  
  return match ? match.reasoning : null;
}

module.exports = exports;
