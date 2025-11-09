const axios = require('axios');

class TranslationService {
  static async translateText(text, targetLang) {
    try {
      if (!text || text.trim() === '') return text;
      
      const response = await axios.get('https://translate.googleapis.com/translate_a/single', {
        params: {
          client: 'gtx',
          sl: 'auto',
          tl: targetLang,
          dt: 't',
          q: text
        },
        timeout: 10000
      });
      
      if (response.data && response.data[0]) {
        return response.data[0].map(item => item[0]).join('');
      }
      return text;
    } catch (error) {
      console.error('Translation error:', error.message);
      return text;
    }
  }

  static detectLanguage(text) {
    const arabicRegex = /[\u0600-\u06FF]/;
    const englishRegex = /[A-Za-z]/;
    
    if (arabicRegex.test(text)) return 'ar';
    if (englishRegex.test(text)) return 'en';
    return 'en';
  }
}

module.exports = TranslationService;