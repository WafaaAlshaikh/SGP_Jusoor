const Child = require('../model/Child');
const Diagnosis = require('../model/Diagnosis');
const Session = require('../model/Session');
const Institution = require('../model/Institution');
const ChildRegistrationRequest = require('../model/ChildRegistrationRequest');
const SessionType = require('../model/SessionType');
const AIAnalysisService = require('../services/aiAnalysisService');
const ExternalAIService = require('../services/externalAIService');
const GroqAIService = require('../services/groqAIService');
const { Op } = require('sequelize');
const sequelize = require('../config/db');
const GeocodingService = require('../services/geocodingService');

exports.calculateDistance = (lat1, lon1, lat2, lon2) => {
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
};

exports.getChildCoordinates = async (childData) => {
  try {
    if (childData.location_lat && childData.location_lng) {
      return {
        lat: parseFloat(childData.location_lat),
        lng: parseFloat(childData.location_lng)
      };
    }
    
    if (childData.address || childData.city) {
      const addressToGeocode = childData.address || childData.city;
      const coords = await GeocodingService.geocodeAddress(addressToGeocode);
      
      if (coords) {
        await Child.update({
          location_lat: coords.lat,
          location_lng: coords.lng
        }, { where: { child_id: childData.child_id } });
        
        return coords;
      }
    }
    
    console.log('⚠️ No location data available for child:', childData.child_id);
    return null;
    
  } catch (error) {
    console.error('❌Error in obtaining the childs coordinates:', error);
    return null;
  }
};

// ================= STEP 1: Save Basic Information Temporarily =================
exports.saveChildBasicInfo = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { 
      full_name, 
      date_of_birth, 
      gender,
      child_identifier,
      school_info,
      photo,
      city,
      address,
      location_lat,    
      location_lng   
    } = req.body;

    if (!full_name || !date_of_birth || !gender) {
      return res.status(400).json({ 
        success: false,
        message: 'Full name, date of birth, and gender are required fields' 
      });
    }

    const birthDate = new Date(date_of_birth);
    const today = new Date();
    if (birthDate > today) {
      return res.status(400).json({
        success: false,
        message: 'Date of birth cannot be in the future'
      });
    }

    const age = exports.calculateAge(date_of_birth);
    if (age > 18) {
      return res.status(400).json({
        success: false,
        message: 'Age must be less than 18 years'
      });
    }

    let childCoords = null;
    if (location_lat && location_lng) {
      childCoords = { lat: parseFloat(location_lat), lng: parseFloat(location_lng) };
    } else if (address || city) {
      childCoords = await GeocodingService.geocodeAddress(address || city);
    }

    const User = require('../model/User');
    const Parent = require('../model/Parent');
    
    const parent = await Parent.findOne({
      where: { parent_id: parentId },
      include: [{
        model: User,
        attributes: ['phone']
      }]
    });

    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent information not found'
      });
    }

    const tempChild = await Child.create({
      parent_id: parentId,
      full_name,
      date_of_birth,
      gender,
      child_identifier: child_identifier || null,
      address: address || null,
      city: city || null,
      parent_phone: parent.User.phone, 
      school_info: school_info || null,
      photo: photo || '',
      registration_status: 'Not Registered',
      current_institution_id: null,
      location_lat: childCoords ? childCoords.lat : null,
      location_lng: childCoords ? childCoords.lng : null
    });

    res.status(201).json({
      success: true,
      message: 'Basic information saved successfully',
      child_id: tempChild.child_id,
      child_location: childCoords ? {
        address: address,
        city: city,
        coordinates: childCoords
      } : null,
      next_step: 'medical_info'
    });

  } catch (error) {
    console.error('❌ Error saving basic information:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to save information', 
      error: error.message 
    });
  }
};

