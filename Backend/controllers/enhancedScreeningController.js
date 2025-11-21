// controllers/enhancedScreeningController.js
const AIAnalysisService = require('../services/aiAnalysisService');
const GroqAIService = require('../services/groqAIService');
const { Institution, SessionType, sequelize } = require('../model/index');
const { Op } = require('sequelize');

class EnhancedScreeningController {
  
  async analyzeScreeningResults(screeningResults, childAgeMonths, childLocation = {}) {
    try {
      console.log('🤖 Starting enhanced screening analysis...');

      // 1. Convert screening results to symptoms description for AI
      const symptomsDescription = this.generateSymptomsFromScreening(screeningResults, childAgeMonths);
      
      // 2. Use AI Analysis
      let aiAnalysis = null;
      
      if (symptomsDescription && symptomsDescription.trim() !== '') {
        console.log('🔍 Analyzing symptoms with AI...');
        
        aiAnalysis = await GroqAIService.analyzeSymptoms(
          symptomsDescription, 
          '', // medical_history
          ''  // previous_services
        );

        if (!aiAnalysis || !aiAnalysis.suggested_conditions || aiAnalysis.suggested_conditions.length === 0) {
          console.log('🔄 Falling back to Local AI...');
          aiAnalysis = await AIAnalysisService.analyzeSymptoms(symptomsDescription);
        }
      }

      // 3. Get recommended institutions
      const recommendedInstitutions = await this.getInstitutionsFromScreening(
        screeningResults, 
        childLocation
      );

      // 4. Generate smart next steps
      const nextSteps = this.generateScreeningNextSteps(screeningResults, aiAnalysis, recommendedInstitutions);

      return {
        success: true,
        ai_analysis: aiAnalysis ? {
          suggested_conditions: aiAnalysis.suggested_conditions.map(condition => ({
            name: condition.arabic_name || condition.name,
            confidence: `${(condition.confidence * 100).toFixed(1)}%`,
            matching_keywords: condition.matching_keywords
          })),
          risk_level: aiAnalysis.risk_level,
          analyzed_keywords: aiAnalysis.analyzed_keywords,
          source: aiAnalysis.source || 'local_ai'
        } : null,
        recommended_institutions: recommendedInstitutions.institutions || [],
        next_steps: nextSteps,
        screening_summary: this.generateScreeningSummary(screeningResults),
        urgency_level: this.getUrgencyLevel(screeningResults)
      };

    } catch (error) {
      console.error('❌ Error in enhanced screening analysis:', error);
      return {
        success: false,
        error: error.message,
        recommended_institutions: [],
        next_steps: ['We recommend consulting with a child development specialist']
      };
    }
  }

  generateSymptomsFromScreening(screeningResults, childAgeMonths) {
    let symptoms = `Child ${childAgeMonths} months old shows the following indicators:\n\n`;
    
    if (screeningResults.primary_concern === 'autism') {
      symptoms += `🔸 Autism Spectrum Indicators:\n`;
      symptoms += `- Risk Level: ${screeningResults.risk_levels.autism}\n`;
      symptoms += `- Critical Signs: ${screeningResults.scores?.autism?.critical || 0}\n`;
      symptoms += `- Total Score: ${screeningResults.scores?.autism?.total || 0}\n`;
      
      if (screeningResults.red_flags && screeningResults.red_flags.length > 0) {
        symptoms += `- Red Flags: ${screeningResults.red_flags.join(', ')}\n`;
      }
    }
    
    if (screeningResults.primary_concern === 'adhd_inattention') {
      symptoms += `🔸 ADHD - Inattention Indicators:\n`;
      symptoms += `- Inattention Score: ${screeningResults.scores?.adhd?.inattention || 0}/9\n`;
      symptoms += `- Likely Impact: ${screeningResults.scores?.adhd?.inattention >= 6 ? 'High' : 'Moderate'}\n`;
    }
    
    if (screeningResults.primary_concern === 'adhd_hyperactive') {
      symptoms += `🔸 ADHD - Hyperactive Indicators:\n`;
      symptoms += `- Hyperactive Score: ${screeningResults.scores?.adhd?.hyperactive || 0}/9\n`;
      symptoms += `- Likely Impact: ${screeningResults.scores?.adhd?.hyperactive >= 6 ? 'High' : 'Moderate'}\n`;
    }
    
    if (screeningResults.primary_concern === 'speech_delay' || screeningResults.secondary_concern === 'speech_delay') {
      symptoms += `🔸 Speech Delay Indicators:\n`;
      symptoms += `- Delay Level: ${screeningResults.risk_levels.speech}\n`;
      symptoms += `- Speech Score: ${screeningResults.scores?.speech?.total || 0}\n`;
      symptoms += `- Age: ${childAgeMonths} months\n`;
    }

    // Add recommendations if available
    if (screeningResults.recommendations && screeningResults.recommendations.length > 0) {
      symptoms += `\n🔸 Initial Recommendations: ${screeningResults.recommendations.join(', ')}`;
    }

    // Add positive indicators if no concerns
    if (!screeningResults.primary_concern && screeningResults.positive_indicators) {
      symptoms += `\n✅ Positive Development: ${screeningResults.positive_indicators.join(', ')}`;
    }

    return symptoms;
  }

