// services/aiAnalysisService.js - Advanced Local AI Analysis System
const Diagnosis = require('../model/Diagnosis');
const Institution = require('../model/Institution');
const SessionType = require('../model/SessionType');

class AIAnalysisService {
  
  // ============= Extended dictionary with keyword weights =============
  static CONDITION_KEYWORDS = {
    'ASD': {
      name: 'ASD',
      english_name: 'Autism Spectrum Disorder',
      
      // Primary keywords (weight 3)
      primary_keywords: [
        'autism', 'spectrum', 'eye contact', 'isolation', 'withdrawal',
        'fixed routine', 'repetitive movements', 'flapping', 'repetition'
      ],
      
      // Secondary keywords (weight 2)
      secondary_keywords: [
        'communication', 'interaction', 'social', 'isolation', 'loneliness',
        'repetition', 'routine', 'stereotypical', 'movements', 'spinning',
        'language', 'speech', 'delay', 'echolalia', 'repeating',
        'sensitivity', 'sensory', 'sounds', 'lights', 'touch'
      ],
      
      // Supporting keywords (weight 1)
      supporting_keywords: [
        'shy', 'prefers to be alone', 'does not play with children',
        'limited interests', 'obsession', 'attachment to objects',
        'difficulty with change', 'anger when changing', 'tantrums'
      ],
      
      // Severity keywords
      severity_keywords: {
        high: ['nonverbal', 'no communication', 'no response', 'severe aggression', 'self-harm', 'complete isolation', 'constant screaming'],
        medium: ['limited communication', 'little speech', 'difficulty interacting', 'frequent tantrums', 'many repetitive movements'],
        low: ['very shy', 'prefers to be alone', 'slow communication', 'some repetition']
      },
      
      // Composite phrases (weight 5)
      phrases: [
        'does not respond to his name',
        'avoids eye contact',
        'repeats same movements',
        'very sensitive to sounds',
        'flaps his hands',
        'does not point to objects'
      ]
    },
    
    'ADHD': {
      name: 'ADHD',
      english_name: 'Attention Deficit Hyperactivity Disorder',
      
      primary_keywords: [
        'adhd', 'hyperactivity', 'overactive', 'attention deficit',
        'cannot sit still', 'impulsive', 'hasty'
      ],
      
      secondary_keywords: [
        'movement', 'activity', 'hyper', 'jumping', 'running', 'restless',
        'attention', 'focus', 'distracted', 'daydreaming', 'forgetful',
        'impulsive', 'interrupting', 'patience', 'waiting', 'quick',
        'forgetting', 'losing', 'items', 'tasks', 'assignments',
        'fidgety', 'nervous', 'anxious'
      ],
      
      supporting_keywords: [
        'difficulty sitting', 'talks a lot', 'interrupts others',
        'does not wait his turn', 'answers before question ends',
        'forgets homework', 'loses belongings', 'disorganized'
      ],
      
      severity_keywords: {
        high: ['never sits', 'always moving', 'danger to himself', 'severe aggression', 'uncontrollable'],
        medium: ['very active', 'difficulty focusing', 'impulsive', 'very forgetful'],
        low: ['active', 'sometimes forgets', 'slightly distracted', 'restless sometimes']
      },
      
      phrases: [
        'cannot sit still',
        'keeps jumping',
        'interrupts everyone',
        'forgets his stuff daily',
        'does not wait his turn',
        'answers before the question ends'
      ]
    },
    
    'Down Syndrome': {
      name: 'Down Syndrome',
      english_name: 'Down Syndrome',
      
      primary_keywords: [
        'down', 'chromosome', 'down syndrome', 'special features', 'almond eyes'
      ],
      
      secondary_keywords: [
        'features', 'face', 'eyes', 'almond', 'protruding tongue',
        'delayed development', 'motor delay', 'mental delay', 'cognitive delay',
        'weak muscles', 'hypotonia', 'extra flexibility', 'softness',
        'speech difficulty', 'talking difficulty', 'understanding difficulty',
        'heart', 'congenital', 'defect', 'health issues'
      ],
      
      supporting_keywords: [
        'short height', 'short fingers', 'short neck',
        'slow learning', 'needs more time', 'difficulty understanding',
        'hearing problems', 'vision problems', 'heart problems'
      ],
      
      severity_keywords: {
        high: ['severe delay', 'cannot walk', 'cannot talk', 'serious medical problems', 'congenital defects'],
        medium: ['moderate delay', 'needs support', 'slow learning', 'some health problems'],
        low: ['mild delay', 'progressing slowly', 'minor problems']
      },
      
      phrases: [
        'almond-shaped eyes',
        'tongue sticks out',
        'muscle weakness',
        'delayed walking',
        'difficulty speaking'
      ]
    },
    
    'Speech & Language Disorder': {
      name: 'Speech & Language Disorder',
      english_name: 'Speech and Language Disorders',
      
      primary_keywords: [
        'speech', 'language delay', 'late talking', 'nonverbal',
        'stuttering', 'stammering', 'lisp'
      ],
      
      secondary_keywords: [
        'talking', 'language', 'voice', 'few words',
        'repeating letters', 'difficulty pronouncing', 'wrong sound',
        'delay', 'slow speech', 'understanding', 'expression', 'short sentences'
      ],
      
      supporting_keywords: [
        'uses gestures', 'points instead of speaking', 'hard to understand',
        'letter r', 'letter s', 'letter th',
        'unclear speech', 'mumbled', 'confused'
      ],
      
      severity_keywords: {
        high: ['completely mute', 'no speech', 'language loss', 'no words'],
        medium: ['limited speech', 'obvious delay', 'pronunciation problems', '10-20 words only'],
        low: ['minor errors', 'slight delay', 'single letter issue', 'mild stutter']
      },
      
      phrases: [
        'says only few words',
        'uses gestures to communicate',
        'difficulty pronouncing letters',
        'stutters when speaking',
        'speech is not clear'
      ]
    }
  };

