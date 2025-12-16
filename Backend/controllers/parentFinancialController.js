const FinancialAssessmentService = require('../services/financialAssessmentService');
const FinancialAssistanceRequest = require('../model/FinancialAssistanceRequest');
const FreeSessionOffer = require('../model/FreeSessionOffer');

// ==============================================
// 🔄 التقييم المالي العام (جديد) - بدون طفل أو مؤسسة
// ==============================================

exports.initiateGeneralFinancialAssessment = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    
    // Get parent data
    const Parent = require('../model/Parent');
    const parent = await Parent.findOne({
      where: { parent_id: parentId },
      include: [{
        model: require('../model/User'),
        attributes: ['full_name', 'email', 'phone']
      }]
    });
    
    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found'
      });
    }
    
    // Check if parent already has a recent assessment
    const daysSinceLastAssessment = parent.last_financial_assessment ? 
      Math.floor((new Date() - new Date(parent.last_financial_assessment)) / (1000 * 60 * 60 * 24)) : null;
    
    const hasValidAssessment = daysSinceLastAssessment !== null && daysSinceLastAssessment <= 30;
    
    // Prepare financial assessment questions (GENERAL version)
    const assessmentFlow = this.getGeneralFinancialAssessmentQuestions();
    
    res.status(200).json({
      success: true,
      message: 'General financial assessment initiated',
      assessment: {
        flow_id: `gfa_${Date.now()}_${parentId}`,
        type: 'general',
        parent: {
          name: parent.User.full_name,
          email: parent.User.email,
          phone: parent.User.phone
        },
        existing_assessment: hasValidAssessment ? {
          has_assessment: true,
          financial_score: parent.financial_score,
          financial_tier: parent.financial_tier,
          last_assessment: parent.last_financial_assessment,
          days_remaining: 30 - daysSinceLastAssessment
        } : {
          has_assessment: false
        },
        questions: assessmentFlow.questions,
        estimated_time: '3-5 minutes',
        privacy_notice: 'All information is kept confidential and used only for assistance determination',
        purpose: 'This assessment will give you an initial financial tier to understand what assistance you might qualify for',
        next_steps: [
          'Complete the financial assessment questions',
          'Receive your initial financial tier and estimated discount range',
          'Later, you can apply this to specific children and institutions'
        ]
      }
    });
    
  } catch (error) {
    console.error('Error initiating general financial assessment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to initiate financial assessment',
      error: error.message
    });
  }
};

exports.submitGeneralFinancialAssessment = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { responses } = req.body;
    
    // Validate required fields
    if (!responses) {
      return res.status(400).json({
        success: false,
        message: 'Responses are required'
      });
    }
    
    // Get parent
    const Parent = require('../model/Parent');
    const parent = await Parent.findOne({ where: { parent_id: parentId } });
    
    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found'
      });
    }
    
    // Process responses and update parent data
    const updatedParentData = this.processAssessmentResponses(parent, responses);
    await parent.update(updatedParentData);
    
    // Get updated parent
    const updatedParent = await Parent.findOne({ where: { parent_id: parentId } });
    
    // Calculate financial assessment
    const assessment = await FinancialAssessmentService.calculateFinancialScore({
      ...updatedParent.toJSON()
    });
    
    // Update parent with assessment results
    await parent.update({
      financial_score: assessment.financial_score,
      financial_tier: assessment.financial_tier,
      last_financial_assessment: new Date(),
      assessment_notes: 'General assessment completed'
    });
    
    // Get available children for this parent
    const Child = require('../model/Child');
    const children = await Child.findAll({
      where: { parent_id: parentId },
      attributes: ['child_id', 'full_name', 'date_of_birth', 'current_institution_id'],
      include: [{
        model: require('../model/Diagnosis'),
        as: 'Diagnosis',
        attributes: ['name']
      }],
      limit: 10
    });
    
    // Get recommended institutions based on financial tier
    let recommendedInstitutions = [];
    try {
      recommendedInstitutions = await this.getRecommendedInstitutions(
        assessment.financial_tier, 
        assessment.suggested_discount_percentage
      );
    } catch (instError) {
      console.warn('⚠️  Could not load recommended institutions:', instError.message);
      // لا نستخدم بيانات افتراضية، نترك المصفوفة فارغة
    }
    
    // Calculate credibility adjustment
    const credibilityMultiplier = parent.credibility_score ? 
      parent.credibility_score / 100 : 1;
    
    // Prepare the response WITHOUT child/institution selection
    const response = {
      success: true,
      message: 'General financial assessment completed successfully',
      assessment_type: 'general',
      assessment_results: {
        financial_score: assessment.financial_score,
        financial_tier: assessment.financial_tier,
        tier_label: this.getTierLabel(assessment.financial_tier),
        suggested_discount_percentage: assessment.suggested_discount_percentage,
        tier_description: this.getTierDescription(assessment.financial_tier),
        credibility_score: parent.credibility_score || 50,
        credibility_multiplier: credibilityMultiplier.toFixed(2),
        assessment_date: new Date().toISOString(),
        valid_until: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        assessment_id: `ASSESS_${parentId}_${Date.now()}`
      },
      what_this_means: {
        estimated_discount_range: this.getDiscountRange(assessment.financial_tier),
        typical_assistance: this.getTypicalAssistance(assessment.financial_tier),
        documents_required: assessment.suggested_discount_percentage >= 50,
        priority_level: assessment.financial_tier === 'tier_1_critical' ? 'High' : 'Normal',
        financial_health_indicator: this.getFinancialHealthIndicator(assessment.financial_score)
      },
      available_children: children.map(child => ({
        child_id: child.child_id,
        name: child.full_name,
        age: this.calculateAge(child.date_of_birth),
        condition: child.Diagnosis?.name || 'Not specified',
        has_institution: !!child.current_institution_id
      })),
      recommended_institutions: recommendedInstitutions,
      next_actions: [
        {
          id: 'select_child',
          action: 'select_child_for_assistance',
          label: 'Select a Child for Assistance',
          description: 'Apply your financial assessment to a specific child',
          icon: '👶',
          available: children.length > 0,
          endpoint: '/api/financial/assessment/apply-to-child'
        },
        {
          id: 'browse_institutions',
          action: 'browse_institutions',
          label: 'Browse Available Institutions',
          description: 'See institutions that match your financial profile',
          icon: '🏥',
          endpoint: '/api/institutions?financial_tier=' + assessment.financial_tier
        },
        {
          id: 'save_assessment',
          action: 'save_assessment',
          label: 'Save Assessment Results',
          description: 'Your assessment is valid for 30 days',
          icon: '💾',
          endpoint: '/api/financial/assessment/save'
        },
        {
          id: 'download_summary',
          action: 'download_summary',
          label: 'Download Assessment Summary',
          description: 'PDF summary of your financial assessment',
          icon: '📄',
          endpoint: '/api/financial/assessment/summary/pdf'
        }
      ],
      quick_stats: {
        total_children: children.length,
        children_with_institutions: children.filter(c => c.current_institution_id).length,
        average_discount_for_tier: this.getAverageDiscountForTier(assessment.financial_tier),
        estimated_monthly_savings: await this.estimateMonthlySavings(parentId, assessment.suggested_discount_percentage)
      }
    };
    
    res.status(200).json(response);
    
  } catch (error) {
    console.error('Error submitting general financial assessment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to submit financial assessment',
      error: error.message
    });
  }
};