  // في enhancedScreeningController.js - نعدل دالة getInstitutionsFromScreening
async getInstitutionsFromScreening(screeningResults, childLocation, parentLocation = {}) {
  try {
    const targetConditions = [];
    
    // Determine target conditions based on screening results
    if (screeningResults.primary_concern === 'autism') {
      targetConditions.push('Autism');
      targetConditions.push('ASD');
      if (screeningResults.risk_levels.autism === 'high') {
        targetConditions.push('Early Intervention');
        targetConditions.push('Behavioral Therapy');
        targetConditions.push('ABA Therapy');
      }
    }
    
    if (screeningResults.primary_concern === 'adhd_inattention') {
      targetConditions.push('ADHD');
      targetConditions.push('Attention Disorder');
      targetConditions.push('Behavioral Therapy');
    }
    
    if (screeningResults.primary_concern === 'adhd_hyperactive') {
      targetConditions.push('ADHD');
      targetConditions.push('Hyperactivity');
      targetConditions.push('Behavior Management');
    }
    
    if (screeningResults.primary_concern === 'speech_delay' || screeningResults.secondary_concern === 'speech_delay') {
      targetConditions.push('Speech Therapy');
      targetConditions.push('Language Development');
      targetConditions.push('Communication Skills');
    }

    console.log('🎯 Target conditions for institutions:', targetConditions);

    // Use our own method with parent location
    return await this.getRecommendedInstitutionsForScreening(
      targetConditions,
      childLocation?.city || '',
      childLocation?.address || '',
      parentLocation // ✅ نضيف موقع الأب
    );

  } catch (error) {
    console.error('❌ Error getting institutions from screening:', error);
    return { institutions: [] };
  }
}

// NEW: نعدل الدالة الأساسية عشان تأخذ parentLocation
async getRecommendedInstitutionsForScreening(targetConditions, childCity, childAddress, parentLocation = {}, filters = {}) {
  try {
    const {
      sort_by = 'match_score',
      city_filter,
      specialization_filter,
      max_distance,
      min_rating,
      max_price,
      page = 1,
      limit = 10
    } = filters;

    let whereClause = {};
    if (city_filter) {
      whereClause.city = city_filter;
    } else if (childCity) {
      whereClause.city = childCity;
    }

    console.log('🔍 Fetching institutions with filter:', whereClause);
    console.log('📍 Parent location data:', parentLocation);

    const institutions = await Institution.findAll({
      where: whereClause,
      attributes: [
        'institution_id', 
        'name', 
        'description', 
        'location',
        'city',
        'region',
        'location_lat',
        'location_lng',
        'location_address',
        'contact_info',
        'website'
      ]
    });

    console.log(`🏫 Found ${institutions.length} institutions`);

    const institutionIds = institutions.map(i => i.institution_id);
    const sessionTypes = await SessionType.findAll({
      where: { institution_id: institutionIds },
      include: [
        { 
          model: Institution, 
          attributes: ['institution_id'] 
        }
      ]
    });

    console.log(`📊 Found ${sessionTypes.length} session types`);

    const sessionTypesByInstitution = {};
    sessionTypes.forEach(st => {
      const instId = st.institution_id;
      if (!sessionTypesByInstitution[instId]) {
        sessionTypesByInstitution[instId] = [];
      }
      sessionTypesByInstitution[instId].push(st);
    });

    const scoredInstitutions = await Promise.all(
      institutions.map(async (institution) => {
        const instData = institution.get({ plain: true });
        const instSessionTypes = sessionTypesByInstitution[instData.institution_id] || [];

        let matchScore = 0;
        let matchingSpecialties = [];
        let matchingSessionTypes = [];

        instSessionTypes.forEach(st => {
          const stConditions = st.target_conditions || [];
          const stSpecialization = st.specialist_specialization || '';

          let conditionMatch = false;
          
          targetConditions.forEach(tc => {
            const targetLower = tc.toLowerCase();
            
            if (stConditions.some(stc => {
              if (!stc) return false;
              return stc.toLowerCase().includes(targetLower) || 
                    targetLower.includes(stc.toLowerCase());
            })) {
              conditionMatch = true;
            }
            
            if (stSpecialization.toLowerCase().includes(targetLower)) {
              conditionMatch = true;
            }
          });

          if (conditionMatch) {
            matchScore += 0.3;
            if (!matchingSpecialties.includes(st.category)) {
              matchingSpecialties.push(st.category);
            }
            matchingSessionTypes.push({
              name: st.name,
              category: st.category,
              price: parseFloat(st.price) || 0,
              duration: st.duration
            });
          }
        });

        if (matchingSpecialties.length > 2) matchScore += 0.2;

        // ✅ NOW: Calculate distance using parent location
        let distance = null;
        if (parentLocation.lat && parentLocation.lng && instData.location_lat && instData.location_lng) {
          distance = this.calculateDistance(
            parentLocation.lat,
            parentLocation.lng,
            instData.location_lat,
            instData.location_lng
          );
          console.log(`📍 Distance from parent to ${instData.name}: ${distance} km`);
        }

        // Simple city-based matching
        if (childCity && instData.city === childCity) {
          matchScore += 0.2;
        }

        const avgPrice = matchingSessionTypes.length > 0
          ? matchingSessionTypes.reduce((sum, st) => sum + (st.price || 0), 0) / matchingSessionTypes.length
          : 0;

        if (max_price && avgPrice > parseFloat(max_price)) {
          return null;
        }

        const rating = 4.0 + Math.random(); 

        if (min_rating && rating < parseFloat(min_rating)) {
          return null;
        }

        let finalScore = matchScore;
        
        // ✅ Adjust score based on distance (closer = better)
        if (distance !== null) {
          // المؤسسات الأقرب تحصل على نقاط أعلى
          if (distance < 5) {
            finalScore += 0.3; // قريبة جداً
          } else if (distance < 15) {
            finalScore += 0.2; // قريبة
          } else if (distance < 30) {
            finalScore += 0.1; // متوسطة
          }
          // أكثر من 30 كم ما في نقاط إضافية
        }
        
        // Adjust score based on specialization match
        if (matchingSpecialties.length > 0) {
          finalScore += 0.1 * matchingSpecialties.length;
        }

        return {
          id: instData.institution_id,
          name: instData.name,
          description: instData.description,
          city: instData.city,
          region: instData.region,
          address: instData.location_address,
          contact: instData.contact_info,
          website: instData.website,
          match_score: Math.min(finalScore, 1.0), 
          distance: distance,
          rating: rating.toFixed(1),
          avg_price: avgPrice.toFixed(2),
          matching_specialties: matchingSpecialties,
          available_services: matchingSessionTypes,
          total_services: instSessionTypes.length,
          coordinates: {
            lat: instData.location_lat,
            lng: instData.location_lng
          }
        };
      })
    );

    let filteredInstitutions = scoredInstitutions.filter(i => i !== null);

    // ✅ NOW: Sort by distance if available, otherwise by match score
    filteredInstitutions.sort((a, b) => {
      switch(sort_by) {
        case 'distance':
          // المؤسسات الأقرب تأتي أولاً
          return (a.distance || 999) - (b.distance || 999);
        case 'rating':
          return parseFloat(b.rating) - parseFloat(a.rating);
        case 'price':
          return parseFloat(a.avg_price) - parseFloat(b.avg_price);
        case 'match_score':
        default:
          // إذا عندنا مسافات، نفضل المؤسسات القريبة حتى لو كانت match score أقل قليلاً
          if (a.distance !== null && b.distance !== null) {
            // دمج بين المسافة والـ match score
            const aScore = a.match_score * (a.distance < 10 ? 1.2 : a.distance < 25 ? 1.1 : 1.0);
            const bScore = b.match_score * (b.distance < 10 ? 1.2 : b.distance < 25 ? 1.1 : 1.0);
            return bScore - aScore;
          }
          return b.match_score - a.match_score;
      }
    });

    const offset = (page - 1) * limit;
    const paginatedInstitutions = filteredInstitutions.slice(offset, offset + limit);

    console.log(`✅ Returning ${paginatedInstitutions.length} recommended institutions`);
    console.log('📍 Top institutions by distance:');
    paginatedInstitutions.slice(0, 3).forEach((inst, index) => {
      console.log(`   ${index + 1}. ${inst.name} - ${inst.distance} km - Match: ${inst.match_score}`);
    });

    return {
      institutions: paginatedInstitutions.map(inst => ({
        ...inst,
        match_score: `${(inst.match_score * 100).toFixed(0)}%`,
        distance: inst.distance ? `${inst.distance.toFixed(1)} KM` : 'Unknown'
      })),
      pagination: {
        page,
        limit,
        total: filteredInstitutions.length,
        total_pages: Math.ceil(filteredInstitutions.length / limit)
      }
    };

  } catch (error) {
    console.error('❌ Error calculating recommendations for screening:', error);
    throw error;
  }
}