  // ============= Advanced symptom analysis =============
  static async analyzeSymptoms(symptomsText, medicalHistory = '', previousServices = '') {
    try {
      console.log('🔍 Starting advanced symptom analysis...');
      
      // Normalize and combine text
      const fullText = this.normalizeArabicText(
        `${symptomsText} ${medicalHistory} ${previousServices}`
      );
      
      const results = [];
      let analyzedKeywords = [];
      let matchedPhrases = [];

      for (const [conditionKey, conditionData] of Object.entries(this.CONDITION_KEYWORDS)) {
        let totalScore = 0;
        let matchedKeywords = [];
        let severityLevel = 'low';
        let severityScore = 0;

        // 1️⃣ Match full phrases (highest weight)
        let phraseMatches = 0;
        conditionData.phrases?.forEach(phrase => {
          const normalizedPhrase = this.normalizeArabicText(phrase);
          if (fullText.includes(normalizedPhrase)) {
            phraseMatches++;
            totalScore += 5;
            matchedKeywords.push(phrase);
            matchedPhrases.push(phrase);
            console.log(`✅ Matched phrase: "${phrase}"`);
          }
        });

        // 2️⃣ Primary keywords (weight 3)
        let primaryMatches = 0;
        conditionData.primary_keywords?.forEach(keyword => {
          if (this.normalizeArabicText(keyword).split(' ').every(word => 
              fullText.includes(word)
          )) {
            primaryMatches++;
            totalScore += 3;
            matchedKeywords.push(keyword);
            analyzedKeywords.push(keyword);
          }
        });

        // 3️⃣ Secondary keywords (weight 2)
        let secondaryMatches = 0;
        conditionData.secondary_keywords?.forEach(keyword => {
          if (fullText.includes(this.normalizeArabicText(keyword))) {
            secondaryMatches++;
            totalScore += 2;
            matchedKeywords.push(keyword);
            analyzedKeywords.push(keyword);
          }
        });

        // 4️⃣ Supporting keywords (weight 1)
        let supportingMatches = 0;
        conditionData.supporting_keywords?.forEach(keyword => {
          if (fullText.includes(this.normalizeArabicText(keyword))) {
            supportingMatches++;
            totalScore += 1;
            matchedKeywords.push(keyword);
          }
        });

        // 5️⃣ Severity level
        for (const [level, keywords] of Object.entries(conditionData.severity_keywords)) {
          const severityMatches = keywords.filter(kw => 
            fullText.includes(this.normalizeArabicText(kw))
          );
          if (severityMatches.length > 0) {
            severityLevel = level;
            severityScore += severityMatches.length * (
              level === 'high' ? 5 : level === 'medium' ? 3 : 1
            );
            totalScore += severityScore;
          }
        }

        // 6️⃣ Confidence calculation
        const maxPossibleScore = 
          (conditionData.phrases?.length || 0) * 5 +
          (conditionData.primary_keywords?.length || 0) * 3 +
          (conditionData.secondary_keywords?.length || 0) * 2 +
          (conditionData.supporting_keywords?.length || 0) * 1;

        let confidence = maxPossibleScore > 0 ? totalScore / maxPossibleScore : 0;

        // Add bonus based on diversity of matches
        const diversityBonus = Math.min(
          (phraseMatches * 0.1) + 
          (primaryMatches * 0.05) + 
          (secondaryMatches * 0.02),
          0.2
        );
        confidence = Math.min(confidence + diversityBonus, 1.0);

        // Include results if confidence > 15%
        if (confidence > 0.15) {
          results.push({
            name: conditionData.name,
            english_name: conditionData.english_name,
            confidence: confidence,
            total_score: totalScore,
            max_possible_score: maxPossibleScore,
            matching_keywords: [...new Set(matchedKeywords)].slice(0, 8),
            phrase_matches: phraseMatches,
            primary_matches: primaryMatches,
            secondary_matches: secondaryMatches,
            supporting_matches: supportingMatches,
            severity_level: severityLevel,
            severity_score: severityScore
          });
        }
      }

      // Sort by confidence
      results.sort((a, b) => b.confidence - a.confidence);

      // Determine overall risk level
      let riskLevel = 'Low';
      if (results.length > 0) {
        const topResult = results[0];
        
        if (topResult.confidence > 0.7 && topResult.severity_level === 'high') {
          riskLevel = 'High';
        } else if (topResult.confidence > 0.6 && topResult.severity_level === 'high') {
          riskLevel = 'High';
        } else if (topResult.confidence > 0.5 || topResult.severity_level === 'medium') {
          riskLevel = 'Medium';
        } else if (topResult.confidence > 0.3) {
          riskLevel = 'Medium';
        }
      }

      console.log('📊 Analysis results:', results.map(r => 
        `${r.english_name}: ${(r.confidence * 100).toFixed(1)}%`
      ));

      return {
        suggested_conditions: results,
        risk_level: riskLevel,
        analysis_confidence: results.length > 0 ? results[0].confidence : 0,
        analyzed_keywords: [...new Set(analyzedKeywords)].slice(0, 15),
        matched_phrases: matchedPhrases,
        total_matches: analyzedKeywords.length,
        analysis_quality: this.assessAnalysisQuality(symptomsText)
      };

    } catch (error) {
      console.error('❌ Error during symptom analysis:', error);
      throw error;
    }
  }