// ================= STEP 2: Analyze Medical Condition and Return Recommendations =================
exports.analyzeMedicalCondition = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { id } = req.params;
    const { 
      diagnosis_id,
      suspected_condition,
      symptoms_description,
      medical_history,
      previous_services,
      additional_notes
    } = req.body;

    const child = await Child.findOne({
      where: { 
        child_id: id,
        parent_id: parentId 
      }
    });

    if (!child) {
      return res.status(404).json({ 
        success: false,
        message: 'Child not found' 
      });
    }

    let aiAnalysis = null;
    let targetConditions = [];

    if (diagnosis_id) {
      const diagnosis = await Diagnosis.findByPk(diagnosis_id);
      if (diagnosis) targetConditions = [diagnosis.name];
    }

    if (symptoms_description && symptoms_description.trim() !== '') {
      console.log('🤖 Starting AI symptom analysis...');
      console.log('🌐 Trying External AI (GROQ) first...');
      
      aiAnalysis = await GroqAIService.analyzeSymptoms(
        symptoms_description, 
        medical_history || '',
        previous_services || ''
      );

      if (!aiAnalysis || !aiAnalysis.suggested_conditions || aiAnalysis.suggested_conditions.length === 0) {
        console.log('⚠️ External AI failed or returned no results');
        console.log('🔄 Falling back to Local AI...');
        
        aiAnalysis = await AIAnalysisService.analyzeSymptoms(
          symptoms_description, 
          medical_history || '',
          previous_services || ''
        );
        
        if (aiAnalysis) {
          aiAnalysis.source = 'local_ai';
        }
      } else {
        console.log('✅ External AI analysis successful (GROQ)');
        aiAnalysis.source = 'groq_ai';
      }

      if (aiAnalysis && aiAnalysis.suggested_conditions && aiAnalysis.suggested_conditions.length > 0) {
        const aiConditions = aiAnalysis.suggested_conditions
          .filter(c => c.confidence > 0.3)
          .map(c => c.name);
        targetConditions = [...new Set([...targetConditions, ...aiConditions])];
      }
    }

    if (targetConditions.length === 0 && suspected_condition) {
      targetConditions = [suspected_condition];
    }

    await child.update({
      diagnosis_id: diagnosis_id || null,
      suspected_condition: suspected_condition || null,
      symptoms_description: symptoms_description || null,
      medical_history: medical_history || null,
      previous_services: previous_services || null,
      additional_notes: additional_notes || null,
      ai_suggested_diagnosis: aiAnalysis ? aiAnalysis.suggested_conditions : null,
      ai_confidence_score: aiAnalysis ? aiAnalysis.analysis_confidence : null,
      risk_level: aiAnalysis ? aiAnalysis.risk_level : null
    });

    const recommendedInstitutions = await exports.getRecommendedInstitutions(
      id,
      targetConditions,
      child.city,
      child.address
    );

    res.status(200).json({
      success: true,
      message: 'Medical condition analyzed successfully',
      analysis: aiAnalysis ? {
        suggested_conditions: aiAnalysis.suggested_conditions.map(c => ({
          name: c.arabic_name || c.name,
          confidence: `${(c.confidence * 100).toFixed(1)}%`,
          matching_keywords: c.matching_keywords
        })),
        risk_level: aiAnalysis.risk_level,
        analyzed_keywords: aiAnalysis.analyzed_keywords
      } : null,
      target_conditions: targetConditions,
      recommended_institutions: recommendedInstitutions,
      next_step: 'select_institution'
    });

  } catch (error) {
    console.error('❌ Error analyzing medical condition:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to analyze medical condition', 
      error: error.message 
    });
  }
};