exports.applyFinancialAssessmentToChild = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { 
      child_id, 
      institution_id,
      use_existing_assessment = true
    } = req.body;
    
    // Validate required fields
    if (!child_id || !institution_id) {
      return res.status(400).json({
        success: false,
        message: 'Child ID and Institution ID are required'
      });
    }
    
    // Get parent with financial assessment
    const Parent = require('../model/Parent');
    const parent = await Parent.findOne({
      where: { parent_id: parentId },
      include: [{
        model: require('../model/User'),
        attributes: ['full_name']
      }]
    });
    
    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found'
      });
    }
    
    // Check if parent has financial assessment
    if (!parent.financial_score || !parent.last_financial_assessment) {
      return res.status(400).json({
        success: false,
        message: 'Please complete a financial assessment first',
        action_required: 'complete_financial_assessment',
        redirect_to: '/api/financial/assessment/general/initiate'
      });
    }
    
    // Check if assessment is still valid (within 30 days)
    const assessmentAge = new Date() - new Date(parent.last_financial_assessment);
    const daysSinceAssessment = Math.floor(assessmentAge / (1000 * 60 * 60 * 24));
    
    if (daysSinceAssessment > 30 && use_existing_assessment) {
      return res.status(400).json({
        success: false,
        message: 'Your financial assessment has expired (older than 30 days)',
        action_required: 'renew_assessment',
        days_expired: daysSinceAssessment - 30,
        redirect_to: '/api/financial/assessment/general/renew'
      });
    }
    
    // Get child data
    const Child = require('../model/Child');
    const child = await Child.findOne({
      where: {
        child_id,
        parent_id: parentId
      },
      include: [{
        model: require('../model/Diagnosis'),
        as: 'Diagnosis',
        attributes: ['name']
      }]
    });
    
    if (!child) {
      return res.status(404).json({
        success: false,
        message: 'Child not found or not authorized'
      });
    }
    
    // Check if child is registered at the institution
    if (child.current_institution_id !== parseInt(institution_id)) {
      return res.status(400).json({
        success: false,
        message: 'Child is not registered at this institution',
        current_institution: child.current_institution_id,
        requested_institution: institution_id
      });
    }
    
    // Get institution session costs
    const SessionType = require('../model/SessionType');
    const sessionTypes = await SessionType.findAll({
      where: {
        institution_id: institution_id,
        approval_status: 'Approved'
      },
      attributes: ['session_type_id', 'name', 'price', 'duration', 'frequency_recommendation'],
      limit: 5
    });
    
    if (sessionTypes.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No approved session types available at this institution'
      });
    }
    
    // Calculate estimated costs
    const estimatedMonthlySessions = 8; // Default: 2 sessions per week
    let totalMonthlyCost = 0;
    let sessionDetails = [];
    
    // Use average price for estimation
    const avgPrice = sessionTypes.reduce((sum, st) => sum + (parseFloat(st.price) || 0), 0) / sessionTypes.length;
    totalMonthlyCost = avgPrice * estimatedMonthlySessions;
    
    sessionDetails = sessionTypes.map(st => ({
      type: st.name,
      price: parseFloat(st.price) || 0,
      duration: st.duration,
      frequency: st.frequency_recommendation || 'Weekly'
    }));
    
    // Get discount based on financial assessment
    const suggestedDiscount = parseFloat(parent.financial_score) >= 40 ? 
      Math.min(100, Math.floor(parent.financial_score * 1.5)) : 0;
    
    // Adjust discount based on child's condition severity
    const severityMultiplier = this.getSeverityMultiplier(child.Diagnosis?.severity);
    const adjustedDiscount = Math.min(100, Math.floor(suggestedDiscount * severityMultiplier));
    
    // Determine if documents are required
    const requiresDocuments = adjustedDiscount >= 50 &&
      parent.financial_tier !== 'tier_5_no_assistance';
    
    // Get institution information
    const Institution = require('../model/Institution');
    const institution = await Institution.findByPk(institution_id, {
      attributes: ['name', 'city', 'services_offered', 'average_session_price']
    });
    
    // Prepare response
    const response = {
      success: true,
      message: 'Financial assessment applied successfully',
      assessment_type: 'applied',
      parent_assessment: {
        financial_score: parent.financial_score,
        financial_tier: parent.financial_tier,
        tier_label: this.getTierLabel(parent.financial_tier),
        assessment_date: parent.last_financial_assessment,
        days_valid: 30 - daysSinceAssessment,
        expires_on: new Date(Date.now() + (30 - daysSinceAssessment) * 24 * 60 * 60 * 1000).toISOString()
      },
      child_info: {
        child_id: child.child_id,
        name: child.full_name,
        condition: child.Diagnosis?.name || 'Not specified',
        severity: child.Diagnosis?.severity || 'Medium',
        age: this.calculateAge(child.date_of_birth),
        urgency_level: this.determineChildUrgencyFromData(child, null)
      },
      institution_info: {
        institution_id: institution_id,
        name: institution?.name || 'Unknown',
        city: institution?.city || 'Unknown',
        services_offered: institution?.services_offered || 'غير محدد',
        average_session_price: avgPrice.toFixed(2),
        available_session_types: sessionTypes.length,
        estimated_processing_days: this.estimateProcessingTime(institution, parent.financial_tier)
      },
      financial_analysis: {
        estimated_monthly_cost_before_discount: totalMonthlyCost.toFixed(2),
        suggested_discount_percentage: adjustedDiscount,
        estimated_monthly_cost_after_discount: (totalMonthlyCost * (1 - adjustedDiscount / 100)).toFixed(2),
        monthly_savings: (totalMonthlyCost * (adjustedDiscount / 100)).toFixed(2),
        estimated_sessions_per_month: estimatedMonthlySessions,
        cost_per_session_before: avgPrice.toFixed(2),
        cost_per_session_after: (avgPrice * (1 - adjustedDiscount / 100)).toFixed(2),
        yearly_savings: ((totalMonthlyCost * (adjustedDiscount / 100)) * 12).toFixed(2)
      },
      session_details: sessionDetails,
      documents_required: requiresDocuments,
      documents_info: requiresDocuments ? {
        types_required: this.getRequiredDocumentTypes(parent.financial_tier, adjustedDiscount),
        deadline_days: 14,
        upload_instructions: 'Upload clear photos or scans of required documents'
      } : null,
      next_steps: [
        {
          action: 'request_assistance',
          label: 'Request Financial Assistance',
          description: `Formally request ${adjustedDiscount}% discount for ${child.full_name}`,
          priority: 'high',
          endpoint: '/api/financial/assistance/request',
          payload_template: {
            child_id: child_id,
            institution_id: institution_id,
            assessment_type: 'applied',
            requested_sessions_count: estimatedMonthlySessions,
            requested_discount_percentage: adjustedDiscount
          }
        },
        ...(requiresDocuments ? [{
          action: 'upload_documents',
          label: 'Upload Supporting Documents',
          description: 'Required for discount approval',
          priority: 'medium',
          endpoint: '/api/financial/documents/prepare',
          estimated_time: '10-15 minutes'
        }] : []),
        {
          action: 'schedule_consultation',
          label: 'Schedule Free Consultation',
          description: 'Discuss treatment plan with institution',
          priority: 'medium',
          endpoint: '/api/consultation/schedule'
        },
        {
          action: 'compare_options',
          label: 'Compare Other Institutions',
          description: 'See if other institutions offer better rates',
          priority: 'low',
          endpoint: '/api/institutions/compare?child_id=' + child_id
        }
      ],
      disclaimer: 'Discount percentage is an estimate. Final approval is at the discretion of the institution.'
    };
    
    res.status(200).json(response);
    
  } catch (error) {
    console.error('Error applying financial assessment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to apply financial assessment',
      error: error.message
    });
  }
};

exports.initiateFinancialAssessment = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { child_id, institution_id } = req.body;
    
    if (!child_id || !institution_id) {
      return res.status(400).json({
        success: false,
        message: 'Child ID and Institution ID are required'
      });
    }
    
    // Get parent data
    const Parent = require('../model/Parent');
    const parent = await Parent.findOne({
      where: { parent_id: parentId },
      include: [{
        model: require('../model/User'),
        attributes: ['full_name', 'email', 'phone']
      }]
    });
    
    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found'
      });
    }
    
    // Get child data
    const Child = require('../model/Child');
    const child = await Child.findOne({
      where: {
        child_id,
        parent_id: parentId
      },
      include: [{
        model: require('../model/Diagnosis'),
        as: 'Diagnosis',
        attributes: ['name']
      }]
    });
    
    if (!child) {
      return res.status(404).json({
        success: false,
        message: 'Child not found or not authorized'
      });
    }
    
    // Check if child is registered at the institution
    if (child.current_institution_id !== parseInt(institution_id)) {
      return res.status(400).json({
        success: false,
        message: 'Child is not registered at this institution'
      });
    }
    
    // Prepare financial assessment questions
    const assessmentFlow = this.getFinancialAssessmentQuestions(parent);
    
    res.status(200).json({
      success: true,
      message: 'Financial assessment initiated',
      assessment: {
        flow_id: `fa_${Date.now()}_${parentId}`,
        type: 'specific',
        parent: {
          name: parent.User.full_name,
          email: parent.User.email,
          phone: parent.User.phone
        },
        child: {
          name: child.full_name,
          condition: child.Diagnosis?.name || 'Not specified'
        },
        questions: assessmentFlow.questions,
        estimated_time: '5-10 minutes',
        privacy_notice: 'All information is kept confidential and used only for assistance determination',
        next_steps: [
          'Complete the financial assessment questions',
          'Review automatic discount recommendation',
          'Submit formal assistance request if needed',
          'Upload supporting documents if requested'
        ]
      }
    });
    
  } catch (error) {
    console.error('Error initiating financial assessment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to initiate financial assessment',
      error: error.message
    });
  }
};