  // NEW: Custom method for screening (without childId)
  // في enhancedScreeningController.js - نعدل دالة getRecommendedInstitutionsForScreening
async getRecommendedInstitutionsForScreening(targetConditions, childCity, childAddress, parentLocation = {}, filters = {}) {
  try {
    const {
      sort_by = 'match_score',
      city_filter,
      specialization_filter,
      max_distance,
      min_rating,
      max_price,
      page = 1,
      limit = 10
    } = filters;

    let whereClause = {};
    if (city_filter) {
      whereClause.city = city_filter;
    } else if (childCity) {
      whereClause.city = childCity;
    }

    console.log('🔍 Fetching institutions with filter:', whereClause);
    console.log('📍 Parent location data:', parentLocation);
    console.log('🎯 Target conditions for matching:', targetConditions);

    const institutions = await Institution.findAll({
      where: whereClause,
      attributes: [
        'institution_id', 
        'name', 
        'description', 
        'location',
        'city',
        'region',
        'location_lat',
        'location_lng',
        'location_address',
        'contact_info',
        'website'
      ]
    });

    console.log(`🏫 Found ${institutions.length} institutions`);

    const institutionIds = institutions.map(i => i.institution_id);
    const sessionTypes = await SessionType.findAll({
      where: { institution_id: institutionIds },
      include: [
        { 
          model: Institution, 
          attributes: ['institution_id'] 
        }
      ]
    });

    console.log(`📊 Found ${sessionTypes.length} session types`);

    const sessionTypesByInstitution = {};
    sessionTypes.forEach(st => {
      const instId = st.institution_id;
      if (!sessionTypesByInstitution[instId]) {
        sessionTypesByInstitution[instId] = [];
      }
      sessionTypesByInstitution[instId].push(st);
    });

    const scoredInstitutions = await Promise.all(
      institutions.map(async (institution) => {
        const instData = institution.get({ plain: true });
        const instSessionTypes = sessionTypesByInstitution[instData.institution_id] || [];

        let matchScore = 0;
        let matchingSpecialties = [];
        let matchingSessionTypes = [];
        let matchingReasons = []; // ✅ أسباب التطابق

        console.log(`\n🔍 Analyzing institution: ${instData.name}`);
        console.log(`   📍 Location: ${instData.city}, ${instData.region}`);
        console.log(`   📞 Contact: ${instData.contact_info}`);
        console.log(`   🌐 Website: ${instData.website}`);

        instSessionTypes.forEach(st => {
          const stConditions = st.target_conditions || [];
          const stSpecialization = st.specialist_specialization || '';

          let conditionMatch = false;
          let matchDetails = [];
          
          targetConditions.forEach(tc => {
            const targetLower = tc.toLowerCase();
            
            // Check conditions match
            if (stConditions.some(stc => {
              if (!stc) return false;
              const stcLower = stc.toLowerCase();
              if (stcLower.includes(targetLower) || targetLower.includes(stcLower)) {
                matchDetails.push(`✅ Matches condition: "${stc}" with target "${tc}"`);
                return true;
              }
              return false;
            })) {
              conditionMatch = true;
            }
            
            // Check specialization match
            if (stSpecialization.toLowerCase().includes(targetLower)) {
              conditionMatch = true;
              matchDetails.push(`✅ Matches specialization: "${stSpecialization}" with target "${tc}"`);
            }
          });

          if (conditionMatch) {
            matchScore += 0.3;
            if (!matchingSpecialties.includes(st.category)) {
              matchingSpecialties.push(st.category);
            }
            matchingSessionTypes.push({
              name: st.name,
              category: st.category,
              price: parseFloat(st.price) || 0,
              duration: st.duration,
              description: st.description || 'No description available'
            });
            
            // ✅ Add matching reasons
            matchDetails.forEach(detail => {
              if (!matchingReasons.includes(detail)) {
                matchingReasons.push(detail);
              }
            });
            
            console.log(`   💼 Service: ${st.name} (${st.category})`);
            console.log(`   💰 Price: ${st.price || 'Free'} | Duration: ${st.duration}`);
            if (st.description) {
              console.log(`   📝 Description: ${st.description}`);
            }
          }
        });

        if (matchingSpecialties.length > 2) {
          matchScore += 0.2;
          matchingReasons.push(`✅ Offers ${matchingSpecialties.length} different specialties`);
        }

        // ✅ Calculate distance using parent location
        let distance = null;
        let distanceReason = '';
        if (parentLocation.lat && parentLocation.lng && instData.location_lat && instData.location_lng) {
          distance = this.calculateDistance(
            parentLocation.lat,
            parentLocation.lng,
            instData.location_lat,
            instData.location_lng
          );
          
          if (distance < 5) {
            distanceReason = `🚗 Very close to you (${distance.toFixed(1)} km)`;
            matchScore += 0.3;
          } else if (distance < 15) {
            distanceReason = `📍 Close to you (${distance.toFixed(1)} km)`;
            matchScore += 0.2;
          } else if (distance < 30) {
            distanceReason = `🗺️ Within reasonable distance (${distance.toFixed(1)} km)`;
            matchScore += 0.1;
          } else {
            distanceReason = `✈️ Further away (${distance.toFixed(1)} km)`;
          }
          
          matchingReasons.push(distanceReason);
          console.log(`   📏 Distance from parent: ${distance.toFixed(1)} km - ${distanceReason}`);
        }

        // Simple city-based matching
        if (childCity && instData.city === childCity) {
          matchScore += 0.2;
          matchingReasons.push(`🏙️ Located in your city (${childCity})`);
          console.log(`   🏙️ Same city as child: ${childCity}`);
        }

        const avgPrice = matchingSessionTypes.length > 0
          ? matchingSessionTypes.reduce((sum, st) => sum + (st.price || 0), 0) / matchingSessionTypes.length
          : 0;

        // Price-based filtering and reasoning
        if (max_price && avgPrice > parseFloat(max_price)) {
          console.log(`   ❌ Excluded: Average price ${avgPrice.toFixed(2)} exceeds max ${max_price}`);
          return null;
        }

        const rating = 4.0 + Math.random();
        let ratingReason = '';
        if (rating >= 4.5) {
          ratingReason = `⭐ Excellent rating (${rating.toFixed(1)}/5)`;
          matchScore += 0.15;
        } else if (rating >= 4.0) {
          ratingReason = `👍 Good rating (${rating.toFixed(1)}/5)`;
          matchScore += 0.1;
        } else {
          ratingReason = `📊 Average rating (${rating.toFixed(1)}/5)`;
        }
        matchingReasons.push(ratingReason);

        if (min_rating && rating < parseFloat(min_rating)) {
          console.log(`   ❌ Excluded: Rating ${rating.toFixed(1)} below minimum ${min_rating}`);
          return null;
        }

        let finalScore = matchScore;
        
        // ✅ Adjust score based on specialization match
        if (matchingSpecialties.length > 0) {
          finalScore += 0.1 * matchingSpecialties.length;
          matchingReasons.push(`🎯 Specialized in ${matchingSpecialties.length} relevant areas`);
        }

        // ✅ Summary for this institution
        console.log(`   📊 FINAL SCORE: ${(finalScore * 100).toFixed(0)}%`);
        console.log(`   🎯 Matching specialties: ${matchingSpecialties.join(', ')}`);
        console.log(`   📋 Matching services: ${matchingSessionTypes.length}`);
        console.log(`   💡 Reasons for recommendation:`);
        matchingReasons.forEach(reason => console.log(`      • ${reason}`));

        return {
          id: instData.institution_id,
          name: instData.name,
          description: instData.description,
          city: instData.city,
          region: instData.region,
          address: instData.location_address,
          contact: instData.contact_info,
          website: instData.website,
          match_score: Math.min(finalScore, 1.0), 
          distance: distance,
          rating: rating.toFixed(1),
          avg_price: avgPrice.toFixed(2),
          matching_specialties: matchingSpecialties,
          available_services: matchingSessionTypes,
          total_services: instSessionTypes.length,
          matching_reasons: matchingReasons, // ✅ أسباب التوصية
          coordinates: {
            lat: instData.location_lat,
            lng: instData.location_lng
          }
        };
      })
    );

    let filteredInstitutions = scoredInstitutions.filter(i => i !== null);

    // ✅ NOW: Sort by distance if available, otherwise by match score
    filteredInstitutions.sort((a, b) => {
      switch(sort_by) {
        case 'distance':
          return (a.distance || 999) - (b.distance || 999);
        case 'rating':
          return parseFloat(b.rating) - parseFloat(a.rating);
        case 'price':
          return parseFloat(a.avg_price) - parseFloat(b.avg_price);
        case 'match_score':
        default:
          if (a.distance !== null && b.distance !== null) {
            const aScore = a.match_score * (a.distance < 10 ? 1.2 : a.distance < 25 ? 1.1 : 1.0);
            const bScore = b.match_score * (b.distance < 10 ? 1.2 : b.distance < 25 ? 1.1 : 1.0);
            return bScore - aScore;
          }
          return b.match_score - a.match_score;
      }
    });

    const offset = (page - 1) * limit;
    const paginatedInstitutions = filteredInstitutions.slice(offset, offset + limit);

    // ✅ FINAL SUMMARY
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🎯 FINAL RECOMMENDATION SUMMARY');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📊 Total institutions analyzed: ${institutions.length}`);
    console.log(`✅ Recommended institutions: ${paginatedInstitutions.length}`);
    console.log(`🎯 Target conditions: ${targetConditions.join(', ')}`);
    console.log(`📍 Parent location: ${parentLocation.lat ? `Lat: ${parentLocation.lat}, Lng: ${parentLocation.lng}` : 'Not available'}`);
    
    console.log('\n🏆 TOP RECOMMENDED INSTITUTIONS:');
    paginatedInstitutions.forEach((inst, index) => {
      console.log(`\n${index + 1}. ${inst.name}`);
      console.log(`   📍 ${inst.city}, ${inst.region}`);
      console.log(`   📊 Match Score: ${(inst.match_score * 100).toFixed(0)}%`);
      console.log(`   📏 Distance: ${inst.distance ? `${inst.distance.toFixed(1)} km` : 'Unknown'}`);
      console.log(`   ⭐ Rating: ${inst.rating}/5`);
      console.log(`   💰 Avg Price: ${inst.avg_price}`);
      console.log(`   🎯 Specialties: ${inst.matching_specialties.join(', ')}`);
      console.log(`   💼 Services: ${inst.available_services.length} matching services`);
      console.log(`   📋 Why we recommend it:`);
      inst.matching_reasons.forEach(reason => console.log(`      • ${reason}`));
      
      // Show available services
      if (inst.available_services.length > 0) {
        console.log(`   🔍 Available services:`);
        inst.available_services.forEach(service => {
          console.log(`      • ${service.name} (${service.category}) - ${service.price || 'Free'} - ${service.duration}`);
          if (service.description && service.description !== 'No description available') {
            console.log(`        📝 ${service.description}`);
          }
        });
      }
    });
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    return {
      institutions: paginatedInstitutions.map(inst => ({
        ...inst,
        match_score: `${(inst.match_score * 100).toFixed(0)}%`,
        distance: inst.distance ? `${inst.distance.toFixed(1)} KM` : 'Unknown',
        // ✅ نضمن أن أسباب التوصية بتكون موجودة في النتيجة
        recommendation_reasons: inst.matching_reasons
      })),
      pagination: {
        page,
        limit,
        total: filteredInstitutions.length,
        total_pages: Math.ceil(filteredInstitutions.length / limit)
      },
      analysis_summary: {
        total_institutions_analyzed: institutions.length,
        recommended_count: paginatedInstitutions.length,
        target_conditions: targetConditions,
        parent_location_available: !!(parentLocation.lat && parentLocation.lng)
      }
    };

  } catch (error) {
    console.error('❌ Error calculating recommendations for screening:', error);
    throw error;
  }
}