  // ============= Normalize and clean Arabic text =============
  static normalizeArabicText(text) {
    if (!text) return '';
    
    return text
      .toLowerCase()
      .trim()
      .replace(/[أإآ]/g, 'ا')
      .replace(/ؤ/g, 'و')
      .replace(/ئ/g, 'ي')
      .replace(/ة/g, 'ه')
      .replace(/[\u064B-\u065F]/g, '')
      .replace(/[^\u0621-\u064A\u0660-\u0669a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ');
  }

  // ============= Evaluate analysis quality =============
  static assessAnalysisQuality(symptomsText) {
    const wordCount = symptomsText.trim().split(/\s+/).length;
    
    if (wordCount < 10) {
      return {
        quality: 'low',
        message: 'The description is too short. Please add more details for better accuracy.',
        recommendation: 'Include details about: behavior, social interaction, communication skills, and daily activities.'
      };
    } else if (wordCount < 30) {
      return {
        quality: 'medium',
        message: 'Good description but could use more details.',
        recommendation: 'Try to add specific examples from daily behavior.'
      };
    } else {
      return {
        quality: 'high',
        message: 'Detailed and sufficient description for accurate analysis.',
        recommendation: null
      };
    }
  }

  // ============= Institution recommendation (same logic) =============
  static async recommendInstitutions(suggestedConditions, preferredCity = null) {
    try {
      console.log('🏥 Starting institution recommendations...');

      if (!suggestedConditions || suggestedConditions.length === 0) {
        return [];
      }

      const conditionNames = suggestedConditions.map(c => c.name || c);

      let whereClause = {};
      if (preferredCity) {
        whereClause.city = preferredCity;
      }

      const institutions = await Institution.findAll({
        where: whereClause,
        attributes: [
          'institution_id', 
          'name', 
          'city', 
          'region',
          'location_address'
        ]
      });

      const institutionIds = institutions.map(i => i.institution_id);
      const sessionTypes = await SessionType.findAll({
        where: { 
          institution_id: institutionIds
        }
      });

      const sessionTypesByInst = {};
      sessionTypes.forEach(st => {
        const instId = st.institution_id;
        if (!sessionTypesByInst[instId]) {
          sessionTypesByInst[instId] = [];
        }
        sessionTypesByInst[instId].push(st);
      });

      const recommendations = institutions.map(institution => {
        const instData = institution.get({ plain: true });
        const instSessionTypes = sessionTypesByInst[instData.institution_id] || [];

        let matchScore = 0;
        let matchingSpecialties = [];

        instSessionTypes.forEach(st => {
          const targetConditions = st.target_conditions || [];
          
          const hasMatch = conditionNames.some(cn => 
            targetConditions.includes(cn)
          );

          if (hasMatch) {
            matchScore += 0.4;
            if (!matchingSpecialties.includes(st.category)) {
              matchingSpecialties.push(st.category);
            }
          }
        });

        if (preferredCity && instData.city === preferredCity) {
          matchScore += 0.3;
        }

        return {
          ...instData,
          match_score: Math.min(matchScore, 1.0),
          matching_specialties: matchingSpecialties,
          total_services: instSessionTypes.length
        };
      });

      recommendations.sort((a, b) => b.match_score - a.match_score);

      return recommendations.slice(0, 10);

    } catch (error) {
      console.error('❌ Error during institution recommendation:', error);
      throw error;
    }
  }
}

module.exports = AIAnalysisService;