exports.submitFinancialAssessment = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { 
      child_id, 
      institution_id,
      responses,
      skip_documents = false
    } = req.body;
    
    // Validate required fields
    if (!child_id || !institution_id || !responses) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields'
      });
    }
    
    // Update parent information with responses
    const Parent = require('../model/Parent');
    const parent = await Parent.findOne({ where: { parent_id: parentId } });
    
    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found'
      });
    }
    
    // Process responses and update parent data
    const updatedParentData = this.processAssessmentResponses(parent, responses);
    await parent.update(updatedParentData);
    
    // Get updated parent data
    const updatedParent = await Parent.findOne({ where: { parent_id: parentId } });
    
    // Calculate financial assessment
    const assessment = await FinancialAssessmentService.calculateFinancialScore({
      ...updatedParent.toJSON()
    });
    
    // Update parent with assessment results
    await parent.update({
      financial_score: assessment.financial_score,
      financial_tier: assessment.financial_tier,
      last_financial_assessment: new Date(),
      assessment_notes: 'Specific assessment completed for child: ' + child_id
    });
    
    // Get institution session costs
    const SessionType = require('../model/SessionType');
    const sessionTypes = await SessionType.findAll({
      where: {
        institution_id: institution_id,
        approval_status: 'Approved'
      },
      attributes: ['session_type_id', 'name', 'price', 'duration'],
      limit: 5
    });
    
    // Calculate estimated costs
    const estimatedMonthlySessions = 8; // Default: 2 sessions per week
    let totalMonthlyCost = 0;
    let sessionDetails = [];
    
    if (sessionTypes.length > 0) {
      // Use average price for estimation
      const avgPrice = sessionTypes.reduce((sum, st) => sum + (parseFloat(st.price) || 0), 0) / sessionTypes.length;
      totalMonthlyCost = avgPrice * estimatedMonthlySessions;
      
      sessionDetails = sessionTypes.map(st => ({
        type: st.name,
        price: parseFloat(st.price) || 0,
        duration: st.duration
      }));
    }
    
    // Determine if documents are required
    const suggestedDiscount = parseFloat(assessment.suggested_discount_percentage) || 0;
    const requiresDocuments = !skip_documents && 
      suggestedDiscount >= 50 &&
      assessment.financial_tier !== 'tier_5_no_assistance';
    
    // Prepare response
    const response = {
      success: true,
      message: 'Financial assessment completed successfully',
      assessment_type: 'specific',
      assessment_results: {
        financial_score: assessment.financial_score,
        financial_tier: assessment.financial_tier,
        tier_label: this.getTierLabel(assessment.financial_tier),
        suggested_discount_percentage: suggestedDiscount,
        credibility_score: parent.credibility_score || 50,
        assessment_date: new Date().toISOString()
      },
      financial_snapshot: {
        estimated_monthly_cost_before_discount: totalMonthlyCost.toFixed(2),
        estimated_monthly_cost_after_discount: (totalMonthlyCost * (1 - suggestedDiscount / 100)).toFixed(2),
        monthly_savings: (totalMonthlyCost * (suggestedDiscount / 100)).toFixed(2),
        estimated_sessions_per_month: estimatedMonthlySessions,
        session_details: sessionDetails
      },
      next_actions: [
        {
          action: 'request_assistance',
          label: 'Request Financial Assistance',
          description: `Formally request ${suggestedDiscount}% discount`,
          priority: 'high'
        },
        ...(requiresDocuments ? [{
          action: 'upload_documents',
          label: 'Upload Supporting Documents',
          description: 'Required for discount approval',
          priority: 'medium'
        }] : []),
        {
          action: 'payment_plan',
          label: 'Setup Payment Plan',
          description: 'Spread payments over time',
          priority: 'low'
        },
        {
          action: 'contact_institution',
          label: 'Contact Institution Directly',
          description: 'Discuss alternative options',
          priority: 'low'
        }
      ],
      documents_required: requiresDocuments,
      estimated_processing_time: requiresDocuments ? '5-7 business days' : '2-3 business days'
    };
    
    res.status(200).json(response);
    
  } catch (error) {
    console.error('Error submitting financial assessment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to submit financial assessment',
      error: error.message
    });
  }
};

exports.requestFinancialAssistance = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const {
      child_id,
      institution_id,
      assessment_type = 'general', // 'general' or 'specific'
      requested_sessions_count = 8,
      urgency_reason,
      documents = [],
      use_existing_assessment = true
    } = req.body;
    
    // Get parent with assessment data
    const Parent = require('../model/Parent');
    const parent = await Parent.findOne({
      where: { parent_id: parentId },
      include: [{
        model: require('../model/User'),
        attributes: ['full_name']
      }]
    });
    
    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found'
      });
    }
    
    // Check if parent has financial assessment
    if (!parent.financial_score || !parent.last_financial_assessment) {
      return res.status(400).json({
        success: false,
        message: 'Please complete a financial assessment first',
        redirect_to: '/api/financial/assessment/general/initiate'
      });
    }
    
    // Check if assessment is still valid (within 30 days)
    const assessmentAge = new Date() - new Date(parent.last_financial_assessment);
    const daysSinceAssessment = Math.floor(assessmentAge / (1000 * 60 * 60 * 24));
    
    if (daysSinceAssessment > 30 && use_existing_assessment) {
      return res.status(400).json({
        success: false,
        message: 'Your financial assessment has expired (older than 30 days)',
        redirect_to: '/api/financial/assessment/general/renew'
      });
    }
    
    // Get child data
    const Child = require('../model/Child');
    const child = await Child.findOne({
      where: {
        child_id,
        parent_id: parentId,
        current_institution_id: institution_id
      },
      include: [{
        model: require('../model/Diagnosis'),
        as: 'Diagnosis',
        attributes: ['name']
      }]
    });
    
    if (!child) {
      return res.status(404).json({
        success: false,
        message: 'Child not found or not registered at this institution'
      });
    }
    
    // Calculate estimated cost
    const SessionType = require('../model/SessionType');
    const sessionTypes = await SessionType.findAll({
      where: {
        institution_id: institution_id,
        approval_status: 'Approved'
      },
      attributes: ['price'],
      limit: 3
    });
    
    const avgPrice = sessionTypes.length > 0 ?
      sessionTypes.reduce((sum, st) => sum + (parseFloat(st.price) || 0), 0) / sessionTypes.length :
      50; // Default average price
    
    const totalOriginalCost = avgPrice * requested_sessions_count;
    
    // Determine child urgency
    const childUrgency = this.determineChildUrgencyFromData(child, urgency_reason);
    
    // Calculate discount based on financial score
    const requestedDiscountPercentage = parent.financial_score >= 40 ? 
      Math.min(100, Math.floor(parent.financial_score * 1.5)) : 0;
    
    // Create financial assistance request
    const financialRequest = await FinancialAssistanceRequest.create({
      parent_id: parentId,
      child_id: child_id,
      institution_id: institution_id,
      requested_sessions_count: requested_sessions_count,
      requested_discount_percentage: requestedDiscountPercentage,
      requested_total_amount: totalOriginalCost,
      parent_financial_score: parent.financial_score,
      parent_financial_tier: parent.financial_tier,
      assessment_type: assessment_type, // Track which type of assessment was used
      child_condition_urgency: childUrgency,
      status: 'submitted',
      auto_generated: false,
      requires_documents: parent.financial_tier !== 'tier_5_no_assistance' && documents.length === 0,
      documents_submitted: documents.length > 0 ? documents : null,
      urgency_reason: urgency_reason,
      submitted_at: new Date(),
      estimated_processing_days: parent.financial_tier === 'tier_1_critical' ? 3 : 7
    });
    
    // Send notification to institution managers
    await this.notifyInstitutionManagers(institution_id, financialRequest);
    
    // Prepare response
    const response = {
      success: true,
      message: 'Financial assistance request submitted successfully',
      request_details: {
        request_id: financialRequest.request_id,
        reference_number: `FA-${financialRequest.request_id.toString().padStart(6, '0')}`,
        status: financialRequest.status,
        submitted_date: financialRequest.submitted_at,
        estimated_decision_date: new Date(Date.now() + financialRequest.estimated_processing_days * 24 * 60 * 60 * 1000),
        assessment_type: assessment_type
      },
      financial_summary: {
        requested_sessions: requested_sessions_count,
        requested_discount: `${requestedDiscountPercentage}%`,
        original_monthly_cost: `$${totalOriginalCost.toFixed(2)}`,
        potential_monthly_cost: `$${(totalOriginalCost * (1 - requestedDiscountPercentage / 100)).toFixed(2)}`,
        potential_monthly_savings: `$${(totalOriginalCost * (requestedDiscountPercentage / 100)).toFixed(2)}`
      },
      next_steps: [
        'Your request has been submitted for review',
        financialRequest.requires_documents ? 
          'Please upload required documents to expedite processing' :
          'No additional documents required at this time',
        'You will receive a notification when a decision is made',
        `Average processing time: ${financialRequest.estimated_processing_days} business days`
      ],
      contact_information: {
        institution_contact: await this.getInstitutionContact(institution_id),
        support_email: 'financial-assistance@therapyplatform.com',
        support_phone: '+1-800-HELP-NOW'
      }
    };
    
    res.status(201).json(response);
    
  } catch (error) {
    console.error('Error requesting financial assistance:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to submit financial assistance request',
      error: error.message
    });
  }
};