// ================= STEP 3: Get Institutions with Filters =================
exports.getInstitutionsWithFilters = async (req, res) => {
  try {
    const { id } = req.params;
    const parentId = req.user.user_id;
    const {
      sort_by = 'match_score', 
      city_filter,
      specialization_filter,
      max_distance, 
      min_rating,
      max_price,
      page = 1,
      limit = 10
    } = req.query;

    const child = await Child.findOne({
      where: { 
        child_id: id,
        parent_id: parentId 
      }
    });

    if (!child) {
      return res.status(404).json({ 
        success: false,
        message: 'Child not found' 
      });
    }

    let targetConditions = [];
    if (child.diagnosis_id) {
      const diagnosis = await Diagnosis.findByPk(child.diagnosis_id);
      if (diagnosis) targetConditions.push(diagnosis.name);
    }
    if (child.ai_suggested_diagnosis) {
      const aiConditions = child.ai_suggested_diagnosis
        .filter(c => c.confidence > 0.3)
        .map(c => c.name);
      targetConditions = [...new Set([...targetConditions, ...aiConditions])];
    }

    const institutions = await exports.getRecommendedInstitutions(
      id,
      targetConditions,
      child.city,
      child.address,
      {
        sort_by,
        city_filter,
        specialization_filter,
        max_distance,
        min_rating,
        max_price,
        page: parseInt(page),
        limit: parseInt(limit)
      }
    );

    res.status(200).json({
      success: true,
      data: institutions.institutions,
      pagination: institutions.pagination,
      filters_applied: {
        sort_by,
        city_filter,
        specialization_filter,
        max_distance,
        min_rating,
        max_price
      }
    });

  } catch (error) {
    console.error('❌ Error fetching institutions:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to fetch institutions', 
      error: error.message 
    });
  }
};

// ================= STEP 4: Request Institution Registration =================
exports.requestInstitutionRegistration = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const child_id = req.params.id;
    const { institution_id, notes, consent_given } = req.body;

    console.log('🔍 Request registration data:', {
      parentId,
      child_id, 
      institution_id
    });

    if (!child_id || !institution_id) {
      return res.status(400).json({ 
        success: false,
        message: 'Child ID and Institution ID are required'
      });
    }

    const child = await Child.findOne({
      where: { 
        child_id: child_id,
        parent_id: parentId 
      }
    });

    if (!child) {
      return res.status(404).json({ 
        success: false,
        message: 'Child not found' 
      });
    }

    const existingRequest = await ChildRegistrationRequest.findOne({
      where: { 
        child_id: child_id, 
        institution_id: institution_id,
        status: 'Pending' 
      }
    });

    if (existingRequest) {
      return res.status(400).json({ 
        success: false,
        message: 'There is already a pending registration request for this institution' 
      });
    }

    const request = await ChildRegistrationRequest.create({
      child_id: child_id,
      institution_id: institution_id,
      requested_by_parent_id: parentId,
      status: 'Pending',
      notes: notes || null
    });

    await child.update({ 
      registration_status: 'Pending',
      consent_given: consent_given || false
    });

    const institution = await Institution.findByPk(institution_id);

    res.status(201).json({ 
      success: true,
      message: 'Registration request submitted successfully',
      request_id: request.request_id,
      status: 'Pending',
      institution: {
        id: institution.institution_id,
        name: institution.name
      },
      next_steps: [
        'The request will be reviewed by the institution administration',
        'You will receive a notification when the request is approved',
        'You can track request status from your dashboard'
      ]
    });

  } catch (error) {
    console.error('❌ Error requesting registration:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to submit registration request', 
      error: error.message 
    });
  }
};

// ================= Helper Function: Calculate Recommendations =================
exports.getRecommendedInstitutions = async (
  childId, 
  targetConditions, 
  childCity, 
  childAddress,
  filters = {}
) => {
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

    const child = await Child.findByPk(childId);
    if (!child) {
      throw new Error('Child not found');
    }

    let whereClause = {};
    if (city_filter) {
      whereClause.city = city_filter;
    }

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

        let distance = null;
        let childCoords = null;

        if (childAddress || childCity) {
          childCoords = await exports.getChildCoordinates({
            child_id: childId,
            address: childAddress,
            city: childCity,
            location_lat: child.location_lat,
            location_lng: child.location_lng
          });
        }

        if (childCoords && instData.location_lat && instData.location_lng) {
          distance = exports.calculateDistance(
            childCoords.lat,
            childCoords.lng,
            instData.location_lat,
            instData.location_lng
          );
          console.log(`📍 The distance between the child and the institution ${instData.name}: ${distance} كم`);
        }

        if (max_distance && distance && distance > parseFloat(max_distance)) {
          console.log(`❌ The institution has been excluded ${instData.name} - Distance ${distance}km bigger than${max_distance}Km`);
          return null;
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
        if (distance) {
          finalScore += Math.max(0, (50 - distance) / 50) * 0.3;
        }
        if (instData.city === childCity) {
          finalScore += 0.2;
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
          return b.match_score - a.match_score;
      }
    });

    const offset = (page - 1) * limit;
    const paginatedInstitutions = filteredInstitutions.slice(offset, offset + limit);

    return {
      institutions: paginatedInstitutions.map(inst => ({
        ...inst,
        match_score: `${(inst.match_score * 100).toFixed(0)}%`,
        distance: inst.distance ? `${inst.distance} KM` : 'Uncalculated'
      })),
      pagination: {
        page,
        limit,
        total: filteredInstitutions.length,
        total_pages: Math.ceil(filteredInstitutions.length / limit)
      }
    };

  } catch (error) {
    console.error('❌ Error calculating recommendations:', error);
    throw error;
  }
};

