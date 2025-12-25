const { Op } = require('sequelize');
const Groq = require('groq-sdk');

const { Institution, InstitutionFAQ, InstitutionPageContent, InstitutionProgram, InstitutionProject, InstitutionNews } = require('../model/index');

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY,
});

async function getApprovedInstitutionOrNull(institutionId) {
  return Institution.findOne({
    where: {
      institution_id: institutionId,
      is_active: true,
      approval_status: 'Approved',
    },
  });
}

function buildKnowledgeBase({ faq, content, programs, projects, news }) {
  const parts = [];

  if (Array.isArray(content) && content.length) {
    parts.push('INSTITUTION PAGE CONTENT:');
    content.forEach((c) => {
      parts.push(`- [${c.key}] ${c.title || ''}`.trim());
      parts.push(`${c.content || ''}`.trim());
    });
  }

  if (Array.isArray(faq) && faq.length) {
    parts.push('INSTITUTION FAQ:');
    faq.forEach((f, idx) => {
      parts.push(`Q${idx + 1}: ${f.question}`);
      parts.push(`A${idx + 1}: ${f.answer}`);
    });
  }

  if (Array.isArray(programs) && programs.length) {
    parts.push('PROGRAMS:');
    programs.forEach((p) => {
      parts.push(`- ${p.title}: ${p.description || ''}`.trim());
    });
  }

  if (Array.isArray(projects) && projects.length) {
    parts.push('PROJECTS:');
    projects.forEach((p) => {
      const goal = p.goal_amount != null ? `goal=${p.goal_amount}` : '';
      const raised = p.raised_amount != null ? `raised=${p.raised_amount}` : '';
      const status = p.status ? `status=${p.status}` : '';
      parts.push(`- ${p.title}: ${p.description || ''}`.trim());
      parts.push(`  (${[status, goal, raised].filter(Boolean).join(', ')})`);
    });
  }

  if (Array.isArray(news) && news.length) {
    parts.push('LATEST NEWS:');
    news.forEach((n) => {
      parts.push(`- ${n.title}${n.published_at ? ` (${n.published_at})` : ''}`);
      if (n.summary) parts.push(`  ${n.summary}`);
    });
  }

  return parts.filter(Boolean).join('\n');
}

exports.askInstitutionAI = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const question = (req.body?.question ?? '').toString().trim();

    if (!question) {
      return res.status(400).json({ success: false, message: 'Question is required' });
    }

    const inst = await getApprovedInstitutionOrNull(institutionId);
    if (!inst) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const [faq, content, programs, projects, news] = await Promise.all([
      InstitutionFAQ.findAll({
        where: { institution_id: institutionId, is_active: true },
        order: [['sort_order', 'ASC'], ['faq_id', 'ASC']],
        raw: true,
      }),
      InstitutionPageContent.findAll({
        where: { institution_id: institutionId, is_active: true },
        order: [['sort_order', 'ASC'], ['content_id', 'ASC']],
        raw: true,
      }),
      InstitutionProgram.findAll({
        where: { institution_id: institutionId, is_active: true },
        order: [['sort_order', 'ASC'], ['program_id', 'ASC']],
        raw: true,
      }),
      InstitutionProject.findAll({
        where: { institution_id: institutionId, is_active: true },
        order: [['sort_order', 'ASC'], ['project_id', 'ASC']],
        raw: true,
      }),
      InstitutionNews.findAll({
        where: {
          institution_id: institutionId,
          is_published: true,
          published_at: { [Op.ne]: null },
        },
        order: [['published_at', 'DESC'], ['news_id', 'DESC']],
        limit: 5,
        raw: true,
      }),
    ]);

    const knowledgeBase = buildKnowledgeBase({ faq, content, programs, projects, news });

    if (!process.env.GROQ_API_KEY) {
      return res.status(200).json({
        success: true,
        data: {
          answer: 'AI service is not configured right now. Please contact the institution directly or try again later.',
          sources: {
            faq_count: faq.length,
            content_count: content.length,
            programs_count: programs.length,
            projects_count: projects.length,
            news_count: news.length,
          },
          user: req.user ? { user_id: req.user.user_id, role: req.user.role } : null,
        }
      });
    }

    const systemPrompt = `You are an assistant for a therapy/education institution public page.
Answer the user's question using ONLY the provided knowledge base.
If the answer is not found in the knowledge base, say you don't have that information and suggest contacting the institution.
Be concise, helpful, and respond in Arabic unless the user writes in English.
Do NOT invent phone numbers, emails, prices, or policies.
If the user asks about donations, mention that donation requires login.
`;

    const userPrompt = `INSTITUTION NAME: ${inst.name}

KNOWLEDGE BASE:
${knowledgeBase}

USER QUESTION:
${question}

Return JSON ONLY with this exact structure:
{
  "answer": "...",
  "confidence": "high|medium|low",
  "suggested_actions": ["..."],
  "matched_section": "faq|content|programs|projects|news|unknown"
}`;

    const chatCompletion = await groq.chat.completions.create({
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      model: 'llama-3.3-70b-versatile',
      temperature: 0.2,
      max_tokens: 900,
    });

    const contentText = chatCompletion.choices[0]?.message?.content || '{}';
    const jsonMatch = contentText.match(/\{[\s\S]*\}/);

    let parsed;
    try {
      parsed = JSON.parse(jsonMatch ? jsonMatch[0] : contentText);
    } catch (_) {
      parsed = {
        answer: contentText.toString().trim(),
        confidence: 'low',
        suggested_actions: ['Contact the institution for more details'],
        matched_section: 'unknown',
      };
    }

    return res.status(200).json({
      success: true,
      data: {
        ...parsed,
        sources: {
          faq_count: faq.length,
          content_count: content.length,
          programs_count: programs.length,
          projects_count: projects.length,
          news_count: news.length,
        },
        user: req.user ? { user_id: req.user.user_id, role: req.user.role } : null,
      }
    });
  } catch (error) {
    console.error('Error in institution AI assistant:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};