  generateScreeningNextSteps(screeningResults, aiAnalysis, recommendedInstitutions) {
    const steps = [];
    const primaryConcern = screeningResults.primary_concern;
    const riskLevel = primaryConcern ? screeningResults.risk_levels[primaryConcern] : null;

    // Urgent steps for high risk
    if (riskLevel === 'high' || riskLevel === 'significant') {
      steps.push(`🚨 URGENT: Immediate evaluation recommended for ${this.getConditionEnglishName(primaryConcern)}`);
      steps.push('📞 Contact specialist within 1-2 weeks');
      steps.push('🩺 Schedule comprehensive developmental assessment');
    }

    // Steps based on primary concern
    if (primaryConcern) {
      if (riskLevel === 'medium' || riskLevel === 'moderate') {
        steps.push(`📋 Recommended: Professional assessment for ${this.getConditionEnglishName(primaryConcern)}`);
        steps.push('👥 Consult with pediatrician or specialist');
        steps.push('📊 Consider formal diagnostic evaluation');
      } else if (riskLevel === 'low') {
        steps.push(`👀 Monitoring recommended for ${this.getConditionEnglishName(primaryConcern)} indicators`);
        steps.push('📝 Continue routine developmental check-ups');
      }
    }

    // Add institution recommendations
    if (recommendedInstitutions.length > 0) {
      const topInstitution = recommendedInstitutions[0];
      steps.push(`🏫 Recommended center: "${topInstitution.name}" in ${topInstitution.city} - Match: ${topInstitution.match_score}`);
      
      if (recommendedInstitutions.length > 1) {
        steps.push(`📍 ${recommendedInstitutions.length - 1} additional suitable centers available`);
      }
    }

    // General next steps
    if (!primaryConcern) {
      steps.push('✅ Child appears to be developing typically for age');
      steps.push('📅 Continue with routine pediatric check-ups');
      steps.push('👀 Monitor development with regular screening');
    } else {
      steps.push('💡 Complete child registration for ongoing support');
      steps.push('📚 Access educational resources and strategies');
      steps.push('👪 Join parent support groups if available');
    }

    // AI analysis insights
    if (aiAnalysis && aiAnalysis.suggested_conditions && aiAnalysis.suggested_conditions.length > 0) {
      const topAICondition = aiAnalysis.suggested_conditions[0];
      if (topAICondition.confidence > 70) {
        steps.push(`🤖 AI suggests: ${topAICondition.name} (${topAICondition.confidence} confidence)`);
      }
    }

    return steps;
  }