// ================= Helper Function: Calculate Age =================
exports.calculateAge = (dateOfBirth) => {
  if (!dateOfBirth) return 0;
  const birthDate = new Date(dateOfBirth);
  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  return age;
};

// ================= GET CHILDREN =================
exports.getChildren = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const {
      search = '',
      gender,
      diagnosis, 
      sort = 'name', 
      order = 'asc',
      page = '1',
      limit = '50',
    } = req.query;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const pageLimit = Math.max(1, parseInt(limit, 10) || 50);
    const offset = (pageNum - 1) * pageLimit;

    const where = { parent_id: parentId, deleted_at: null };

    if (search && search.trim() !== '') {
      where.full_name = { [Op.like]: `%${search.trim()}%` };
    }

    if (gender && (gender === 'Male' || gender === 'Female')) {
      where.gender = gender;
    }

    let include = [
      {
        model: Diagnosis,
        attributes: ['name'],
        as: 'ChildDiagnosis',
        required: false
      },
      {
        model: Institution,
        as: 'CurrentInstitution',
        attributes: ['institution_id', 'name'],
        required: false
      }
    ];

    if (diagnosis && diagnosis !== 'All') {
      if (isNaN(parseInt(diagnosis, 10))) {
        include = [
          {
            model: Diagnosis,
            attributes: ['name'],
            as: 'ChildDiagnosis',
            required: true,
            where: { name: diagnosis }
          },
          {
            model: Institution,
            as: 'CurrentInstitution',
            attributes: ['institution_id', 'name'],
            required: false
          }
        ];
      } else {
        where.diagnosis_id = parseInt(diagnosis, 10);
      }
    }

    let orderArray = [];
    if (sort === 'age') {
      orderArray.push(['date_of_birth', order === 'asc' ? 'ASC' : 'DESC']);
    } else if (sort === 'lastSession') {
      orderArray.push(['date_of_birth', 'ASC']);
    } else {
      orderArray.push(['full_name', order === 'asc' ? 'ASC' : 'DESC']);
    }

    const children = await Child.findAll({
      where,
      include,
      offset,
      limit: pageLimit,
      order: orderArray
    });

    const processedChildren = await Promise.all(children.map(async (child) => {
      const childData = child.get({ plain: true });

      let age = exports.calculateAge(childData.date_of_birth);

      const lastSession = await Session.findOne({
        where: { child_id: childData.child_id },
        order: [['date', 'DESC']],
        limit: 1
      });

      return {
        id: childData.child_id,
        full_name: childData.full_name,
        date_of_birth: childData.date_of_birth,
        gender: childData.gender,
        diagnosis_id: childData.diagnosis_id,
        photo: childData.photo || '',
        medical_history: childData.medical_history || '',
        condition: childData.Diagnosis ? childData.Diagnosis.name : null,
        age: age,
        last_session_date: lastSession ? lastSession.date : null,
        status: 'Active',
        registration_status: childData.registration_status || 'Not Registered',
        current_institution_id: childData.current_institution_id,
        institution_id: childData.institution_id,
        current_institution_name: childData.currentInstitution ? childData.currentInstitution.name : null,
        risk_level: childData.risk_level,
        ai_confidence_score: childData.ai_confidence_score
      };
    }));

    res.status(200).json({
      data: processedChildren,
      meta: {
        page: pageNum,
        limit: pageLimit,
        returned: processedChildren.length
      }
    });

  } catch (error) {
    console.error('Error fetching children:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};
exports.addChild = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { 
      full_name, 
      date_of_birth, 
      gender, 
      diagnosis_id,
      suspected_condition,
      symptoms_description,
      medical_history,
      location_preference,
      photo,
      child_identifier,
      city,
      address,
      parent_phone,
      school_info,
      previous_services,
      additional_notes,
      consent_given,
      location_lat,   
      location_lng    
    } = req.body;

    if (!full_name || !date_of_birth || !gender) {
      return res.status(400).json({ 
        success: false,
        message: 'Full name, date of birth, and gender are required fields' 
      });
    }

    const birthDate = new Date(date_of_birth);
    const today = new Date();
    if (birthDate > today) {
      return res.status(400).json({
        success: false,
        message: 'The date of birth cannot be in the future.'
      });
    }

    const age = exports.calculateAge(date_of_birth);
    if (age > 18) {
      return res.status(400).json({
        success: false,
        message: 'Age must be under 18 years'
      });
    }

    let childCoords = null;
    if (location_lat && location_lng) {
      childCoords = { lat: parseFloat(location_lat), lng: parseFloat(location_lng) };
      console.log('📍Direct coordinates were received:', childCoords);
    } else if (address || city) {
      childCoords = await GeocodingService.geocodeAddress(address || city);
      console.log('📍Coordinates were obtained from Geocoding:', childCoords);
    }

    let aiAnalysis = null;
    let recommendedInstitutions = [];

    if (symptoms_description && symptoms_description.trim() !== '') {
      console.log('🤖 Starting to analyze symptoms using artificial intelligence...');
      aiAnalysis = await AIAnalysisService.analyzeSymptoms(
        symptoms_description, 
        medical_history || ''
      );
      console.log('✅ The artificial intelligence analysis is complete.:', aiAnalysis);

      if (aiAnalysis && aiAnalysis.suggested_conditions && aiAnalysis.suggested_conditions.length > 0) {
        console.log('🏫 Search for recommended institutions...');
        recommendedInstitutions = await exports.getRecommendedInstitutions(
          null,
          aiAnalysis.suggested_conditions.map(c => c.name),
          city,
          address
        );
      }
    }

    const newChild = await Child.create({
      parent_id: parentId,
      full_name,
      date_of_birth,
      gender,
      diagnosis_id: diagnosis_id || null,
      suspected_condition: suspected_condition || null,
      symptoms_description: symptoms_description || null,
      medical_history: medical_history || '',
      photo: photo || '',
      
      ai_suggested_diagnosis: aiAnalysis ? aiAnalysis.suggested_conditions : null,
      ai_confidence_score: aiAnalysis ? aiAnalysis.analysis_confidence : null,
      risk_level: aiAnalysis ? aiAnalysis.risk_level : null,

      child_identifier: child_identifier || null,
      city: city || null,
      address: address || null,
      parent_phone: parent_phone || null,
      school_info: school_info || null,
      previous_services: previous_services || null,
      additional_notes: additional_notes || null,
      consent_given: consent_given || false,

      location_lat: childCoords ? childCoords.lat : null,
      location_lng: childCoords ? childCoords.lng : null,

      registration_status: 'Not Registered',
      current_institution_id: null
    });

    const response = {
      success: true,
      message: 'The child has been successfully added',
      child_id: newChild.child_id,
      child_data: {
        id: newChild.child_id,
        full_name: newChild.full_name,
        age: exports.calculateAge(date_of_birth),
        gender: newChild.gender
      }
    };

    if (aiAnalysis) {
      response.ai_analysis = {
        suggested_conditions: aiAnalysis.suggested_conditions.map(condition => ({
          name: condition.arabic_name || condition.name,
          confidence: `${(condition.confidence * 100).toFixed(1)}%`,
          matching_keywords: condition.matching_keywords
        })),
        risk_level: aiAnalysis.risk_level,
        analyzed_keywords: aiAnalysis.analyzed_keywords
      };
    }

    if (recommendedInstitutions && recommendedInstitutions.institutions && recommendedInstitutions.institutions.length > 0) {
      response.recommended_institutions = recommendedInstitutions.institutions.map(inst => ({
        id: inst.id,
        name: inst.name,
        city: inst.city,
        match_score: inst.match_score,
        specialties: inst.matching_specialties
      }));
    }

    response.next_steps = exports.generateNextSteps(aiAnalysis, recommendedInstitutions?.institutions || []);

    res.status(201).json(response);

  } catch (error) {
    console.error('❌ Error adding child:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to add child', 
      error: error.message 
    });
  }
};

