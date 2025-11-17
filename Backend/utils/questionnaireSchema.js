// Questionnaire schema: sections & questions definition (English)
// NOTE: Keep this file purely as a config. Backend uses it to lookup
// question metadata (section, category, weight, scores), and frontend
// can consume it via /api/questionnaire/schema.

const questionnaireSchema = {
  sections: [
    // =============================
    // 1) Demographics
    // =============================
    {
      id: 'demographics',
      title: 'Demographics',
      description: 'Basic information about the child',
      questions: [
        {
          id: 'Q1',
          text: 'How old is your child?',
          type: 'single_choice',
          required: true,
          category: 'demographics',
          options: [
            { value: '0-12m', label: 'Less than 1 year', ageGroup: 'infant' },
            { value: '12-24m', label: '1–2 years', ageGroup: 'toddler' },
            { value: '24-36m', label: '2–3 years', ageGroup: 'toddler' },
            { value: '36-48m', label: '3–4 years', ageGroup: 'preschool' },
            { value: '48-60m', label: '4–5 years', ageGroup: 'preschool' },
            { value: '60-72m', label: '5–6 years', ageGroup: 'school' },
            { value: '72m+', label: 'More than 6 years', ageGroup: 'school' }
          ]
        },
        {
          id: 'Q2',
          text: "What is your child's gender?",
          type: 'single_choice',
          required: true,
          category: 'demographics',
          options: [
            { value: 'male', label: 'Male' },
            { value: 'female', label: 'Female' }
          ]
        },
        {
          id: 'Q4',
          text: 'Were there any complications during pregnancy or birth?',
          type: 'multiple_choice',
          required: false,
          category: 'demographics',
          options: [
            { value: 'none', label: 'No, normal pregnancy and birth', exclusive: true },
            { value: 'premature', label: 'Premature birth' },
            { value: 'low_weight', label: 'Low birth weight' },
            { value: 'complications', label: 'Medical complications' },
            { value: 'prefer_not', label: 'Prefer not to answer' }
          ],
          scoring: {
            premature: { general_risk: 1 },
            low_weight: { general_risk: 1 },
            complications: { general_risk: 2 }
          }
        }
      ]
    },

    // =============================
    // 2) General Screening (Q5–Q14)
    // =============================
    {
      id: 'general_screening',
      title: 'General Screening',
      description: 'General questions to decide which deep sections to show',
      questions: [
        {
          id: 'Q5',
          text: 'Does your child look into your eyes when you talk to them?',
          type: 'single_choice',
          category: 'social_communication',
          options: [
            { value: 'always', label: 'Always and rarely avoids eye contact', score: 0 },
            { value: 'usually', label: 'Usually, but sometimes looks away', score: 1 },
            { value: 'sometimes', label: 'Sometimes only', score: 2 },
            { value: 'rarely', label: 'Rarely', score: 3 },
            { value: 'never', label: 'Never or completely avoids eye contact', score: 4 }
          ],
          scoring: {
            ASD: 'score',
            trigger_threshold: 2
          }
        },
        {
          id: 'Q6',
          text: 'Does your child respond when you call their name?',
          type: 'single_choice',
          category: 'social_communication',
          options: [
            { value: 'always', label: 'Always turns or responds', score: 0 },
            { value: 'usually', label: 'Usually responds', score: 1 },
            { value: 'sometimes', label: 'Sometimes only', score: 2 },
            { value: 'rarely', label: 'Rarely responds', score: 3 },
            { value: 'never', label: 'Never responds', score: 4 }
          ],
          scoring: {
            ASD: 'score',
            Speech: 'score * 0.5',
            trigger_threshold: 2
          }
        },
        {
          id: 'Q7',
          text: 'How many clear and understandable words can your child say?',
          type: 'single_choice',
          category: 'language',
          options: [
            // simplified age-dependent logic into generic bands with scores
            { value: 'none', label: 'No words', score: 4 },
            { value: 'few', label: 'Very few words for age', score: 3 },
            { value: 'limited', label: 'Limited vocabulary for age', score: 2 },
            { value: 'age_expected', label: 'Age-appropriate number of words', score: 1 },
            { value: 'above', label: 'Good / advanced vocabulary for age', score: 0 }
          ],
          scoring: {
            Speech: 'score',
            ASD: 'score * 0.5',
            trigger_threshold: 2
          }
        },
        {
          id: 'Q8',
          text: 'Can people who do not know your child well understand their speech?',
          type: 'single_choice',
          category: 'language',
          options: [
            { value: 'mostly', label: 'Most of the time', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'rarely', label: 'Rarely', score: 2 },
            { value: 'never', label: 'No one can understand except family', score: 3 }
          ],
          scoring: {
            Speech: 'score',
            trigger_threshold: 2
          }
        },
        {
          id: 'Q9',
          text: 'Can your child sit calmly and focus on one activity (e.g., video, quiet game) for 5–10 minutes?',
          type: 'single_choice',
          category: 'attention',
          options: [
            { value: 'yes_easily', label: 'Yes, easily', score: 0 },
            { value: 'yes_sometimes', label: 'Sometimes, needs encouragement', score: 1 },
            { value: 'difficult', label: 'Very difficult', score: 2 },
            { value: 'impossible', label: 'Impossible, always moving', score: 3 }
          ],
          scoring: {
            ADHD: 'score',
            trigger_threshold: 2
          }
        },
        {
          id: 'Q10',
          text: 'How would you describe your child’s level of physical activity compared to children of the same age?',
          type: 'single_choice',
          category: 'hyperactivity',
          options: [
            { value: 'less_active', label: 'Less active or normal', score: 0 },
            { value: 'average', label: 'Normal activity', score: 0 },
            { value: 'more_active', label: 'A bit more active', score: 1 },
            { value: 'very_active', label: 'Very active, hard to control', score: 2 },
            { value: 'extreme', label: 'Extremely hyperactive, never stops', score: 3 }
          ],
          scoring: {
            ADHD: 'score',
            trigger_threshold: 2
          }
        },
        {
          id: 'Q11',
          text: 'Does your child interact and play with other children?',
          type: 'single_choice',
          category: 'social',
          options: [
            { value: 'plays_well', label: 'Plays and interacts well', score: 0 },
            { value: 'plays_sometimes', label: 'Plays sometimes, limited interaction', score: 1 },
            { value: 'prefers_alone', label: 'Prefers to play alone', score: 2 },
            { value: 'avoids', label: 'Avoids or is annoyed by others', score: 3 },
            { value: 'no_interest', label: 'Shows no interest in other children', score: 4 }
          ],
          scoring: {
            ASD: 'score',
            trigger_threshold: 2
          }
        },
        {
          id: 'Q12',
          text: 'Does your child use gestures to communicate? (e.g., pointing, waving, nodding yes/no)',
          type: 'single_choice',
          category: 'communication',
          options: [
            { value: 'yes_frequently', label: 'Yes, uses them frequently', score: 0 },
            { value: 'yes_sometimes', label: 'Yes, but rarely', score: 1 },
            { value: 'limited', label: 'Very limited use of gestures', score: 2 },
            { value: 'never', label: 'Does not use gestures at all', score: 3 }
          ],
          scoring: {
            ASD: 'score * 1.5',
            Speech: 'score',
            trigger_threshold: 2
          }
        },
        {
          id: 'Q13',
          text: 'Does your child repeat the same movements or behaviors over and over?',
          type: 'multiple_choice',
          category: 'repetitive_behaviors',
          options: [
            { value: 'none', label: 'No, does not do this', score: 0, exclusive: true },
            { value: 'hand_flapping', label: 'Hand flapping', score: 2 },
            { value: 'spinning', label: 'Spinning around', score: 2 },
            { value: 'rocking', label: 'Rocking back and forth', score: 2 },
            { value: 'lining_objects', label: 'Lining up objects', score: 1 },
            { value: 'repetitive_sounds', label: 'Repetitive sounds or words', score: 2 },
            { value: 'strict_routines', label: 'Very strong attachment to routines', score: 2 },
            { value: 'unusual_interests', label: 'Very narrow / unusual interests', score: 1 }
          ],
          scoring: {
            ASD: 'sum_of_selected_scores',
            trigger_threshold: 3
          }
        },
        {
          id: 'Q14',
          text: 'At what age did your child reach these milestones?',
          type: 'multi_milestone',
          category: 'development',
          milestones: {
            sitting: {
              question: 'Sitting independently without support',
              options: [
                { value: '6-9m', label: '6–9 months (typical)', score: 0 },
                { value: '9-12m', label: '9–12 months (mild delay)', score: 1 },
                { value: '12-18m', label: '12–18 months (moderate delay)', score: 2 },
                { value: '18m+', label: 'After 18 months or not yet', score: 3 }
              ]
            },
            walking: {
              question: 'Walking independently',
              options: [
                { value: '12-18m', label: '12–18 months (typical)', score: 0 },
                { value: '18-24m', label: '18–24 months (mild delay)', score: 1 },
                { value: '24m+', label: 'After 2 years or not yet', score: 3 }
              ]
            }
          },
          scoring: {
            Down: 'average_score * 1.5',
            general_delay: 'average_score',
            trigger_threshold: 2
          }
        }
      ]
    },

    // =============================
    // 3) ASD Deep (ASD1–ASD10)
    // =============================
    {
      id: 'ASD_deep',
      title: 'Autism (ASD) Deep Questions',
      description: 'More detailed questions for autism spectrum features',
      questions: [
        {
          id: 'ASD1',
          text: 'Does your child play pretend or imaginative games?',
          type: 'single_choice',
          category: 'core_ASD_symptom',
          weight: 1.5,
          options: [
            { value: 'yes_frequently', label: 'Yes, often and creatively', score: 0 },
            { value: 'yes_sometimes', label: 'Yes, sometimes', score: 2 },
            { value: 'rarely', label: 'Very rarely', score: 3 },
            { value: 'never', label: 'No, only literal play (e.g., opening/closing doors)', score: 4 }
          ]
        },
        {
          id: 'ASD2',
          text: 'Does your child point with their finger to show you something interesting (not just to request)?',
          type: 'single_choice',
          category: 'joint_attention',
          weight: 2.0,
          options: [
            { value: 'yes', label: 'Yes, points to share interest', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 2 },
            { value: 'only_wants', label: 'Only to request things, not to share', score: 3 },
            { value: 'never', label: 'Never points', score: 4 }
          ]
        },
        {
          id: 'ASD3',
          text: 'If you point at something in the room, does your child look at what you are pointing to?',
          type: 'single_choice',
          category: 'joint_attention',
          weight: 2.0,
          options: [
            { value: 'yes_always', label: 'Yes, always understands and follows', score: 0 },
            { value: 'yes_usually', label: 'Yes, usually', score: 1 },
            { value: 'sometimes', label: 'Sometimes only', score: 2 },
            { value: 'looks_at_finger', label: 'Looks only at my finger, not the object', score: 3 },
            { value: 'no_response', label: 'No response or does not look', score: 4 }
          ]
        },
        {
          id: 'ASD4',
          text: 'Does your child smile back at you when you smile at them?',
          type: 'single_choice',
          category: 'social_reciprocity',
          weight: 1.5,
          options: [
            { value: 'yes_always', label: 'Yes, always smiles back', score: 0 },
            { value: 'yes_usually', label: 'Yes, usually', score: 1 },
            { value: 'sometimes', label: 'Sometimes only', score: 2 },
            { value: 'rarely', label: 'Rarely', score: 3 },
            { value: 'never', label: 'Never as a social response', score: 4 }
          ]
        },
        {
          id: 'ASD5',
          text: 'Is your child unusually sensitive or upset by everyday sounds?',
          type: 'single_choice',
          category: 'sensory_sensitivity',
          weight: 1.0,
          options: [
            { value: 'no', label: 'No, normal reaction to sounds', score: 0 },
            { value: 'some_sounds', label: 'Some loud sounds only (typical)', score: 1 },
            { value: 'many_sounds', label: 'Upset by many everyday sounds', score: 2 },
            { value: 'extreme', label: 'Covers ears or screams with certain sounds', score: 3 }
          ]
        },
        {
          id: 'ASD6',
          text: 'Does your child imitate your actions (e.g., clapping, waving)?',
          type: 'single_choice',
          category: 'social_communication',
          weight: 1.5,
          options: [
            { value: 'yes_frequently', label: 'Yes, imitates a lot', score: 0 },
            { value: 'yes_sometimes', label: 'Yes, sometimes', score: 2 },
            { value: 'rarely', label: 'Rarely', score: 3 },
            { value: 'never', label: 'Never imitates', score: 4 }
          ]
        },
        {
          id: 'ASD7',
          text: 'Does your child look at your face for a long time during interaction?',
          type: 'single_choice',
          category: 'social_communication',
          weight: 2.0,
          options: [
            { value: 'yes', label: 'Yes, looks with interest', score: 0 },
            { value: 'brief', label: 'Looks but very briefly', score: 2 },
            { value: 'rarely', label: 'Rarely looks at my face', score: 3 },
            { value: 'avoids', label: 'Avoids looking at my face', score: 4 }
          ]
        },
        {
          id: 'ASD8',
          text: 'How does your child play with toys?',
          type: 'multiple_choice',
          category: 'play_patterns',
          weight: 1.5,
          options: [
            { value: 'appropriate', label: 'Plays appropriately in varied ways', score: 0, exclusive: true },
            { value: 'lines_up', label: 'Lines up toys in rows', score: 2 },
            { value: 'spins', label: 'Spins toys or round objects', score: 2 },
            { value: 'one_part', label: 'Focuses on one part of a toy (e.g., wheels)', score: 2 },
            { value: 'repetitive', label: 'Repeats the same play or action', score: 2 },
            { value: 'unusual', label: 'Uses toys in unusual ways', score: 3 }
          ]
        },
        {
          id: 'ASD9',
          text: 'Does your child seem to understand other people’s feelings?',
          type: 'single_choice',
          category: 'emotional_reciprocity',
          weight: 1.5,
          options: [
            { value: 'yes', label: 'Yes, responds to my feelings', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 2 },
            { value: 'rarely', label: 'Rarely', score: 3 },
            { value: 'no', label: 'Does not seem to respond to emotions', score: 4 }
          ]
        },
        {
          id: 'ASD10',
          text: 'Does your child have very limited or unusual interests?',
          type: 'single_choice',
          category: 'restricted_interests',
          weight: 1.5,
          options: [
            { value: 'varied_interests', label: 'No, interests are varied and age-appropriate', score: 0 },
            { value: 'some_preference', label: 'Some preferences but normal', score: 1 },
            { value: 'limited', label: 'Very limited interests', score: 2 },
            { value: 'obsessive', label: 'Obsessed with one topic or object', score: 3 },
            { value: 'unusual', label: 'Very unusual interests', score: 4 }
          ]
        }
      ]
    },

    // =============================
    // 4) ADHD Deep (simplified)
    // =============================
    {
      id: 'ADHD_deep',
      title: 'ADHD Deep Questions',
      description: 'Detailed questions for attention and hyperactivity/impulsivity',
      questions: [
        // Inattention
        {
          id: 'ADHD1',
          text: 'Does your child have difficulty paying attention to details or makes careless mistakes?',
          type: 'single_choice',
          category: 'inattention',
          options: [
            { value: 'never', label: 'Never or very rarely', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD2',
          text: 'Does your child have difficulty sustaining attention during play or activities?',
          type: 'single_choice',
          category: 'inattention',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Always or almost always', score: 3 }
          ]
        },
        {
          id: 'ADHD3',
          text: 'Does your child seem not to listen when spoken to directly?',
          type: 'single_choice',
          category: 'inattention',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD4',
          text: 'Does your child have difficulty finishing tasks or activities they start?',
          type: 'single_choice',
          category: 'inattention',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD5',
          text: 'Is your child easily distracted by surrounding stimuli?',
          type: 'single_choice',
          category: 'inattention',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD6',
          text: 'Does your child often forget things in daily activities?',
          type: 'single_choice',
          category: 'inattention',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },

        // Hyperactivity
        {
          id: 'ADHD7',
          text: 'Does your child fidget or move hands/feet a lot when sitting?',
          type: 'single_choice',
          category: 'hyperactivity',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD8',
          text: 'Does your child leave their seat in situations when expected to stay seated (e.g., meals)?',
          type: 'single_choice',
          category: 'hyperactivity',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD9',
          text: 'Does your child run or climb in inappropriate situations?',
          type: 'single_choice',
          category: 'hyperactivity',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD10',
          text: 'Does your child find it difficult to play quietly?',
          type: 'single_choice',
          category: 'hyperactivity',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD11',
          text: 'Does your child seem to be "on the go" or act as if driven by a motor?',
          type: 'single_choice',
          category: 'hyperactivity',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD12',
          text: 'Does your child talk excessively?',
          type: 'single_choice',
          category: 'hyperactivity',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },

        // Impulsivity
        {
          id: 'ADHD13',
          text: 'Does your child answer questions before they have been completed?',
          type: 'single_choice',
          category: 'impulsivity',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD14',
          text: 'Does your child have difficulty waiting their turn (e.g., in games or queues)?',
          type: 'single_choice',
          category: 'impulsivity',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        },
        {
          id: 'ADHD15',
          text: 'Does your child interrupt or intrude on others (e.g., conversations, games)?',
          type: 'single_choice',
          category: 'impulsivity',
          options: [
            { value: 'never', label: 'Never', score: 0 },
            { value: 'sometimes', label: 'Sometimes', score: 1 },
            { value: 'often', label: 'Often', score: 2 },
            { value: 'very_often', label: 'Very often', score: 3 }
          ]
        }
      ]
    },

    // =============================
    // 5) Speech & Language Deep (simplified)
    // =============================
    {
      id: 'Speech_deep',
      title: 'Speech & Language Deep Questions',
      description: 'Detailed questions about receptive and expressive language, articulation, and social use of language',
      questions: [
        {
          id: 'SPEECH1',
          text: 'Does your child understand simple instructions without gestures?',
          type: 'single_choice',
          category: 'receptive_language',
          weight: 2.0,
          options: [
            { value: 'yes_advanced', label: 'Understands even complex multi-step instructions', score: 0 },
            { value: 'yes_two_step', label: 'Understands two-step instructions', score: 1 },
            { value: 'yes_simple', label: 'Understands only very simple instructions', score: 2 },
            { value: 'limited', label: 'Very limited understanding', score: 3 },
            { value: 'no', label: 'Does not understand instructions', score: 4 }
          ]
        },
        {
          id: 'SPEECH2',
          text: 'How many things can your child point to or identify when you ask "Where is the ...?"',
          type: 'single_choice',
          category: 'receptive_language',
          weight: 1.5,
          options: [
            { value: '50+', label: '50+ familiar items', score: 0 },
            { value: '20-50', label: '20–50 items', score: 1 },
            { value: '10-20', label: '10–20 items', score: 2 },
            { value: 'less_10', label: 'Less than 10', score: 3 },
            { value: 'none', label: 'Does not identify items', score: 4 }
          ]
        },
        {
          id: 'SPEECH3',
          text: 'What is the longest sentence your child can say?',
          type: 'single_choice',
          category: 'expressive_language',
          weight: 2.0,
          options: [
            { value: 'full_sentences', label: 'Full and complex sentences (6+ words)', score: 0 },
            { value: 'simple_sentences', label: 'Simple sentences (3–5 words)', score: 1 },
            { value: '2-3_words', label: 'Only 2–3 words', score: 3 },
            { value: 'single_words', label: 'Single words only', score: 4 },
            { value: 'none', label: 'Does not speak', score: 4 }
          ]
        },
        {
          id: 'SPEECH4',
          text: 'Does your child use basic grammar correctly (e.g., plurals, verbs, pronouns)?',
          type: 'single_choice',
          category: 'expressive_language',
          weight: 1.5,
          options: [
            { value: 'yes_well', label: 'Uses grammar well for age', score: 0 },
            { value: 'yes_basic', label: 'Uses basic grammar with some errors', score: 1 },
            { value: 'limited', label: 'Very limited grammar', score: 2 },
            { value: 'no', label: 'Does not use grammar, only single words', score: 3 }
          ]
        },
        {
          id: 'SPEECH5',
          text: 'How clear is your child’s pronunciation of different sounds?',
          type: 'single_choice',
          category: 'articulation',
          weight: 2.0,
          options: [
            { value: 'perfect', label: 'Very clear, almost all sounds correct', score: 0 },
            { value: 'minor_errors', label: 'Minor errors in 1–2 sounds', score: 1 },
            { value: 'several_errors', label: 'Errors in several sounds', score: 2 },
            { value: 'many_errors', label: 'Errors in many sounds', score: 3 },
            { value: 'very_unclear', label: 'Speech mostly unintelligible', score: 4 }
          ]
        },
        {
          id: 'SPEECH6',
          text: 'Does your child use language for social communication (e.g., asking, telling, sharing)?',
          type: 'single_choice',
          category: 'pragmatic_language',
          weight: 1.5,
          options: [
            { value: 'yes_advanced', label: 'Communicates fluently and initiates conversation', score: 0 },
            { value: 'yes_good', label: 'Communicates well', score: 1 },
            { value: 'yes_limited', label: 'Communicates but limited', score: 2 },
            { value: 'basic_only', label: 'Only basic requests', score: 3 },
            { value: 'no', label: 'Does not use language for communication', score: 4 }
          ]
        },
        {
          id: 'SPEECH7',
          text: 'Does your child try to imitate words or sounds you say?',
          type: 'single_choice',
          category: 'expressive_language',
          weight: 1.0,
          options: [
            { value: 'yes_accurately', label: 'Yes, imitates accurately', score: 0 },
            { value: 'yes_tries', label: 'Yes, tries but not accurate', score: 1 },
            { value: 'rarely', label: 'Rarely imitates', score: 2 },
            { value: 'never', label: 'Does not try to imitate', score: 3 }
          ]
        },
        {
          id: 'SPEECH8',
          text: 'Does your child use language (words or gestures) to:',
          type: 'multiple_choice',
          category: 'pragmatic_language',
          weight: 1.5,
          options: [
            { value: 'request', label: 'Request things', score: 0 },
            { value: 'protest', label: 'Refuse or protest', score: 0 },
            { value: 'comment', label: 'Comment on things', score: 0 },
            { value: 'ask', label: 'Ask questions', score: 0 },
            { value: 'greet', label: 'Greet and say goodbye', score: 0 },
            { value: 'none', label: 'Does not use language functionally', score: 4, exclusive: true }
          ],
          scoring_logic: 'if (selected.includes("none")) score = 4; else score = 5 - selected.length;'
        }
      ]
    },

    // =============================
    // 6) Down Syndrome Deep (simplified)
    // =============================
    {
      id: 'Down_deep',
      title: 'Down Syndrome Deep Questions',
      description: 'Questions related to physical features and developmental profile of Down syndrome',
      questions: [
        {
          id: 'DOWN1',
          text: 'Have you noticed any of the following physical features in your child?',
          type: 'multiple_choice',
          category: 'physical_features',
          weight: 2.0,
          options: [
            { value: 'none', label: 'None of these', score: 0, exclusive: true },
            { value: 'eyes', label: 'Almond-shaped eyes slanting upwards', score: 2 },
            { value: 'nose', label: 'Small, flat nose with low nasal bridge', score: 2 },
            { value: 'tongue', label: 'Tongue often protruding', score: 2 },
            { value: 'neck', label: 'Short neck with extra skin at the back', score: 1 },
            { value: 'hands', label: 'Short hands and fingers', score: 1 },
            { value: 'palm_crease', label: 'Single crease across the palm', score: 2 },
            { value: 'ears', label: 'Small ears', score: 1 },
            { value: 'muscle_tone', label: 'Notably low muscle tone (floppiness)', score: 2 },
            { value: 'short_stature', label: 'Shorter height than peers', score: 1 }
          ]
        },
        {
          id: 'DOWN2',
          text: 'Has your child had any of the following medical tests or diagnoses?',
          type: 'multiple_choice',
          category: 'medical_diagnosis',
          options: [
            { value: 'none', label: 'No tests done', score: 0, exclusive: true },
            { value: 'karyotype_positive', label: 'Chromosome test (karyotype) positive for Down syndrome', score: 10 },
            { value: 'karyotype_negative', label: 'Chromosome test negative for Down syndrome', score: -10 },
            { value: 'prenatal_positive', label: 'Prenatal tests indicated high probability', score: 3 },
            { value: 'doctor_suspects', label: 'Doctor suspects but no test yet', score: 2 },
            { value: 'pending', label: 'Awaiting test results', score: 0 }
          ]
        },
        {
          id: 'DOWN3',
          text: 'Compared to other children, how has your child’s motor development been?',
          type: 'single_choice',
          category: 'motor_development',
          weight: 1.5,
          options: [
            { value: 'normal', label: 'Typical motor milestones', score: 0 },
            { value: 'mild_delay', label: 'Mild motor delay', score: 1 },
            { value: 'moderate_delay', label: 'Moderate motor delay', score: 2 },
            { value: 'severe_delay', label: 'Severe motor delay', score: 3 }
          ]
        },
        {
          id: 'DOWN4',
          text: 'How do you rate your child’s cognitive and language development compared to peers?',
          type: 'single_choice',
          category: 'cognitive_development',
          weight: 1.5,
          options: [
            { value: 'advanced', label: 'Advanced', score: 0 },
            { value: 'normal', label: 'Typical for age', score: 0 },
            { value: 'slightly_delayed', label: 'Slight delay (3–6 months)', score: 1 },
            { value: 'moderately_delayed', label: 'Moderate delay (6–12 months)', score: 2 },
            { value: 'significantly_delayed', label: 'Significant delay (>1 year)', score: 3 },
            { value: 'severe_delay', label: 'Very severe delay', score: 4 }
          ]
        },
        {
          id: 'DOWN5',
          text: 'Does your child have any of the following health problems?',
          type: 'multiple_choice',
          category: 'associated_conditions',
          weight: 1.0,
          options: [
            { value: 'none', label: 'None, generally healthy', score: 0, exclusive: true },
            { value: 'heart', label: 'Heart problems (congenital defects)', score: 2 },
            { value: 'hearing', label: 'Hearing problems', score: 1 },
            { value: 'vision', label: 'Vision problems', score: 1 },
            { value: 'thyroid', label: 'Thyroid problems', score: 1 },
            { value: 'respiratory', label: 'Frequent respiratory infections', score: 1 },
            { value: 'digestive', label: 'Digestive problems', score: 1 },
            { value: 'sleep_apnea', label: 'Sleep apnea (breathing pauses during sleep)', score: 1 }
          ]
        },
        {
          id: 'DOWN6',
          text: 'Is there any family history of Down syndrome?',
          type: 'single_choice',
          category: 'family_history',
          weight: 0.5,
          options: [
            { value: 'no', label: 'No', score: 0 },
            { value: 'distant', label: 'Yes, in distant relatives', score: 1 },
            { value: 'close', label: 'Yes, in immediate family', score: 2 }
          ]
        },
        {
          id: 'DOWN7',
          text: 'How old was the mother when this child was born?',
          type: 'single_choice',
          category: 'risk_factors',
          weight: 0.5,
          options: [
            { value: 'under_25', label: 'Younger than 25 years', score: 0 },
            { value: '25-29', label: '25–29 years', score: 0 },
            { value: '30-34', label: '30–34 years', score: 0 },
            { value: '35-39', label: '35–39 years', score: 1 },
            { value: '40-44', label: '40–44 years', score: 2 },
            { value: '45+', label: '45 years or older', score: 3 }
          ]
        }
      ]
    }
  ]
};

module.exports = questionnaireSchema;
