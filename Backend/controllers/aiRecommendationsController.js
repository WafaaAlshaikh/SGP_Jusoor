const axios = require('axios');
const sequelize = require('../config/db');

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