exports.getGeneralFinancialAssessmentQuestions = () => {
  const questions = [
    {
      id: 'assessment_type',
      type: 'info',
      content: 'This assessment will determine your financial tier and estimated discount range for therapy services.',
      note: 'You can apply this assessment to specific children and institutions later.'
    },
    {
      id: 'monthly_income',
      type: 'range',
      question: 'What is your approximate total monthly household income?',
      description: 'Include all sources of income for all family members',
      options: [
        { value: 'under_300', label: 'Under $300', score_weight: 1.0 },
        { value: '300_600', label: '$300 - $600', score_weight: 0.9 },
        { value: '600_900', label: '$600 - $900', score_weight: 0.8 },
        { value: '900_1200', label: '$900 - $1,200', score_weight: 0.7 },
        { value: '1200_1500', label: '$1,200 - $1,500', score_weight: 0.6 },
        { value: '1500_2000', label: '$1,500 - $2,000', score_weight: 0.5 },
        { value: '2000_3000', label: '$2,000 - $3,000', score_weight: 0.4 },
        { value: '3000_5000', label: '$3,000 - $5,000', score_weight: 0.3 },
        { value: 'over_5000', label: 'Over $5,000', score_weight: 0.1 }
      ],
      required: true,
      privacy_level: 'high'
    },
    {
      id: 'employment_status',
      type: 'select',
      question: 'What is your current employment status?',
      options: [
        { value: 'employed_full_time', label: 'Employed Full-Time', score_weight: 0.2 },
        { value: 'employed_part_time', label: 'Employed Part-Time', score_weight: 0.4 },
        { value: 'self_employed', label: 'Self-Employed', score_weight: 0.3 },
        { value: 'unemployed', label: 'Currently Unemployed', score_weight: 0.9 },
        { value: 'student', label: 'Student', score_weight: 0.7 },
        { value: 'retired', label: 'Retired', score_weight: 0.6 },
        { value: 'disabled', label: 'Disabled', score_weight: 0.8 }
      ],
      required: true
    },
    {
      id: 'family_size',
      type: 'number',
      question: 'How many people live in your household?',
      description: 'Include all family members who live together',
      min: 1,
      max: 15,
      required: true
    },
    {
      id: 'dependents_count',
      type: 'number',
      question: 'How many dependents do you have?',
      description: 'Children, elderly, or others who depend on your income',
      min: 0,
      max: 10,
      required: true
    },
    {
      id: 'special_circumstances',
      type: 'multi_select',
      question: 'Do any of these circumstances apply to your family?',
      options: [
        { value: 'single_parent', label: 'Single Parent Household', score_weight: 0.7 },
        { value: 'widow_widower', label: 'Widow/Widower', score_weight: 0.8 },
        { value: 'divorced', label: 'Recently Divorced/Separated', score_weight: 0.6 },
        { value: 'refugee_displaced', label: 'Refugee/Displaced', score_weight: 0.9 },
        { value: 'low_income_family', label: 'Low-Income Family', score_weight: 0.5 },
        { value: 'special_needs_family_member', label: 'Other Family Member with Special Needs', score_weight: 0.4 },
        { value: 'medical_emergency', label: 'Recent Medical Emergency', score_weight: 0.6 },
        { value: 'none', label: 'None of the above', score_weight: 0.1 }
      ],
      required: true
    },
    {
      id: 'government_support',
      type: 'conditional',
      question: 'Do you receive any government financial support?',
      follow_up: {
        yes: [
          {
            id: 'support_amount',
            type: 'range',
            question: 'Approximate monthly support amount?',
            options: [
              { value: 'under_100', label: 'Under $100' },
              { value: '100_300', label: '$100 - $300' },
              { value: '300_500', label: '$300 - $500' },
              { value: 'over_500', label: 'Over $500' }
            ]
          }
        ]
      },
      required: true
    },
    {
      id: 'monthly_medical_expenses',
      type: 'range',
      question: 'Approximate monthly medical expenses for your family?',
      description: 'Include all family members\' medical expenses',
      options: [
        { value: 'under_100', label: 'Under $100', score_weight: 0.2 },
        { value: '100_300', label: '$100 - $300', score_weight: 0.4 },
        { value: '300_500', label: '$300 - $500', score_weight: 0.6 },
        { value: '500_800', label: '$500 - $800', score_weight: 0.8 },
        { value: 'over_800', label: 'Over $800', score_weight: 1.0 }
      ],
      required: false
    },
    {
      id: 'other_monthly_expenses',
      type: 'range',
      question: 'Other major monthly expenses?',
      description: 'Rent, utilities, loans, etc.',
      options: [
        { value: 'under_500', label: 'Under $500', score_weight: 0.2 },
        { value: '500_1000', label: '$500 - $1,000', score_weight: 0.4 },
        { value: '1000_1500', label: '$1,000 - $1,500', score_weight: 0.6 },
        { value: '1500_2000', label: '$1,500 - $2,000', score_weight: 0.8 },
        { value: 'over_2000', label: 'Over $2,000', score_weight: 1.0 }
      ],
      required: false
    }
  ];
  
  return { 
    questions, 
    total_questions: questions.length,
    note: 'This is a general assessment. Child-specific details will be collected when you apply for assistance.'
  };
};

exports.getRecommendedInstitutions = async (financialTier, discountPercentage) => {
  try {
    const Institution = require('../model/Institution');
    const { Op } = require('sequelize');
    
    // استخدم الحقول الموجودة فقط
    const whereConditions = { 
      is_active: true,
      approval_status: 'Approved'
    };
    
    // 🔹 استبدل financial_aid_available بشرط بديل
    if (financialTier === 'tier_1_critical' || financialTier === 'tier_2_high') {
      // استخدم services_offered بدلاً من financial_aid_available
      whereConditions.services_offered = { 
        [Op.ne]: null,
        [Op.not]: '' 
      };
    }
    
    // جلب المؤسسات
    const institutions = await Institution.findAll({
      where: whereConditions,
      include: [{
        model: require('../model/SessionType'),
        where: { approval_status: 'Approved' },
        required: false,
        attributes: ['price']
      }],
      attributes: [
        'institution_id', 
        'name', 
        'city', 
        'services_offered', // موجود
        'conditions_supported', // موجود
        'price_range', // موجود
        'rating', // موجود
        'capacity', // موجود
        'available_slots' // موجود
      ],
      limit: 6,
      order: [
        ['rating', 'DESC'], // استخدم rating بدلاً من financial_aid_available
        ['available_slots', 'DESC'], // أولوية للأماكن المتاحة
        ['name', 'ASC']
      ]
    });
    
    return institutions.map(inst => {
      const sessionPrices = inst.sessionTypes?.map(st => parseFloat(st.price) || 0) || [];
      const avgPrice = sessionPrices.length > 0 ? 
        sessionPrices.reduce((a, b) => a + b, 0) / sessionPrices.length : 0;
      
      // تحديد المساعدة المالية بناءً على معايير بديلة
      const hasFinancialAid = this.determineFinancialAidAvailability(inst, financialTier);
      
      // تحديد التخصصات من الحقول المتاحة
      const specializations = this.extractSpecializations(inst);
      
      return {
        institution_id: inst.institution_id,
        name: inst.name,
        city: inst.city,
        specializations: specializations,
        financial_aid: hasFinancialAid,
        average_session_price: avgPrice.toFixed(2),
        compatibility_score: this.calculateInstitutionCompatibility(financialTier, inst, hasFinancialAid),
        estimated_discount: this.calculateEstimatedInstitutionDiscount(financialTier, avgPrice),
        processing_time: this.estimateProcessingTime(inst, financialTier)
      };
    });
    
  } catch (error) {
    console.error('⚠️ Error getting recommended institutions:', error.message);
    return []; // إرجاع مصفوفة فارغة بدلاً من بيانات افتراضية
  }
};

exports.determineFinancialAidAvailability = (institution, financialTier) => {
  // معايير بديلة لتحديد المساعدة المالية:
  
  // 1. إذا كان price_range يشير إلى أسعار منخفضة
  if (institution.price_range && (
      institution.price_range.includes('Low') ||
      institution.price_range.includes('low') ||
      institution.price_range.includes('منخفض')
  )) {
    return true;
  }
  
  // 2. إذا كانت المؤسسة لديها خدمات متعددة
  if (institution.services_offered && 
      institution.services_offered.split(',').length >= 3) {
    return true;
  }
  
  // 3. إذا كانت للمستويات العالية فقط
  if ((financialTier === 'tier_1_critical' || financialTier === 'tier_2_high') &&
      institution.capacity > institution.available_slots) {
    return true; // المؤسسة لديها طاقة لاستقبال حالات تحتاج مساعدة
  }
  
  return false; // الافتراضي
};

exports.extractSpecializations = (institution) => {
  if (institution.services_offered) {
    return institution.services_offered;
  }
  
  if (institution.conditions_supported) {
    return institution.conditions_supported;
  }
  
  // استخراج من الاسم إذا كان يحتوي على كلمات دلالية
  const name = institution.name || '';
  const specializationsMap = {
    'نطق': 'علاج النطق واللغة',
    'لغة': 'علاج النطق واللغة',
    'سلوك': 'العلاج السلوكي',
    'وظيفي': 'العلاج الوظيفي',
    'تربية': 'التربية الخاصة',
    'تأهيل': 'التأهيل الشامل',
    'ذوي': 'ذوي الاحتياجات الخاصة',
    'احتياجات': 'ذوي الاحتياجات الخاصة'
  };
  
  for (const [keyword, specialization] of Object.entries(specializationsMap)) {
    if (name.includes(keyword)) {
      return specialization;
    }
  }
  
  return 'خدمات تأهيل وعلاج عامة';
};

