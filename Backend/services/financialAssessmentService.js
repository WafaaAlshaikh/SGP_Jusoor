// services/financialAssessmentService.js
const sequelize = require('../config/db');
const { Op } = require('sequelize');

class FinancialAssessmentService {
  
  /**
   * Calculate financial score based on multiple factors
   * @param {Object} parentData - Parent information including financial details
   * @returns {Object} - Score, tier, and breakdown
   */
  static async calculateFinancialScore(parentData) {
    try {
      let totalScore = 0;
      const scoreBreakdown = {};
      
      // 1. INCOME SCORE (0-25 points)
      const incomeScore = this.calculateIncomeScore(parentData.monthly_income);
      totalScore += incomeScore;
      scoreBreakdown.income = incomeScore;
      
      // 2. EMPLOYMENT SCORE (0-20 points)
      const employmentScore = this.calculateEmploymentScore(parentData.employment_status);
      totalScore += employmentScore;
      scoreBreakdown.employment = employmentScore;
      
      // 3. FAMILY BURDEN SCORE (0-20 points)
      const familyScore = this.calculateFamilyBurdenScore(
        parentData.family_size,
        parentData.dependents_count
      );
      totalScore += familyScore;
      scoreBreakdown.family_burden = familyScore;
      
      // 4. SPECIAL CIRCUMSTANCES (0-20 points)
      const circumstancesScore = this.calculateCircumstancesScore(
        parentData.special_circumstances
      );
      totalScore += circumstancesScore;
      scoreBreakdown.special_circumstances = circumstancesScore;
      
      // 5. ADDITIONAL EXPENSES (0-15 points)
      const expensesScore = this.calculateExpensesScore(
        parentData.additional_medical_expenses,
        parentData.other_monthly_expenses
      );
      totalScore += expensesScore;
      scoreBreakdown.additional_expenses = expensesScore;
      
      // 6. GOVERNMENT SUPPORT ADJUSTMENT (-10 to 0 points)
      const supportAdjustment = this.calculateGovernmentSupportAdjustment(
        parentData.receives_government_support,
        parentData.government_support_amount
      );
      totalScore += supportAdjustment;
      scoreBreakdown.government_support_adjustment = supportAdjustment;
      
      // 7. CREDIBILITY MULTIPLIER (0.5 to 1.5)
      const credibilityMultiplier = this.calculateCredibilityMultiplier(
        parentData.credibility_score
      );
      
      // Apply credibility multiplier
      totalScore = Math.round(totalScore * credibilityMultiplier);
      
      // Ensure score is between 0-100
      totalScore = Math.max(0, Math.min(100, totalScore));
      
      // Determine financial tier
      const financialTier = this.determineFinancialTier(totalScore);
      
      // Calculate suggested discount percentage
      const suggestedDiscount = this.calculateSuggestedDiscount(financialTier, totalScore);
      
      return {
        financial_score: totalScore,
        financial_tier: financialTier,
        suggested_discount_percentage: suggestedDiscount,
        score_breakdown: scoreBreakdown,
        credibility_multiplier: credibilityMultiplier,
        assessment_date: new Date()
      };
      
    } catch (error) {
      console.error('Error calculating financial score:', error);
      throw new Error('Failed to calculate financial assessment');
    }
  }
  
  // Helper Methods
  
  static calculateIncomeScore(monthlyIncome) {
    if (!monthlyIncome || monthlyIncome <= 0) return 25;
    
    if (monthlyIncome <= 300) return 25;
    if (monthlyIncome <= 600) return 22;
    if (monthlyIncome <= 900) return 18;
    if (monthlyIncome <= 1200) return 15;
    if (monthlyIncome <= 1500) return 12;
    if (monthlyIncome <= 2000) return 8;
    if (monthlyIncome <= 3000) return 5;
    if (monthlyIncome <= 5000) return 3;
    return 1;
  }
  