// ================= توليد الخطوات التالية الذكية =================
exports.generateNextSteps = (aiAnalysis, institutions) => {
  const steps = [];

  if (!aiAnalysis || !aiAnalysis.suggested_conditions || aiAnalysis.suggested_conditions.length === 0) {
    steps.push('We recommend consulting a child development specialist for a comprehensive assessment');
    return steps;
  }

  const topCondition = aiAnalysis.suggested_conditions[0];
  
  if (topCondition.confidence > 0.7) {
    steps.push(`بBased on the analysis, we recommend consulting a specialist.${topCondition.arabic_name || topCondition.name} بشكل عاجل`);
  } else if (topCondition.confidence > 0.4) {
    steps.push('There are indications of${topCondition.arabic_name || topCondition.name}، We recommend a professional assessment.');
  } else {
    steps.push('We recommend follow-up with a pediatrician to ensure proper growth.');
  }

  if (institutions && institutions.length > 0) {
    const topInstitution = institutions[0];
    steps.push(`You can register in "${topInstitution.name}" (${topInstitution.city}) - agree ${topInstitution.match_score}`);
  }

  steps.push('You can take a preliminary diagnostic questionnaire to obtain a more accurate analysis.');
  steps.push('You can book an assessment session with a specialist.');

  return steps;
};