exports.calculateInstitutionCompatibility = (financialTier, institution, hasFinancialAid) => {
  let score = 50;
  
  // 1. المساعدة المالية (المقدرة)
  if (hasFinancialAid) score += 20;
  
  // 2. التقييم
  if (institution.rating && institution.rating >= 4.0) score += 15;
  
  // 3. الأماكن المتاحة
  if (institution.available_slots && institution.available_slots > 0) {
    const availabilityRatio = institution.available_slots / (institution.capacity || 10);
    if (availabilityRatio > 0.3) score += 10;
  }
  
  // 4. نطاق السعر
  if (institution.price_range) {
    if (financialTier === 'tier_1_critical' || financialTier === 'tier_2_high') {
      if (institution.price_range.includes('Low') || institution.price_range.includes('منخفض')) {
        score += 15;
      }
    } else {
      if (!institution.price_range.includes('High') && !institution.price_range.includes('مرتفع')) {
        score += 10;
      }
    }
  }
  
  // 5. الخدمات المقدمة
  if (institution.services_offered && institution.services_offered.length > 20) {
    score += 10;
  }
  
  return Math.min(100, Math.max(0, score));
};

exports.estimateProcessingTime = (institution, financialTier) => {
  // تقدير بناءً على عدة عوامل
  let days = 7; // افتراضي
  
  if (financialTier === 'tier_1_critical') {
    days = 3;
  } else if (financialTier === 'tier_2_high') {
    days = 5;
  }
  
  // تعديل حسب التقييم
  if (institution && institution.rating && institution.rating >= 4.5) {
    days -= 1;
  }
  
  // تعديل حسب الأماكن المتاحة
  if (institution && institution.available_slots && institution.available_slots > 5) {
    days -= 1;
  }
  
  return Math.max(2, days); // لا يقل عن يومين
};

exports.calculateEstimatedInstitutionDiscount = (financialTier, avgPrice) => {
  const tierDiscountRanges = {
    'tier_1_critical': { min: 80, max: 100 },
    'tier_2_high': { min: 60, max: 79 },
    'tier_3_medium': { min: 40, max: 59 },
    'tier_4_low': { min: 20, max: 39 },
    'tier_5_no_assistance': { min: 0, max: 19 }
  };
  
  const range = tierDiscountRanges[financialTier] || { min: 0, max: 0 };
  
  let adjustment = 0;
  if (avgPrice > 100) adjustment = 5;
  if (avgPrice > 150) adjustment = 10;
  
  return {
    min: range.min,
    max: Math.min(100, range.max + adjustment),
    average: Math.floor((range.min + range.max) / 2) + adjustment
  };
};

exports.getTierDescription = (tier) => {
  const descriptions = {
    'tier_1_critical': 'You qualify for maximum financial assistance. Most institutions will offer significant discounts (80-100%).',
    'tier_2_high': 'You qualify for high financial assistance. Many institutions have programs for your situation (60-79%).',
    'tier_3_medium': 'You qualify for moderate financial assistance. Some institutions offer sliding scale fees (40-59%).',
    'tier_4_low': 'You qualify for limited financial assistance. Consider payment plans or partial assistance (20-39%).',
    'tier_5_no_assistance': 'You may not qualify for financial assistance, but payment plans may be available (0-19%).'
  };
  return descriptions[tier] || '';
};

exports.getDiscountRange = (tier) => {
  const ranges = {
    'tier_1_critical': '80-100%',
    'tier_2_high': '60-79%',
    'tier_3_medium': '40-59%',
    'tier_4_low': '20-39%',
    'tier_5_no_assistance': '0-19%'
  };
  return ranges[tier] || '0%';
};

exports.getTypicalAssistance = (tier) => {
  const assistance = {
    'tier_1_critical': 'Full or nearly full coverage of therapy costs',
    'tier_2_high': 'Significant discount on therapy sessions',
    'tier_3_medium': 'Moderate discount or sliding scale fees',
    'tier_4_low': 'Small discount or payment plan options',
    'tier_5_no_assistance': 'Payment plans or installment options'
  };
  return assistance[tier] || '';
};

exports.getFinancialHealthIndicator = (score) => {
  if (score >= 85) return { level: 'critical', color: 'red', message: 'High financial need - maximum assistance recommended' };
  if (score >= 70) return { level: 'high', color: 'orange', message: 'Significant financial need - substantial assistance recommended' };
  if (score >= 55) return { level: 'medium', color: 'yellow', message: 'Moderate financial need - partial assistance recommended' };
  if (score >= 40) return { level: 'low', color: 'blue', message: 'Low financial need - limited assistance recommended' };
  return { level: 'minimal', color: 'green', message: 'Minimal financial need - payment plans recommended' };
};

exports.getAverageDiscountForTier = (tier) => {
  const averages = {
    'tier_1_critical': '90%',
    'tier_2_high': '70%',
    'tier_3_medium': '50%',
    'tier_4_low': '30%',
    'tier_5_no_assistance': '10%'
  };
  return averages[tier] || '0%';
};

exports.estimateMonthlySavings = async (parentId, discountPercentage) => {
  try {
    // Estimate based on average session cost and typical number of sessions
    const averageSessionCost = 75; // Average across all institutions
    const typicalSessionsPerMonth = 8;
    const monthlyCost = averageSessionCost * typicalSessionsPerMonth;
    
    return (monthlyCost * (discountPercentage / 100)).toFixed(2);
  } catch (error) {
    return '0.00';
  }
};

exports.getSeverityMultiplier = (severity) => {
  const multipliers = {
    'critical': 1.2,
    'high': 1.1,
    'medium': 1.0,
    'low': 0.9
  };
  return multipliers[severity?.toLowerCase()] || 1.0;
};

exports.getRequiredDocumentTypes = (financialTier, discountPercentage) => {
  const baseDocs = ['Identification Document', 'Proof of Address'];
  
  if (financialTier === 'tier_1_critical' || discountPercentage >= 80) {
    return [...baseDocs, 'Income Proof', 'Bank Statements (3 months)', 'Utility Bills'];
  } else if (financialTier === 'tier_2_high' || discountPercentage >= 60) {
    return [...baseDocs, 'Income Proof', 'Recent Pay Slips'];
  } else if (discountPercentage >= 40) {
    return [...baseDocs, 'Income Declaration'];
  }
  
  return baseDocs;
};

exports.calculateAge = (birthDate) => {
  if (!birthDate) return null;
  const today = new Date();
  const birth = new Date(birthDate);
  let age = today.getFullYear() - birth.getFullYear();
  const monthDiff = today.getMonth() - birth.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
    age--;
  }
  return age;
};

exports.getFinancialAssessmentQuestions = (parent) => {
  const questions = [
    {
      id: 'monthly_income',
      type: 'range',
      question: 'What is your approximate total monthly household income?',
      description: 'Include all sources of income for all family members',
      options: [
        { value: 'under_300', label: 'Under $300', score_weight: 1.0 },
        { value: '300_600', label: '$300 - $600', score_weight: 0.9 },
        { value: '600_900', label: '$600 - $900', score_weight: 0.8 },
        { value: '900_1200', label: '$900 - $1,200', score_weight: 0.7 },
        { value: '1200_1500', label: '$1,200 - $1,500', score_weight: 0.6 },
        { value: '1500_2000', label: '$1,500 - $2,000', score_weight: 0.5 },
        { value: '2000_3000', label: '$2,000 - $3,000', score_weight: 0.4 },
        { value: '3000_5000', label: '$3,000 - $5,000', score_weight: 0.3 },
        { value: 'over_5000', label: 'Over $5,000', score_weight: 0.1 }
      ],
      required: true,
      privacy_level: 'high'
    },
    {
      id: 'employment_status',
      type: 'select',
      question: 'What is your current employment status?',
      options: [
        { value: 'employed_full_time', label: 'Employed Full-Time', score_weight: 0.2 },
        { value: 'employed_part_time', label: 'Employed Part-Time', score_weight: 0.4 },
        { value: 'self_employed', label: 'Self-Employed', score_weight: 0.3 },
        { value: 'unemployed', label: 'Currently Unemployed', score_weight: 0.9 },
        { value: 'student', label: 'Student', score_weight: 0.7 },
        { value: 'retired', label: 'Retired', score_weight: 0.6 },
        { value: 'disabled', label: 'Disabled', score_weight: 0.8 }
      ],
      required: true
    },
    {
      id: 'family_size',
      type: 'number',
      question: 'How many people live in your household?',
      description: 'Include all family members who live together',
      min: 1,
      max: 15,
      required: true
    },
    {
      id: 'dependents_count',
      type: 'number',
      question: 'How many dependents do you have?',
      description: 'Children, elderly, or others who depend on your income',
      min: 0,
      max: 10,
      required: true
    },
    {
      id: 'special_circumstances',
      type: 'multi_select',
      question: 'Do any of these circumstances apply to your family?',
      options: [
        { value: 'single_parent', label: 'Single Parent Household', score_weight: 0.7 },
        { value: 'widow_widower', label: 'Widow/Widower', score_weight: 0.8 },
        { value: 'divorced', label: 'Recently Divorced/Separated', score_weight: 0.6 },
        { value: 'refugee_displaced', label: 'Refugee/Displaced', score_weight: 0.9 },
        { value: 'low_income_family', label: 'Low-Income Family', score_weight: 0.5 },
        { value: 'special_needs_family_member', label: 'Other Family Member with Special Needs', score_weight: 0.4 },
        { value: 'medical_emergency', label: 'Recent Medical Emergency', score_weight: 0.6 },
        { value: 'none', label: 'None of the above', score_weight: 0.1 }
      ],
      required: true
    },
    {
      id: 'government_support',
      type: 'conditional',
      question: 'Do you receive any government financial support?',
      follow_up: {
        yes: [
          {
            id: 'support_amount',
            type: 'range',
            question: 'Approximate monthly support amount?',
            options: [
              { value: 'under_100', label: 'Under $100' },
              { value: '100_300', label: '$100 - $300' },
              { value: '300_500', label: '$300 - $500' },
              { value: 'over_500', label: 'Over $500' }
            ]
          }
        ]
      },
      required: true
    },
    {
      id: 'monthly_expenses',
      type: 'range',
      question: 'Approximate monthly medical expenses for your child?',
      options: [
        { value: 'under_100', label: 'Under $100', score_weight: 0.2 },
        { value: '100_300', label: '$100 - $300', score_weight: 0.4 },
        { value: '300_500', label: '$300 - $500', score_weight: 0.6 },
        { value: '500_800', label: '$500 - $800', score_weight: 0.8 },
        { value: 'over_800', label: 'Over $800', score_weight: 1.0 }
      ],
      required: false
    }
  ];
  
  return { questions, total_questions: questions.length };
};