  static calculateEmploymentScore(employmentStatus) {
    const scoreMap = {
      'unemployed': 20,
      'disabled': 18,
      'student': 15,
      'employed_part_time': 10,
      'self_employed': 8,
      'retired': 12,
      'employed_full_time': 5
    };
    
    return scoreMap[employmentStatus] || 5;
  }
  
  static calculateFamilyBurdenScore(familySize, dependentsCount) {
    let score = 0;
    
    // Base on family size
    if (familySize >= 6) score += 10;
    else if (familySize >= 4) score += 7;
    else if (familySize >= 2) score += 4;
    else score += 2;
    
    // Additional for dependents
    if (dependentsCount >= 3) score += 10;
    else if (dependentsCount >= 2) score += 7;
    else if (dependentsCount >= 1) score += 4;
    
    return Math.min(score, 20);
  }
  
  static calculateCircumstancesScore(circumstance) {
    const scoreMap = {
      'refugee_displaced': 20,
      'widow_widower': 18,
      'single_parent': 15,
      'medical_emergency': 15,
      'special_needs_family_member': 12,
      'low_income_family': 10,
      'divorced': 8,
      'none': 0
    };
    
    return scoreMap[circumstance] || 0;
  }
  
  static calculateExpensesScore(medicalExpenses, otherExpenses) {
    let score = 0;
    const totalExpenses = (medicalExpenses || 0) + (otherExpenses || 0);
    
    if (totalExpenses >= 800) score += 15;
    else if (totalExpenses >= 500) score += 12;
    else if (totalExpenses >= 300) score += 8;
    else if (totalExpenses >= 100) score += 5;
    else score += 2;
    
    return score;
  }
  
  static calculateGovernmentSupportAdjustment(receivesSupport, supportAmount) {
    if (!receivesSupport) return 0;
    
    if (supportAmount >= 500) return -8;
    if (supportAmount >= 300) return -6;
    if (supportAmount >= 100) return -4;
    return -2;
  }
  
  static calculateCredibilityMultiplier(credibilityScore) {
    // Convert 0-100 credibility score to 0.5-1.5 multiplier
    // Higher credibility = higher multiplier (rewards honest users)
    if (credibilityScore >= 90) return 1.5;
    if (credibilityScore >= 80) return 1.3;
    if (credibilityScore >= 70) return 1.1;
    if (credibilityScore >= 60) return 1.0;
    if (credibilityScore >= 50) return 0.9;
    if (credibilityScore >= 40) return 0.8;
    if (credibilityScore >= 30) return 0.7;
    if (credibilityScore >= 20) return 0.6;
    return 0.5;
  }
  
  static determineFinancialTier(score) {
    if (score >= 85) return 'tier_1_critical';
    if (score >= 70) return 'tier_2_high';
    if (score >= 55) return 'tier_3_medium';
    if (score >= 40) return 'tier_4_low';
    return 'tier_5_no_assistance';
  }
  
  static calculateSuggestedDiscount(tier, score) {
    const tierDiscounts = {
      'tier_1_critical': { min: 80, max: 100 },
      'tier_2_high': { min: 60, max: 79 },
      'tier_3_medium': { min: 40, max: 59 },
      'tier_4_low': { min: 20, max: 39 },
      'tier_5_no_assistance': { min: 0, max: 19 }
    };
    
    const range = tierDiscounts[tier];
    if (!range) return 0;
    
    // Calculate discount based on where the score falls in the tier
    if (tier === 'tier_5_no_assistance') return 0;
    
    const tierMinScore = this.getTierMinScore(tier);
    const tierMaxScore = this.getTierMaxScore(tier);
    
    const normalizedScore = Math.max(0, Math.min(1, 
      (score - tierMinScore) / (tierMaxScore - tierMinScore)
    ));
    
    const discount = range.min + (range.max - range.min) * normalizedScore;
    return Math.round(discount);
  }
  
  static getTierMinScore(tier) {
    const tierScores = {
      'tier_1_critical': 85,
      'tier_2_high': 70,
      'tier_3_medium': 55,
      'tier_4_low': 40,
      'tier_5_no_assistance': 0
    };
    return tierScores[tier] || 0;
  }
  
