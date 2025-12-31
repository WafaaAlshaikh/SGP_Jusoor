const Groq = require('groq-sdk');

class AIEquipmentNeedsService {
  static getGroqClient() {
    if (!process.env.GROQ_API_KEY) return null;
    return new Groq({ apiKey: process.env.GROQ_API_KEY });
  }

  static fallbackSuggest(notes) {
    const text = (notes || '').toLowerCase();
    const suggestions = [];

    const pushUnique = (item) => {
      const key = `${(item.equipment_type || '').toLowerCase()}|${(item.equipment_name || '').toLowerCase()}`;
      if (!suggestions.some(s => `${(s.equipment_type || '').toLowerCase()}|${(s.equipment_name || '').toLowerCase()}` === key)) {
        suggestions.push(item);
      }
    };

    if (text.includes('wheelchair') || text.includes('كرسي متحرك') || text.includes('كرسي')) {
      pushUnique({ equipment_name: 'Wheelchair', equipment_type: 'wheelchair', severity: 'high', reason: 'Mobility support mentioned in evaluation notes' });
    }

    if (text.includes('walker') || text.includes('مشايه')) {
      pushUnique({ equipment_name: 'Walker', equipment_type: 'walker', severity: 'medium', reason: 'Walking support mentioned in evaluation notes' });
    }

    if (text.includes('hearing') || text.includes('سماعه') || text.includes('سمع')) {
      pushUnique({ equipment_name: 'Hearing Aid', equipment_type: 'hearing_aid', severity: 'medium', reason: 'Hearing support mentioned in evaluation notes' });
    }

    if (text.includes('communication device') || text.includes('aac') || text.includes('تواصل')) {
      pushUnique({ equipment_name: 'Communication Device (AAC)', equipment_type: 'aac_device', severity: 'medium', reason: 'Communication support mentioned in evaluation notes' });
    }

    if (text.includes('sensory') || text.includes('حسي')) {
      pushUnique({ equipment_name: 'Sensory Tools', equipment_type: 'sensory_tools', severity: 'low', reason: 'Sensory regulation mentioned in evaluation notes' });
    }

    return suggestions;
  }

  static cleanAIResponse(response) {
    if (!response) return '[]';
    return response
      .replace(/```json/g, '')
      .replace(/```/g, '')
      .trim();
  }

  static async suggestEquipmentNeeds(notes) {
    const groq = this.getGroqClient();
    if (!groq) {
      return this.fallbackSuggest(notes);
    }

    const prompt = `
You are a medical rehabilitation assistant. Extract ONLY equipment needs from the evaluation notes.

NOTES:
"""
${notes || ''}
"""

Return ONLY a valid JSON array. Each item must have:
- equipment_name (string)
- equipment_type (string, snake_case)
- severity (one of: low, medium, high)
- reason (string)

Rules:
- Do not include therapy sessions.
- Do not include medications.
- Keep the list short (0-6 items).

Return ONLY JSON:
`;

    try {
      const completion = await groq.chat.completions.create({
        messages: [
          {
            role: 'system',
            content: 'Return ONLY valid JSON array. No explanations.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        model: 'llama-3.1-8b-instant',
        temperature: 0.1,
        max_tokens: 600,
        stream: false
      });

      const raw = completion.choices[0]?.message?.content?.trim();
      const cleaned = this.cleanAIResponse(raw);
      const parsed = JSON.parse(cleaned);
      if (!Array.isArray(parsed)) return [];

      return parsed
        .filter(x => x && typeof x === 'object')
        .map(x => ({
          equipment_name: String(x.equipment_name || '').trim(),
          equipment_type: String(x.equipment_type || '').trim(),
          severity: ['low', 'medium', 'high'].includes(String(x.severity)) ? String(x.severity) : 'medium',
          reason: String(x.reason || '').trim()
        }))
        .filter(x => x.equipment_name);
    } catch (e) {
      return this.fallbackSuggest(notes);
    }
  }
}

module.exports = AIEquipmentNeedsService;