  // ========== HELPER METHODS ==========
  getConditionEnglishName(condition) {
    const conditionsMap = {
      'autism': 'Autism Spectrum Disorder',
      'adhd_inattention': 'ADHD - Inattentive Type',
      'adhd_hyperactive': 'ADHD - Hyperactive Type',
      'speech_delay': 'Speech and Language Delay'
    };
    return conditionsMap[condition] || condition;
  }

  generateScreeningSummary(screeningResults) {
    return {
      primary_issue: screeningResults.primary_concern ? 
        this.getConditionEnglishName(screeningResults.primary_concern) : 'No significant concerns',
      overall_risk: this.getOverallRiskLevel(screeningResults),
      confidence: screeningResults.confidence_level || 'medium',
      urgency: this.getUrgencyLevel(screeningResults),
      recommended_actions: this.getRecommendedActions(screeningResults)
    };
  }

  getOverallRiskLevel(screeningResults) {
    if (!screeningResults.primary_concern) return 'low';
    
    const risk = screeningResults.risk_levels[screeningResults.primary_concern];
    if (risk === 'high' || risk === 'significant') return 'high';
    if (risk === 'medium' || risk === 'moderate') return 'medium';
    return 'low';
  }

  getUrgencyLevel(screeningResults) {
    if (!screeningResults.primary_concern) return 'routine';
    
    const risk = screeningResults.risk_levels[screeningResults.primary_concern];
    if (risk === 'high' || risk === 'significant') return 'urgent';
    if (risk === 'medium' || risk === 'moderate') return 'soon';
    return 'routine';
  }

