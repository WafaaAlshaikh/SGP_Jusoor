// services/documentAnalysisService.js
const pdfParse = require('pdf-parse');

const Tesseract = require('tesseract.js');
const sharp = require('sharp');
const fs = require('fs').promises;
const GroqAIService = require('./groqAIService');

class DocumentAnalysisService {
  
  /**
   * تحليل ملف طبي واستخراج معلومات مهمة
   */
  static async analyzeDocument(filePath, fileType, fileExt = '') {
  try {
    console.log(`📄 Starting document analysis: ${filePath}`);
    console.log(`📄 MIME type: ${fileType}, Extension: ${fileExt}`);

    let extractedText = '';

    const isPdf =
      fileType === 'application/pdf' || fileExt === '.pdf';

    const isImage =
      fileType.startsWith('image/') ||
      ['.png', '.jpg', '.jpeg'].includes(fileExt);

    if (isPdf) {
      extractedText = await this.extractTextFromPDF(filePath);
    } else if (isImage) {
      extractedText = await this.extractTextFromImage(filePath);
    } else {
      throw new Error('Unsupported file type for analysis');
    }

      console.log(`📝 Extracted text length: ${extractedText.length} characters`);

      // إذا لم يتم استخراج نص كافٍ
      if (extractedText.length < 50) {
        return {
          success: false,
          message: 'Could not extract enough text from document',
          extracted_text_preview: extractedText
        };
      }

      // إرسال النص للـ AI للتحليل
      const aiAnalysis = await this.analyzeTextWithAI(extractedText);

      return {
        success: true,
        extracted_text: extractedText.substring(0, 1000), // أول 1000 حرف
        ai_analysis: aiAnalysis,
        processed_at: new Date()
      };

    } catch (error) {
      console.error('❌ Document analysis error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * استخراج النص من ملف PDF
   */
  static async extractTextFromPDF(filePath) {
  try {
    const dataBuffer = await fs.readFile(filePath);
    const data = await pdfParse(dataBuffer);
    return data.text;
  } catch (error) {
    console.error('❌ PDF parsing error:', error);
    throw new Error('Failed to parse PDF');
  }
}


  /**
   * استخراج النص من صورة باستخدام OCR
   */
  static async extractTextFromImage(filePath) {
    try {
      // تحسين جودة الصورة قبل OCR
      const processedImagePath = filePath.replace(/\.\w+$/, '_processed.png');
      
      await sharp(filePath)
        .greyscale()
        .normalize()
        .sharpen()
        .toFile(processedImagePath);

      // استخدام Tesseract للتعرف على النص
      const { data: { text } } = await Tesseract.recognize(
        processedImagePath,
        'eng+ara', // دعم الإنجليزية والعربية
        {
          logger: m => console.log(m)
        }
      );

      // حذف الصورة المعالجة
      await fs.unlink(processedImagePath);

      return text;
    } catch (error) {
      console.error('❌ OCR error:', error);
      throw new Error('Failed to extract text from image');
    }
  }

  /**
   * تحليل النص المستخرج باستخدام AI
   */
  static async analyzeTextWithAI(text) {
    try {
      const prompt = `
You are a medical document analyzer. Extract key medical information from the following text.

**Text to analyze:**
${text.substring(0, 3000)} // نقطع النص إذا كان طويلاً جداً

**Extract and provide:**
1. Diagnosed conditions or suspected conditions
2. Current medications
3. Known allergies
4. Previous treatments or therapies
5. Key symptoms mentioned
6. Any test results or assessments

**Return ONLY valid JSON:**
{
  "conditions": ["condition1", "condition2"],
  "medications": ["medication1"],
  "allergies": ["allergy1"],
  "treatments": ["treatment1"],
  "symptoms": ["symptom1", "symptom2"],
  "test_results": ["result1"],
  "additional_notes": "any other important information",
  "confidence_score": 0.85
}

If information is not found, return empty arrays.
`;

      const response = await GroqAIService.analyzeSymptoms(prompt, '', '');

      // محاولة استخراج JSON من الاستجابة
      let parsedData;

try {
  // ✅ إذا كان الرد Object (وهو حالتك الآن)
  if (typeof response === 'object') {
    parsedData = response;
  }
  // ✅ إذا كان String (احتياط)
  else if (typeof response === 'string') {
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      parsedData = JSON.parse(jsonMatch[0]);
    } else {
      throw new Error('No JSON found in AI response');
    }
  }
  else {
    throw new Error('Unsupported AI response format');
  }
} catch (parseError) {
  console.error('❌ JSON parsing error:', parseError);
  parsedData = {
    raw_response: response,
    confidence_score: 0
  };
}


      return parsedData;

    } catch (error) {
      console.error('❌ AI analysis error:', error);
      return {
        error: error.message,
        confidence_score: 0
      };
    }
  }
}

module.exports = DocumentAnalysisService;