// ================= GET SINGLE CHILD =================
exports.getChild = async (req, res) => {
  try {
    const childId = req.params.id;
    const parentId = req.user.user_id;

    const child = await Child.findOne({
      where: { 
        child_id: childId,
        parent_id: parentId,
        deleted_at: null 
      },
      include: [
        {
          model: Diagnosis,
          attributes: ['name'],
          as: 'Diagnosis'
        },
        {
          model: Institution,
          as: 'currentInstitution',
          attributes: ['institution_id', 'name'],
          required: false
        }
      ]
    });

    if (!child) {
      return res.status(404).json({ 
        success: false,
        message: 'The child is not present' 
      });
    }

    const age = exports.calculateAge(child.date_of_birth);

    const lastSession = await Session.findOne({
      where: { child_id: childId },
      order: [['date', 'DESC']],
      limit: 1
    });

    const childData = {
      id: child.child_id,
      full_name: child.full_name,
      date_of_birth: child.date_of_birth,
      gender: child.gender,
      diagnosis_id: child.diagnosis_id,
      photo: child.photo || '',
      medical_history: child.medical_history || '',
      condition: child.Diagnosis ? child.Diagnosis.name : null,
      age: age,
      last_session_date: lastSession ? lastSession.date : null,
      status: 'Active',
      registration_status: child.registration_status || 'Not Registered',
      current_institution_id: child.current_institution_id,
      current_institution_name: child.currentInstitution ? child.currentInstitution.name : null,
      
      suspected_condition: child.suspected_condition,
      symptoms_description: child.symptoms_description,
      ai_suggested_diagnosis: child.ai_suggested_diagnosis,
      ai_confidence_score: child.ai_confidence_score,
      risk_level: child.risk_level,

      child_identifier: child.child_identifier,
      city: child.city,
      address: child.address,
      parent_phone: child.parent_phone,
      school_info: child.school_info,
      previous_services: child.previous_services,
      additional_notes: child.additional_notes,
      consent_given: child.consent_given,
      location_lat: child.location_lat,
      location_lng: child.location_lng
    };

    res.status(200).json({
      success: true,
      data: childData
    });

  } catch (error) {
    console.error('Error fetching child:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

// ================= SEARCH BY SYMPTOMS ONLY =================
exports.searchBySymptoms = async (req, res) => {
  try {
    const { symptoms_description, location } = req.body;

    if (!symptoms_description || symptoms_description.trim() === '') {
      return res.status(400).json({ 
        success: false,
        message: 'Description of symptoms required' 
      });
    }

    const analysis = await AIAnalysisService.analyzeSymptoms(symptoms_description);
    const institutions = await exports.getRecommendedInstitutions(
      null,
      analysis.suggested_conditions.map(c => c.name),
      location,
      location
    );

    res.status(200).json({
      success: true,
      symptoms_analysis: {
        suggested_conditions: analysis.suggested_conditions.map(c => ({
          name: c.arabic_name || c.name,
          confidence: (c.confidence * 100).toFixed(1) + '%',
          matching_keywords: c.matching_keywords
        })),
        risk_level: analysis.risk_level,
        analyzed_keywords: analysis.analyzed_keywords
      },
      recommended_institutions: institutions.institutions.map(inst => ({
        id: inst.id,
        name: inst.name,
        city: inst.city,
        match_score: inst.match_score,
        specialties: inst.matching_specialties,
        distance: inst.distance
      })),
      next_steps: exports.generateNextSteps(analysis, institutions.institutions)
    });

  } catch (error) {
    console.error('Error searching by symptoms:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failure to analyze symptoms', 
      error: error.message 
    });
  }
};

// ================= GET REGISTRATION STATUS =================
exports.getRegistrationStatus = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { id } = req.params;

    console.log('Fetching registration status for child:', id);

    const child = await Child.findOne({
      where: { 
        child_id: id, 
        parent_id: parentId,
        deleted_at: null 
      },
      attributes: ['child_id', 'full_name', 'registration_status', 'current_institution_id']
    });

    if (!child) {
      return res.status(404).json({ message: 'Child not found' });
    }

    const registrationRequests = await ChildRegistrationRequest.findAll({
      where: { child_id: id },
      include: [
        {
          model: Institution,
          attributes: ['name', 'institution_id']
        },
        {
          model: require('../model/User'),
          as: 'assignedManager',
          attributes: ['full_name']
        }
      ],
      order: [['requested_at', 'DESC']]
    });

    const response = {
      child_id: child.child_id,
      child_name: child.full_name,
      registration_status: child.registration_status,
      current_institution: child.current_institution_id ? {
        institution_id: child.current_institution_id,
      } : null,
      registration_requests: registrationRequests.map(req => ({
        request_id: req.request_id,
        institution_id: req.institution_id,
        institution_name: req.Institution ? req.Institution.name : 'Unknown',
        status: req.status,
        requested_at: req.requested_at,
        reviewed_at: req.reviewed_at,
        notes: req.notes,
        assigned_manager: req.assignedManager ? req.assignedManager.full_name : null
      }))
    };

    res.status(200).json(response);

  } catch (error) {
    console.error('Error fetching registration status:', error);
    res.status(500).json({ 
      message: 'Failed to fetch registration status', 
      error: error.message 
    });
  }
};