  static getTierMaxScore(tier) {
    const tierScores = {
      'tier_1_critical': 100,
      'tier_2_high': 84,
      'tier_3_medium': 69,
      'tier_4_low': 54,
      'tier_5_no_assistance': 39
    };
    return tierScores[tier] || 100;
  }
  
  /**
   * Auto-generate financial assistance request based on assessment
   */
  static async autoGenerateFinancialAssistanceRequest(childId, institutionId, parentId) {
    try {
      // Get parent financial data
      const Parent = require('../models/Parent');
      const parent = await Parent.findOne({
        where: { parent_id: parentId },
        include: [{
          model: require('../models/User'),
          attributes: ['full_name', 'phone']
        }]
      });
      
      if (!parent) {
        throw new Error('Parent not found');
      }
      
      // Calculate financial assessment
      const assessment = await this.calculateFinancialScore(parent);
      
      // Get child information
      const Child = require('../models/Child');
      const child = await Child.findByPk(childId);
      
      if (!child) {
        throw new Error('Child not found');
      }
      
      // Get institution session types to calculate cost
      const SessionType = require('../models/SessionType');
      const sessionTypes = await SessionType.findAll({
        where: {
          institution_id: institutionId,
          approval_status: 'Approved'
        },
        limit: 3 // Initial recommended sessions
      });
      
      // Calculate total original cost
      let totalOriginalCost = 0;
      sessionTypes.forEach(sessionType => {
        totalOriginalCost += parseFloat(sessionType.price) || 0;
      });
      
      // Create auto-generated financial assistance request
      const FinancialAssistanceRequest = require('../models/FinancialAssistanceRequest');
      
      const assistanceRequest = await FinancialAssistanceRequest.create({
        parent_id: parentId,
        child_id: childId,
        institution_id: institutionId,
        requested_sessions_count: sessionTypes.length,
        requested_discount_percentage: assessment.suggested_discount_percentage,
        requested_total_amount: totalOriginalCost,
        parent_financial_score: assessment.financial_score,
        parent_financial_tier: assessment.financial_tier,
        child_condition_urgency: this.determineChildUrgency(child),
        status: 'auto_generated',
        auto_generated: true,
        requires_documents: assessment.suggested_discount_percentage >= 50,
        estimated_processing_days: assessment.suggested_discount_percentage >= 80 ? 3 : 7,
        submitted_at: new Date()
      });
      
      return {
        success: true,
        request: assistanceRequest,
        assessment: assessment,
        estimated_sessions: sessionTypes.length,
        estimated_cost_before_discount: totalOriginalCost,
        estimated_cost_after_discount: totalOriginalCost * (1 - assessment.suggested_discount_percentage / 100)
      };
      
    } catch (error) {
      console.error('Error auto-generating financial assistance request:', error);
      throw error;
    }
  }
  
  static determineChildUrgency(child) {
    if (!child) return 'medium';
    
    // Based on child's condition and AI analysis
    if (child.risk_level === 'High') return 'high';
    if (child.risk_level === 'Critical') return 'critical';
    if (child.ai_confidence_score && child.ai_confidence_score > 0.7) return 'high';
    
    return 'medium';
  }
  
  /**
   * Update parent credibility score based on verification results
   */
  static async updateCredibilityScore(parentId, verificationResult) {
    try {
      const Parent = require('../models/Parent');
      const parent = await Parent.findOne({ where: { parent_id: parentId } });
      
      if (!parent) return;
      
      let newCredibility = parent.credibility_score || 50;
      
      if (verificationResult.verified_accurate) {
        // Increase for accurate information
        newCredibility += 5;
      } else if (verificationResult.discrepancy_found) {
        // Decrease for discrepancies
        newCredibility -= 10;
      }
      
      // Ensure score stays within bounds
      newCredibility = Math.max(0, Math.min(100, newCredibility));
      
      await parent.update({ credibility_score: newCredibility });
      
      return newCredibility;
      
    } catch (error) {
      console.error('Error updating credibility score:', error);
    }
  }
}

module.exports = FinancialAssessmentService;