  getRecommendedActions(screeningResults) {
    const actions = [];
    
    if (screeningResults.primary_concern === 'autism') {
      if (screeningResults.risk_levels.autism === 'high') {
        actions.push('Immediate developmental pediatrician evaluation');
        actions.push('Early intervention program enrollment');
        actions.push('Speech and occupational therapy assessment');
      } else {
        actions.push('Developmental monitoring');
        actions.push('Social skills assessment');
      }
    }
    
    if (screeningResults.primary_concern === 'adhd_inattention' || screeningResults.primary_concern === 'adhd_hyperactive') {
      actions.push('Comprehensive ADHD evaluation');
      actions.push('Classroom behavior assessment');
      actions.push('Parent training resources');
    }
    
    if (screeningResults.primary_concern === 'speech_delay') {
      actions.push('Speech-language pathology evaluation');
      actions.push('Language development activities');
      actions.push('Hearing assessment if not done recently');
    }

    return actions.length > 0 ? actions : ['Continue routine developmental surveillance'];
  }

  // Helper function to calculate distance (simplified for screening)
  calculateDistance(lat1, lon1, lat2, lon2) {
    if (!lat1 || !lon1 || !lat2 || !lon2) return null;
    
    const R = 6371; 
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
      Math.sin(dLon/2) * Math.sin(dLon/2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const distance = R * c;
    
    return Number(distance.toFixed(2));
  }
}

module.exports = EnhancedScreeningController;