// ================= UPDATE CHILD =================
exports.updateChild = async (req, res) => {
  try {
    const childId = req.params.id;
    const parentId = req.user.user_id;
    const { 
      full_name, 
      date_of_birth, 
      gender, 
      diagnosis_id, 
      photo, 
      medical_history,
      suspected_condition,
      symptoms_description
    } = req.body;

    const child = await Child.findOne({
      where: { 
        child_id: childId,
        parent_id: parentId 
      }
    });

    if (!child) {
      return res.status(404).json({ message: 'Child not found' });
    }

    await child.update({
      full_name: full_name,
      date_of_birth: date_of_birth,
      gender: gender,
      diagnosis_id: diagnosis_id,
      photo: photo || child.photo,
      medical_history: medical_history || child.medical_history,
      suspected_condition: suspected_condition || child.suspected_condition,
      symptoms_description: symptoms_description || child.symptoms_description
    });

    let aiAnalysis = null;
    if (symptoms_description && symptoms_description !== child.symptoms_description) {
      aiAnalysis = await AIAnalysisService.analyzeSymptoms(symptoms_description, medical_history);
      await child.update({
        ai_suggested_diagnosis: aiAnalysis ? aiAnalysis.suggested_conditions : null,
        ai_confidence_score: aiAnalysis ? aiAnalysis.risk_level : null
      });
    }

    const updatedChild = await Child.findByPk(childId, {
      include: [
        {
          model: Diagnosis,
          attributes: ['name'],
          as: 'Diagnosis'
        }
      ]
    });

    let age = 0;
    if (updatedChild.date_of_birth) {
      const birthDate = new Date(updatedChild.date_of_birth);
      const today = new Date();
      age = today.getFullYear() - birthDate.getFullYear();
      const monthDiff = today.getMonth() - birthDate.getMonth();
      if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
        age--;
      }
    }

    const childResponse = {
      id: updatedChild.child_id,
      full_name: updatedChild.full_name,
      date_of_birth: updatedChild.date_of_birth,
      gender: updatedChild.gender,
      diagnosis_id: updatedChild.diagnosis_id,
      photo: updatedChild.photo,
      medical_history: updatedChild.medical_history,
      condition: updatedChild.Diagnosis ? updatedChild.Diagnosis.name : null,
      age: age,
      last_session_date: null,
      status: 'Active',
      registration_status: updatedChild.registration_status || 'Not Registered',
      suspected_condition: updatedChild.suspected_condition,
      symptoms_description: updatedChild.symptoms_description,
      ai_suggested_diagnosis: updatedChild.ai_suggested_diagnosis,
      ai_confidence_score: updatedChild.ai_confidence_score
    };

    res.status(200).json(childResponse);

  } catch (error) {
    console.error('Error updating child:', error);
    res.status(500).json({ 
      message: 'Failed to update child', 
      error: error.message 
    });
  }
};