exports.processAssessmentResponses = (parent, responses) => {
  const updates = {};
  
  // Process each response
  if (responses.monthly_income) {
    const incomeMap = {
      'under_300': 150,
      '300_600': 450,
      '600_900': 750,
      '900_1200': 1050,
      '1200_1500': 1350,
      '1500_2000': 1750,
      '2000_3000': 2500,
      '3000_5000': 4000,
      'over_5000': 6000
    };
    updates.monthly_income = incomeMap[responses.monthly_income] || null;
  }
  
  if (responses.employment_status) {
    updates.employment_status = responses.employment_status;
  }
  
  if (responses.family_size) {
    updates.family_size = parseInt(responses.family_size) || 1;
  }
  
  if (responses.dependents_count !== undefined) {
    updates.dependents_count = parseInt(responses.dependents_count) || 0;
  }
  
  if (responses.special_circumstances) {
    const circumstances = Array.isArray(responses.special_circumstances) ? 
      responses.special_circumstances : [responses.special_circumstances];
    
    if (circumstances.includes('none')) {
      updates.special_circumstances = 'none';
    } else if (circumstances.length > 0) {
      // Use the highest priority circumstance
      const priorityOrder = [
        'refugee_displaced',
        'widow_widower',
        'single_parent',
        'medical_emergency',
        'special_needs_family_member',
        'low_income_family',
        'divorced'
      ];
      
      const highestPriority = priorityOrder.find(circ => circumstances.includes(circ));
      updates.special_circumstances = highestPriority || circumstances[0];
    }
  }
  
  if (responses.government_support) {
    updates.receives_government_support = responses.government_support === 'yes';
    
    if (responses.support_amount) {
      const amountMap = {
        'under_100': 50,
        '100_300': 200,
        '300_500': 400,
        'over_500': 600
      };
      updates.government_support_amount = amountMap[responses.support_amount] || 0;
    }
  }
  
  if (responses.monthly_expenses) {
    const expenseMap = {
      'under_100': 50,
      '100_300': 200,
      '300_500': 400,
      '500_800': 650,
      'over_800': 900
    };
    updates.additional_medical_expenses = expenseMap[responses.monthly_expenses] || 0;
  }
  
  // Handle new fields from general assessment
  if (responses.monthly_medical_expenses) {
    const expenseMap = {
      'under_100': 50,
      '100_300': 200,
      '300_500': 400,
      '500_800': 650,
      'over_800': 900
    };
    updates.additional_medical_expenses = expenseMap[responses.monthly_medical_expenses] || 0;
  }
  
  if (responses.other_monthly_expenses) {
    const expenseMap = {
      'under_500': 300,
      '500_1000': 750,
      '1000_1500': 1250,
      '1500_2000': 1750,
      'over_2000': 2250
    };
    updates.other_monthly_expenses = expenseMap[responses.other_monthly_expenses] || 0;
  }
  
  return updates;
};

exports.getTierLabel = (tier) => {
  const labels = {
    'tier_1_critical': 'Critical Financial Need',
    'tier_2_high': 'High Financial Need',
    'tier_3_medium': 'Medium Financial Need',
    'tier_4_low': 'Low Financial Need',
    'tier_5_no_assistance': 'No Assistance Required'
  };
  return labels[tier] || 'Unknown';
};

exports.determineChildUrgencyFromData = (child, urgency_reason) => {
  if (urgency_reason && urgency_reason.toLowerCase().includes('urgent')) {
    return 'high';
  }
  
  if (child.risk_level === 'High' || child.risk_level === 'Critical') {
    return 'high';
  }
  
  if (child.ai_confidence_score && child.ai_confidence_score > 0.7) {
    return 'medium';
  }
  
  return 'low';
};

exports.notifyInstitutionManagers = async (institutionId, financialRequest) => {
  try {
    const Manager = require('../model/Manager');
    const Notification = require('../model/Notification');
    
    const managers = await Manager.findAll({
      where: {
        institution_id: institutionId,
        is_active: true
      },
      attributes: ['manager_id']
    });
    
    for (const manager of managers) {
      await Notification.create({
        user_id: manager.manager_id,
        title: 'New Financial Assistance Request',
        message: `A new financial assistance request has been submitted for review. Request ID: FA-${financialRequest.request_id}`,
        type: 'financial_assistance_request',
        related_id: financialRequest.request_id,
        is_read: false
      });
    }
    
    console.log(`📧 Notified ${managers.length} managers about new financial assistance request`);
    
  } catch (error) {
    console.error('Error notifying institution managers:', error);
  }
};

exports.getInstitutionContact = async (institutionId) => {
  try {
    const Institution = require('../model/Institution');
    const institution = await Institution.findByPk(institutionId, {
      attributes: ['name', 'contact_phone', 'contact_email']
    });
    
    return institution ? {
      name: institution.name,
      phone: institution.contact_phone,
      email: institution.contact_email
    } : {
      name: 'Institution Administration',
      phone: 'Not available',
      email: 'Not available'
    };
    
  } catch (error) {
    console.error('Error getting institution contact:', error);
    return {
      name: 'Institution Administration',
      phone: 'Contact institution directly',
      email: 'Not available'
    };
  }
};

exports.createStatusTimeline = (financialRequest) => {
  const timeline = [];
  
  // Created
  timeline.push({
    status: 'created',
    date: financialRequest.created_at,
    description: 'Request created',
    completed: true
  });
  
  // Submitted
  if (financialRequest.submitted_at) {
    timeline.push({
      status: 'submitted',
      date: financialRequest.submitted_at,
      description: 'Submitted for review',
      completed: true
    });
  }
  
  // Under Review
  if (financialRequest.status === 'under_review' || 
      financialRequest.status === 'pending_documents') {
    timeline.push({
      status: 'under_review',
      date: financialRequest.submitted_at || financialRequest.updated_at,
      description: 'Under review by institution',
      completed: false,
      current: true
    });
  }
  
  // Documents Requested
  if (financialRequest.requires_documents && !financialRequest.documents_submitted) {
    timeline.push({
      status: 'documents_requested',
      date: financialRequest.updated_at,
      description: 'Documents requested',
      completed: false,
      current: true
    });
  }
  
  // Decision
  if (financialRequest.decision_date) {
    timeline.push({
      status: 'decision_made',
      date: financialRequest.decision_date,
      description: `Decision: ${financialRequest.status}`,
      completed: true,
      current: financialRequest.status !== 'approved' && financialRequest.status !== 'partially_approved'
    });
  }
  
  // Sessions Scheduled
  if (financialRequest.status === 'approved' || financialRequest.status === 'partially_approved') {
    timeline.push({
      status: 'sessions_scheduled',
      date: financialRequest.updated_at,
      description: 'Therapy sessions scheduled',
      completed: true
    });
  }
  
  return timeline;
};

exports.getStatusLabel = (status) => {
  const labels = {
    'draft': 'Draft',
    'submitted': 'Submitted',
    'under_review': 'Under Review',
    'pending_documents': 'Documents Required',
    'approved': 'Approved',
    'partially_approved': 'Partially Approved',
    'rejected': 'Rejected',
    'auto_generated': 'Auto-Generated',
    'cancelled': 'Cancelled'
  };
  return labels[status] || status;
};

exports.getStatusColor = (status) => {
  const colors = {
    'draft': '#9CA3AF',
    'submitted': '#3B82F6',
    'under_review': '#F59E0B',
    'pending_documents': '#F97316',
    'approved': '#10B981',
    'partially_approved': '#0D9488',
    'rejected': '#EF4444',
    'auto_generated': '#8B5CF6',
    'cancelled': '#6B7280'
  };
  return colors[status] || '#6B7280';
};