// ================= DELETE CHILD =================
exports.deleteChild = async (req, res) => {
  try {
    const childId = req.params.id;
    const parentId = req.user.user_id;

    const child = await Child.findOne({
      where: { 
        child_id: childId,
        parent_id: parentId,
        deleted_at: null
      }
    });

    if (!child) {
      return res.status(404).json({ message: 'Child not found or already deleted' });
    }

    await child.update({
      deleted_at: new Date(),
      registration_status: 'Archived'
    });

    res.status(200).json({ 
      message: 'Child archived successfully',
      child_id: childId
    });

  } catch (error) {
    console.error('Error archiving child:', error);
    res.status(500).json({ 
      message: 'Failed to archive child', 
      error: error.message 
    });
  }
};

// ================= GET CHILD STATISTICS =================
exports.getChildStatistics = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const children = await Child.findAll({
      where: { parent_id: parentId, deleted_at: null },
      include: [
        {
          model: Diagnosis,
          attributes: ['name'],
          as: 'Diagnosis'
        }
      ]
    });

    const statistics = {
      totalChildren: children.length,
      byCondition: {},
      byGender: {
        Male: 0,
        Female: 0
      },
      byRegistrationStatus: {
        'Not Registered': 0,
        'Pending': 0,
        'Approved': 0
      },
      activeChildren: children.length
    };

    children.forEach(child => {
      const condition = child.Diagnosis ? child.Diagnosis.name : 'Not Diagnosed';
      statistics.byCondition[condition] = (statistics.byCondition[condition] || 0) + 1;

      if (child.gender) {
        statistics.byGender[child.gender] = (statistics.byGender[child.gender] || 0) + 1;
      }

      const regStatus = child.registration_status || 'Not Registered';
      statistics.byRegistrationStatus[regStatus] = (statistics.byRegistrationStatus[regStatus] || 0) + 1;
    });

    res.status(200).json(statistics);

  } catch (error) {
    console.error('Error fetching child statistics:', error);
    res.status(500).json({ 
      message: 'Failed to fetch statistics', 
      error: error.message 
    });
  }
};

module.exports = exports;