exports.getAvailableActions = (status) => {
  const actions = {
    'draft': ['submit', 'save', 'cancel'],
    'submitted': ['view', 'cancel', 'contact_support'],
    'under_review': ['view', 'upload_documents', 'contact_support'],
    'pending_documents': ['upload_documents', 'view', 'contact_support'],
    'approved': ['view_sessions', 'download_approval', 'contact_support'],
    'partially_approved': ['view_sessions', 'setup_payment', 'contact_support'],
    'rejected': ['appeal', 'contact_support', 'new_request'],
    'auto_generated': ['view', 'confirm', 'modify_request'],
    'cancelled': ['new_request', 'contact_support']
  };
  
  return actions[status] || ['contact_support'];
};

exports.processDocumentUpload = async (documents, parentId) => {
  const processedDocs = [];
  
  for (const doc of documents) {
    // Validate document
    if (!doc.type || !doc.file_data) {
      continue;
    }
    
    // Generate unique filename
    const timestamp = Date.now();
    const fileId = `doc_${parentId}_${timestamp}_${Math.random().toString(36).substr(2, 9)}`;
    
    // In production, upload to cloud storage (AWS S3, Google Cloud Storage, etc.)
    // For now, we'll store metadata
    processedDocs.push({
      id: fileId,
      type: doc.type,
      name: doc.name || `${doc.type}_${timestamp}`,
      size: doc.size || 'unknown',
      uploaded_at: new Date(),
      status: 'uploaded',
      verification_status: 'pending'
    });
  }
  
  return processedDocs;
};

exports.notifyDocumentSubmission = async (institutionId, requestId) => {
  try {
    const Manager = require('../model/Manager');
    const Notification = require('../model/Notification');
    
    const managers = await Manager.findAll({
      where: {
        institution_id: institutionId,
        is_active: true
      },
      attributes: ['manager_id']
    });
    
    for (const manager of managers) {
      await Notification.create({
        user_id: manager.manager_id,
        title: 'Documents Submitted for Financial Assistance',
        message: `Documents have been submitted for financial assistance request FA-${requestId}. Ready for review.`,
        type: 'financial_documents_submitted',
        related_id: requestId,
        is_read: false
      });
    }
    
  } catch (error) {
    console.error('Error notifying document submission:', error);
  }
};

exports.safeParseFloat = (value, defaultValue = 0) => {
  if (value === null || value === undefined) return defaultValue;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = parseFloat(value);
    return isNaN(parsed) ? defaultValue : parsed;
  }
  if (typeof value === 'object' && value.toString) {
    try {
      const parsed = parseFloat(value.toString());
      return isNaN(parsed) ? defaultValue : parsed;
    } catch (e) {
      return defaultValue;
    }
  }
  return defaultValue;
};

exports.getParentFinancialProfile = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    
    console.log('🔍 Fetching financial profile for parent:', parentId);

    // جلب بيانات الأب مع معلوماته المالية
    const Parent = require('../model/Parent');
    const parent = await Parent.findOne({
      where: { parent_id: parentId },
      include: [{
        model: require('../model/User'),
        attributes: ['full_name', 'email', 'phone']
      }]
    });

    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found'
      });
    }

    // جلب الطلبات المالية النشطة
    const FinancialAssistanceRequest = require('../model/FinancialAssistanceRequest');
    const activeRequests = await FinancialAssistanceRequest.findAll({
      where: {
        parent_id: parentId,
        status: ['submitted', 'under_review', 'pending_documents']
      },
      order: [['created_at', 'DESC']],
      limit: 5
    });

    // جلب الطلبات المكتملة
    const completedRequests = await FinancialAssistanceRequest.findAll({
      where: {
        parent_id: parentId,
        status: ['approved', 'partially_approved', 'rejected']
      },
      order: [['decision_date', 'DESC']],
      limit: 10
    });

    // تحضير البيانات
    const financialProfile = {
      parent_id: parent.parent_id,
      monthly_income: parent.monthly_income,
      employment_status: parent.employment_status,
      family_size: parent.family_size,
      dependents_count: parent.dependents_count,
      special_circumstances: parent.special_circumstances,
      receives_government_support: parent.receives_government_support,
      government_support_amount: parent.government_support_amount,
      other_monthly_expenses: parent.other_monthly_expenses,
      additional_medical_expenses: parent.additional_medical_expenses,
      financial_score: parent.financial_score,
      financial_tier: parent.financial_tier,
      last_financial_assessment: parent.last_financial_assessment,
      financial_documents: parent.financial_documents,
      assessment_notes: parent.assessment_notes,
      credibility_score: parent.credibility_score,
      parent_info: {
        name: parent.User?.full_name,
        email: parent.User?.email,
        phone: parent.User?.phone
      },
      requests_summary: {
        total_active: activeRequests.length,
        total_completed: completedRequests.length,
        pending_documents: activeRequests.filter(r => r.requires_documents).length
      },
      active_requests: activeRequests.map(req => ({
        request_id: req.request_id,
        child_id: req.child_id,
        institution_id: req.institution_id,
        requested_discount_percentage: req.requested_discount_percentage,
        status: req.status,
        requires_documents: req.requires_documents,
        submitted_at: req.submitted_at
      })),
      estimated_monthly_subsidy: await this.calculateEstimatedSubsidy(parentId)
    };

    res.status(200).json({
      success: true,
      message: 'Financial profile retrieved successfully',
      data: financialProfile
    });

  } catch (error) {
    console.error('Error getting parent financial profile:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch financial profile',
      error: error.message
    });
  }
};

exports.calculateEstimatedSubsidy = async (parentId) => {
  try {
    const FinancialAssistanceRequest = require('../model/FinancialAssistanceRequest');
    
    const approvedRequests = await FinancialAssistanceRequest.findAll({
      where: {
        parent_id: parentId,
        status: 'approved'
      }
    });

    let totalSubsidy = 0;
    
    approvedRequests.forEach(request => {
      const requestedAmount = parseFloat(request.requested_total_amount) || 0;
      const discountPercentage = parseFloat(request.approved_discount_percentage) || 0;
      totalSubsidy += requestedAmount * (discountPercentage / 100);
    });

    return totalSubsidy;
  } catch (error) {
    console.error('Error calculating subsidy:', error);
    return 0;
  }
};

exports.getFinancialAssistanceStatus = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { request_id } = req.params;
    
    const financialRequest = await FinancialAssistanceRequest.findOne({
      where: {
        request_id,
        parent_id: parentId
      },
      include: [
        {
          model: require('../model/Child'),
          as: 'child',
          attributes: ['full_name', 'child_id']
        },
        {
          model: require('../model/Institution'),
          as: 'institution',
          attributes: ['name', 'institution_id']
        },
        {
          model: require('../model/User'),
          as: 'approvedByManager',
          attributes: ['full_name'],
          required: false
        }
      ]
    });
    
    if (!financialRequest) {
      return res.status(404).json({
        success: false,
        message: 'Financial assistance request not found'
      });
    }
    
    // تحويل الأرقام من Decimal إلى numbers عادية
    const requestedTotalAmount = parseFloat(financialRequest.requested_total_amount) || 0;
    const approvedTotalAmount = parseFloat(financialRequest.approved_total_amount) || 0;
    const requestedDiscount = parseFloat(financialRequest.requested_discount_percentage) || 0;
    const approvedDiscount = parseFloat(financialRequest.approved_discount_percentage) || 0;
    
    // Get related sessions if approved
    let relatedSessions = [];
    if (financialRequest.status === 'approved' || financialRequest.status === 'partially_approved') {
      const Session = require('../model/Session');
      relatedSessions = await Session.findAll({
        where: {
          child_id: financialRequest.child_id,
          financial_assistance_request_id: request_id
        },
        attributes: ['session_id', 'date', 'time', 'final_price', 'payment_status'],
        order: [['date', 'ASC']],
        limit: 10
      });
    }
    
    // Prepare status timeline
    const statusTimeline = this.createStatusTimeline(financialRequest);
    
    // Prepare response
    const response = {
      success: true,
      request: {
        request_id: financialRequest.request_id,
        reference_number: `FA-${financialRequest.request_id.toString().padStart(6, '0')}`,
        child_name: financialRequest.child.full_name,
        institution_name: financialRequest.institution.name,
        status: financialRequest.status,
        status_label: this.getStatusLabel(financialRequest.status),
        status_color: this.getStatusColor(financialRequest.status),
        assessment_type: financialRequest.assessment_type || 'specific'
      },
      financial_details: {
        requested_discount: `${requestedDiscount}%`,
        approved_discount: approvedDiscount > 0 ? `${approvedDiscount}%` : 'Pending',
        requested_sessions: financialRequest.requested_sessions_count,
        approved_sessions: financialRequest.approved_sessions_count || 'Pending',
        original_amount: `$${requestedTotalAmount.toFixed(2)}`,
        approved_amount: approvedTotalAmount > 0 ? `$${approvedTotalAmount.toFixed(2)}` : 'Pending',
        estimated_savings: approvedDiscount > 0 ? 
          `$${(requestedTotalAmount * (approvedDiscount / 100)).toFixed(2)}` : 'Calculating...'
      },
      timeline: statusTimeline,
      documents: {
        required: financialRequest.requires_documents,
        submitted: financialRequest.documents_submitted ? financialRequest.documents_submitted.length > 0 : false,
        status: financialRequest.requires_documents && !financialRequest.documents_submitted ? 
          'Pending' : 'Submitted'
      },
      related_sessions: relatedSessions,
      decision_details: financialRequest.decision_date ? {
        decided_by: financialRequest.approvedByManager?.full_name || 'Institution Manager',
        decision_date: financialRequest.decision_date,
        notes: financialRequest.decision_notes
      } : null,
      actions_available: this.getAvailableActions(financialRequest.status),
      estimated_completion: financialRequest.estimated_processing_days ? 
        new Date(Date.now() + financialRequest.estimated_processing_days * 24 * 60 * 60 * 1000) : null
    };
    
    res.status(200).json(response);
    
  } catch (error) {
    console.error('Error getting financial assistance status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch financial assistance status',
      error: error.message
    });
  }
};

exports.uploadFinancialDocuments = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { request_id } = req.params;
    const { documents } = req.body;
    
    if (!documents || !Array.isArray(documents) || documents.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Documents are required'
      });
    }
    
    // Verify request belongs to parent
    const financialRequest = await FinancialAssistanceRequest.findOne({
      where: {
        request_id,
        parent_id: parentId,
        requires_documents: true
      }
    });
    
    if (!financialRequest) {
      return res.status(404).json({
        success: false,
        message: 'Request not found or documents not required'
      });
    }
    
    // Process and validate documents
    const processedDocuments = await this.processDocumentUpload(documents, parentId);
    
    // Update request with documents
    await financialRequest.update({
      documents_submitted: processedDocuments,
      status: 'under_review',
      updated_at: new Date()
    });
    
    // Update parent credibility score positively
    await FinancialAssessmentService.updateCredibilityScore(parentId, {
      verified_accurate: true,
      document_submission: true
    });
    
    // Notify institution managers
    await this.notifyDocumentSubmission(financialRequest.institution_id, request_id);
    
    res.status(200).json({
      success: true,
      message: 'Documents uploaded successfully',
      documents: processedDocuments.map(doc => ({
        type: doc.type,
        status: doc.status,
        uploaded_at: doc.uploaded_at
      })),
      next_steps: [
        'Documents are under review',
        'Decision expected within 3-5 business days',
        'You will receive a notification when reviewed'
      ]
    });
    
  } catch (error) {
    console.error('Error uploading financial documents:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to upload documents',
      error: error.message
    });
  }
};

exports.getFinancialAssistanceRequests = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const {
      status,
      page = 1,
      limit = 10,
      sort_by = 'created_at',
      sort_order = 'DESC'
    } = req.query;

    console.log('🔍 Fetching financial assistance requests for parent:', parentId);

    const whereConditions = { parent_id: parentId };

    if (status && status !== 'all') {
      if (status === 'active') {
        whereConditions.status = ['submitted', 'under_review', 'pending_documents'];
      } else if (status === 'completed') {
        whereConditions.status = ['approved', 'partially_approved', 'rejected'];
      } else {
        whereConditions.status = status;
      }
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const totalCount = await FinancialAssistanceRequest.count({
      where: whereConditions
    });

    const requests = await FinancialAssistanceRequest.findAll({
      where: whereConditions,
      include: [
        {
          model: require('../model/Child'),
          as: 'child',
          attributes: ['child_id', 'full_name', 'date_of_birth', 'gender']
        },
        {
          model: require('../model/Institution'),
          as: 'institution',
          attributes: ['name', 'city', 'location_address']
        },
        {
          model: require('../model/User'),
          as: 'approvedByManager',
          attributes: ['full_name'],
          required: false
        }
      ],
      order: [
        [sort_by, sort_order],
        ['created_at', 'DESC']
      ],
      offset: offset,
      limit: parseInt(limit)
    });

    const formattedRequests = requests.map(request => {
      const urgencyColor = {
        critical: 'red',
        high: 'orange',
        medium: 'yellow',
        low: 'green'
      }[request.child_condition_urgency] || 'gray';

      const requestedTotal = parseFloat(request.requested_total_amount || 0);

      return {
        request_id: request.request_id,
        reference_number: `FA-${request.request_id.toString().padStart(6, '0')}`,
        requested_sessions_count: request.requested_sessions_count,
        requested_discount_percentage: request.requested_discount_percentage,
        requested_total_amount: requestedTotal,
        requires_documents: request.requires_documents,
        documents_submitted: request.documents_submitted,

        child: {
          id: request.child.child_id,
          name: request.child.full_name,
          age: request.child.date_of_birth
            ? Math.floor(
                (new Date() - new Date(request.child.date_of_birth)) /
                  (1000 * 60 * 60 * 24 * 365)
              )
            : null
        },
        institution: {
          id: request.institution_id,
          name: request.institution.name,
          city: request.institution.city
        },
        financial_details: {
          requested_sessions: request.requested_sessions_count,
          requested_discount: `${request.requested_discount_percentage}%`,
          original_amount: `$${requestedTotal.toFixed(2)}`,
          approved_discount: request.approved_discount_percentage
            ? `${request.approved_discount_percentage}%`
            : null,
          approved_amount: request.approved_total_amount
            ? `$${parseFloat(request.approved_total_amount).toFixed(2)}`
            : null,
          estimated_savings: request.approved_discount_percentage
            ? `$${(
                requestedTotal *
                (parseFloat(request.approved_discount_percentage) / 100)
              ).toFixed(2)}`
            : null
        },
        status_info: {
          status: request.status,
          label: this.getStatusLabel(request.status),
          color: this.getStatusColor(request.status),
          requires_documents: request.requires_documents,
          documents_submitted: request.documents_submitted
            ? request.documents_submitted.length > 0
            : false,
          assessment_type: request.assessment_type || 'specific'
        },
        urgency: {
          level: request.child_condition_urgency,
          color: urgencyColor
        },
        timeline: {
          submitted: request.submitted_at,
          decision_date: request.decision_date,
          created: request.created_at,
          days_pending: ['submitted', 'under_review', 'pending_documents'].includes(
            request.status
          )
            ? Math.floor(
                (new Date() -
                  new Date(request.submitted_at || request.created_at)) /
                  (1000 * 60 * 60 * 24)
              )
            : 0
        },
        decision: request.decision_date
          ? {
              date: request.decision_date,
              by: request.approvedByManager?.full_name,
              notes: request.decision_notes
            }
          : null
      };
    });

    const sequelize = require('../config/db');
    const stats = await FinancialAssistanceRequest.findAll({
      where: { parent_id: parentId },
      attributes: [
        'status',
        [sequelize.fn('COUNT', sequelize.col('request_id')), 'count']
      ],
      group: ['status']
    });

    const statistics = {
      total: totalCount,
      by_status: stats.reduce((acc, stat) => {
        acc[stat.status] = parseInt(stat.get('count'));
        return acc;
      }, {}),
      pending_review: await FinancialAssistanceRequest.count({
        where: {
          parent_id: parentId,
          status: ['submitted', 'under_review', 'pending_documents']
        }
      }),
      approved_count: await FinancialAssistanceRequest.count({
        where: {
          parent_id: parentId,
          status: 'approved'
        }
      })
    };

    res.status(200).json({
      success: true,
      data: formattedRequests,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount,
        total_pages: Math.ceil(totalCount / parseInt(limit))
      },
      statistics: statistics,
      filters_applied: {
        status: status || 'all',
        page,
        limit,
        sort_by,
        sort_order
      }
    });

  } catch (error) {
    console.error('Error getting financial assistance requests:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch financial assistance requests',
      error: error.message
    });
  }
};

exports.getFreeSessionOffers = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const Parent = require('../model/Parent');
    const Child = require('../model/Child');
    const Institution = require('../model/Institution');

    const parent = await Parent.findOne({ where: { parent_id: parentId } });
    if (!parent) {
      return res.status(404).json({
        success: false,
        message: 'Parent not found',
      });
    }

    const offers = await FreeSessionOffer.findAll({
      where: { parent_id: parentId, status: 'offered' },
      include: [
        { model: Child, attributes: ['child_id', 'full_name'] },
        { model: Institution, attributes: ['institution_id', 'name'] },
      ],
      order: [['created_at', 'DESC']],
    });

    const formatted = offers.map((o) => ({
      offer_id: o.offer_id,
      child_id: o.child_id,
      parent_id: o.parent_id,
      institution_id: o.institution_id,
      session_type_id: o.session_type_id,
      specialist_id: o.specialist_id,
      status: o.status,
      notes: o.notes,
      created_at: o.created_at,
      expires_at: o.expires_at,
      child: o.Child
        ? { id: o.Child.child_id, name: o.Child.full_name }
        : null,
      institution: o.Institution
        ? { id: o.Institution.institution_id, name: o.Institution.name }
        : null,
    }));

    return res.status(200).json({
      success: true,
      data: formatted,
    });
  } catch (error) {
    console.error('Error getting free session offers:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch free session offers',
      error: error.message,
    });
  }
};

exports.acceptFreeSessionOffer = async (req, res) => {
  try {
    return res.status(410).json({
      success: false,
      message:
        'Free session offers acceptance is deprecated. This feature is now read-only.',
    });
  } catch (error) {
    console.error('Error accepting free session offer:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to accept free session offer',
      error: error.message,
    });
  }
};

module.exports = exports;