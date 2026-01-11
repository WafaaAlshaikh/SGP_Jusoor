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
    console.log('🖼️ [OCR] Extracting text from image...');
    
    // ⚠️ **توقف عن استخدام الإعدادات القاسية!**
    // بدلاً من معالجة الصورة بشكل مفرط، دع Tesseract يتعامل معها
    const { data: { text } } = await Tesseract.recognize(
      filePath, // استخدم الملف الأصلي مباشرة
      'eng+ara', // دعنا نجرب العربية أيضاً
      {
        logger: m => {
          if (m.status === 'recognizing text') {
            console.log(`🔄 [OCR Progress] ${(m.progress * 100).toFixed(1)}%`);
          }
        },
        // ⚠️ **إعدادات أبسط وأفضل:**
        oem: 3, // استخدام كل من LSTM والتقليدي (الأفضل)
        psm: 3, // اكتشاف تلقائي للتخطيط (ليس 6!)
        // ⚠️ **توقف عن استخدام whitelist - إنه يحذف معظم النص!**
        // tessedit_char_whitelist: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@.-+() ',
        
        // ⚠️ **بدلاً من ذلك، استخدم هذه الإعدادات المحسنة:**
        tessedit_pageseg_mode: 3, // اكتشاف تلقائي
        preserve_interword_spaces: 1, // الحفاظ على المسافات
        user_defined_dpi: 300, // دقة مناسبة
        // إعدادات خاصة بالعربية والإنجليزية
        tessedit_char_blacklist: '', // لا تحظر أي أحرف
        tessedit_ocr_engine_mode: 3,
      }
    );

    console.log('✅ [OCR] Text extraction complete');
    console.log('📝 [OCR EXTRACTED TEXT (FIRST 500)]:', text.substring(0, 500));
    console.log('📝 [OCR EXTRACTED TEXT (LAST 500)]:', text.substring(Math.max(0, text.length - 500)));
    console.log('📏 [OCR] Total characters:', text.length);
    
    return text;
  } catch (error) {
    console.error('❌ OCR error:', error);
    throw new Error('Failed to extract text from image');
  }
}

/**
 * تنظيف النص المستخرج من OCR لتحسين دقته
 */
static cleanOCRText(ocrText) {
  console.log('🧹 [TEXT CLEANING] Cleaning OCR extracted text...');
  
  let cleanedText = ocrText;
  
  // 1. إصلاح أخطاء OCR الشائعة في عناوين البريد الإلكتروني
  const emailCorrections = [
    { pattern: /\s+@\s+/g, replacement: '@' },        // مسافات حول @
    { pattern: /gma1l\.com/g, replacement: 'gmail.com' },
    { pattern: /gmai1\.com/g, replacement: 'gmail.com' },
    { pattern: /emai1\.com/g, replacement: 'email.com' },
    { pattern: /hotmai1\.com/g, replacement: 'hotmail.com' },
    { pattern: /yaho0\.com/g, replacement: 'yahoo.com' },
    { pattern: /\.c0m/g, replacement: '.com' },
    { pattern: /\.corn/g, replacement: '.com' },
  ];
  
  emailCorrections.forEach(correction => {
    cleanedText = cleanedText.replace(correction.pattern, correction.replacement);
  });
  
  // 2. إصلاح أخطاء في الأرقام
  const numberCorrections = [
    { pattern: /[oO]/g, replacement: '0' },  // حرف o بدل الصفر
    { pattern: /[lI]/g, replacement: '1' },  // حرف l أو I بدل 1
    { pattern: /[zZ]/g, replacement: '2' },  // حرف z بدل 2
  ];
  
  numberCorrections.forEach(correction => {
    cleanedText = cleanedText.replace(correction.pattern, correction.replacement);
  });
  
  // 3. استخراج البريد الإلكتروني يدوياً بعد التنظيف
  const emailRegex = /[\w._%+-]+@[\w.-]+\.[a-zA-Z]{2,}/g;
  const foundEmails = cleanedText.match(emailRegex) || [];
  
  if (foundEmails.length > 0) {
    console.log('✅ [TEXT CLEANING] Found emails after cleaning:', foundEmails);
  }
  
  console.log('🧹 [TEXT CLEANING] Cleaned text sample:', cleanedText.substring(0, 300));
  return cleanedText;
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


    static async analyzeCV(filePath, fileType, fileExt = '') {
    try {
      console.log('=======================================');
      console.log('🔄 STARTING CV ANALYSIS');
      console.log('=======================================');
      console.log(`📄 File: ${filePath}`);
      console.log(`📄 MIME type: ${fileType}, Extension: ${fileExt}`);

      let extractedText = '';

      const isPdf = fileType === 'application/pdf' || fileExt === '.pdf';
      const isImage = fileType.startsWith('image/') || ['.png', '.jpg', '.jpeg'].includes(fileExt);

      if (isPdf) {
        console.log('📖 Extracting text from PDF...');
        extractedText = await this.extractTextFromPDF(filePath);
      } else if (isImage) {
        console.log('🖼️ Extracting text from Image using enhanced OCR...');
        extractedText = await this.extractTextFromImageEnhanced(filePath);
      } else {
        throw new Error('Unsupported file type for CV analysis');
      }

      console.log(`✅ Text extracted: ${extractedText.length} characters`);
      
      // عرض عينة من النص للتحقق
      this.logTextSample(extractedText);

      // التحقق من جودة النص
      if (extractedText.length < 100) {
        console.log('❌ Not enough text extracted');
        return {
          success: false,
          message: 'Could not extract enough text. Please upload a clearer image or PDF.',
          extracted_text_preview: extractedText,
          suggestion: 'Try taking a photo in good lighting or upload PDF format'
        };
      }

      console.log('🤖 Sending to AI for CV analysis...');
      const cvAnalysis = await this.analyzeCVWithAI(extractedText);

      console.log('=======================================');
      console.log('✅ CV ANALYSIS COMPLETE');
      console.log('=======================================');

      return {
        success: true,
        extracted_text: extractedText.substring(0, 2000),
        cv_analysis: cvAnalysis,
        processed_at: new Date()
      };

    } catch (error) {
      console.error('❌ CV analysis error:', error);
      return {
        success: false,
        error: error.message,
        suggestion: 'Try uploading a PDF instead of image for better accuracy'
      };
    }
  }

  /**
   * استخراج النص من PDF
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
   * استخراج النص من صورة - نسخة محسّنة جداً
   */
  static async extractTextFromImageEnhanced(filePath) {
    try {
      console.log('🖼️ [OCR ENHANCED] Starting enhanced OCR...');
      
      // محاولة 1: استخدام الصورة الأصلية مباشرة
      console.log('🔄 [OCR] Attempt 1: Original image with best settings...');
      let text = await this.performOCR(filePath, {
        lang: 'eng',
        oem: 1, // LSTM engine only (أفضل للنصوص الحديثة)
        psm: 3, // Fully automatic page segmentation
      });

      console.log(`✅ [OCR] Attempt 1 result: ${text.length} characters`);

      // إذا كانت النتيجة ضعيفة، جرب معالجة الصورة
      if (text.length < 200 || this.hasLowQuality(text)) {
        console.log('⚠️ [OCR] Low quality result, trying preprocessed image...');
        
        const processedPath = filePath.replace(/\.\w+$/, '_processed.png');
        
        // معالجة متوازنة للصورة
        await sharp(filePath)
          .resize(2000, 2000, { // تكبير معتدل
            fit: 'inside',
            withoutEnlargement: false
          })
          .greyscale() // تحويل للرمادي
          .normalize() // تحسين التباين
          .sharpen() // شحذ معتدل
          .toFile(processedPath);

        console.log('🔄 [OCR] Attempt 2: Preprocessed image...');
        const text2 = await this.performOCR(processedPath, {
          lang: 'eng',
          oem: 1,
          psm: 6, // Assume a single uniform block of text
        });

        // حذف الملف المعالج
        await fs.unlink(processedPath).catch(() => {});

        // استخدم النتيجة الأفضل
        if (text2.length > text.length) {
          console.log(`✅ [OCR] Using preprocessed result: ${text2.length} characters`);
          text = text2;
        }
      }

      // تنظيف النص النهائي
      const cleanedText = this.cleanOCRTextSmart(text);
      
      console.log('✅ [OCR ENHANCED] Extraction complete');
      console.log(`📏 Final text length: ${cleanedText.length} characters`);
      
      return cleanedText;
      
    } catch (error) {
      console.error('❌ Enhanced OCR error:', error);
      throw new Error('Failed to extract text from image');
    }
  }

  /**
   * تنفيذ OCR مع إعدادات محددة
   */
  static async performOCR(imagePath, config) {
    const { data: { text } } = await Tesseract.recognize(
      imagePath,
      config.lang || 'eng',
      {
        logger: m => {
          if (m.status === 'recognizing text') {
            console.log(`🔄 [OCR Progress] ${(m.progress * 100).toFixed(0)}%`);
          }
        },
        oem: config.oem || 1,
        psm: config.psm || 3,
      }
    );
    
    return text;
  }

  /**
   * تنظيف ذكي للنص المستخرج من OCR
   */
  static cleanOCRTextSmart(text) {
    console.log('🧹 [SMART CLEANING] Cleaning OCR text...');
    
    let cleaned = text;
    
    // 1. إصلاح البريد الإلكتروني بعناية
    // تصحيح الأخطاء الشائعة في النطاقات
    cleaned = cleaned.replace(/gma[i1l]+\.com/gi, 'gmail.com');
    cleaned = cleaned.replace(/gma[il]+\s*\.\s*com/gi, 'gmail.com');
    cleaned = cleaned.replace(/yaho[o0]+\.com/gi, 'yahoo.com');
    cleaned = cleaned.replace(/hotma[i1l]+\.com/gi, 'hotmail.com');
    cleaned = cleaned.replace(/out[l1]ook\.com/gi, 'outlook.com');
    
    // إصلاح المسافات حول @
    cleaned = cleaned.replace(/\s+@\s+/g, '@');
    cleaned = cleaned.replace(/(\w+)\s+\.\s+(\w+)@/g, '$1.$2@');
    
    // 2. إصلاح أرقام الهاتف - لكن فقط في سياق أرقام الهاتف
    // استخراج أرقام الهاتف أولاً
    const phonePattern = /(?:\+?\d{1,3}[\s\-]?)?\(?\d{2,4}\)?[\s\-]?\d{2,4}[\s\-]?\d{3,4}/g;
    const phones = cleaned.match(phonePattern) || [];
    
    // لا تصحح الحروف في النص العام، فقط في أرقام الهاتف
    phones.forEach(phone => {
      const correctedPhone = phone
        .replace(/[oO]/g, '0')
        .replace(/[lI]/g, '1');
      cleaned = cleaned.replace(phone, correctedPhone);
    });
    
    // 3. تنظيف عام
    // إزالة أحرف غريبة لكن بحذر
    cleaned = cleaned.replace(/[^\w\s@.\-+()\u0600-\u06FF]/g, ' ');
    
    // إزالة مسافات زائدة
    cleaned = cleaned.replace(/\s+/g, ' ');
    cleaned = cleaned.replace(/\n\s*\n/g, '\n');
    
    // عرض معاينة
    const emailMatch = cleaned.match(/[\w._%+-]+@[\w.-]+\.[a-zA-Z]{2,}/);
    if (emailMatch) {
      console.log('✅ [CLEANING] Found email:', emailMatch[0]);
    }
    
    const phoneMatch = cleaned.match(phonePattern);
    if (phoneMatch) {
      console.log('✅ [CLEANING] Found phone:', phoneMatch[0]);
    }
    
    return cleaned.trim();
  }

  /**
   * التحقق من جودة النص
   */
  static hasLowQuality(text) {
    // كلمات غريبة تدل على OCR سيء
    const gibberishWords = ['wins', 'cane', 'ceyme', 'rey', 'som', 'smsner'];
    const lowerText = text.toLowerCase();
    
    // إذا كان يحتوي على كلمات غريبة كثيرة
    const gibberishCount = gibberishWords.filter(word => 
      lowerText.includes(word)
    ).length;
    
    if (gibberishCount > 2) return true;
    
    // إذا كانت نسبة الأرقام عالية جداً (يدل على OCR سيء)
    const digitRatio = (text.match(/\d/g) || []).length / text.length;
    if (digitRatio > 0.5) return true;
    
    // إذا كانت الكلمات قصيرة جداً بشكل عام
    const words = text.split(/\s+/).filter(w => w.length > 0);
    const avgWordLength = words.reduce((sum, w) => sum + w.length, 0) / words.length;
    if (avgWordLength < 3) return true;
    
    return false;
  }

  /**
   * عرض عينة من النص للتحقق
   */
  static logTextSample(text) {
    console.log('📋 [TEXT SAMPLE]');
    
    const lines = text.split('\n').filter(line => line.trim().length > 0);
    console.log(`   Total lines: ${lines.length}`);
    
    console.log('   First 10 meaningful lines:');
    lines.slice(0, 10).forEach((line, i) => {
      if (line.trim().length > 3) {
        console.log(`   ${i + 1}. ${line.trim()}`);
      }
    });
    
    // البحث عن معلومات مهمة
    const hasEmail = /@/.test(text);
    const hasPhone = /\d{9,}/.test(text);
    const hasExperience = /experience|year/i.test(text);
    
    console.log('   Quality indicators:');
    console.log(`   - Has email: ${hasEmail ? '✅' : '❌'}`);
    console.log(`   - Has phone: ${hasPhone ? '✅' : '❌'}`);
    console.log(`   - Has experience: ${hasExperience ? '✅' : '❌'}`);
  }

  /**
   * تحليل CV باستخدام AI
   */
  static async analyzeCVWithAI(text) {
    try {
      console.log('🤖 Sending CV text to AI...');
      
      const aiResponse = await GroqAIService.analyzeCV(text);

      if (aiResponse.error) {
        console.error('❌ AI error:', aiResponse.error);
        // استخدم استخراج يدوي كبديل
        return this.extractCVInfoManually(text);
      }

      // التحقق من البيانات وتعبئة الفراغات من النص الخام
      const enhanced = this.enhanceAIResponse(aiResponse, text);
      
      console.log('✅ AI Analysis complete');
      this.logAIResults(enhanced);
      
      return enhanced;

    } catch (error) {
      console.error('❌ AI analysis error:', error);
      return this.extractCVInfoManually(text);
    }
  }

  /**
   * تحسين استجابة AI بالبحث في النص الخام
   */
  static enhanceAIResponse(aiResponse, rawText) {
    const enhanced = JSON.parse(JSON.stringify(aiResponse)); // نسخ عميق
    
    // إذا فشل AI في استخراج البريد الإلكتروني، ابحث يدوياً
    if (!enhanced.personal_info?.email || enhanced.personal_info.email.length < 5) {
      const emailMatch = rawText.match(/[\w._%+-]+@[\w.-]+\.[a-zA-Z]{2,}/);
      if (emailMatch) {
        console.log('✅ [ENHANCE] Found email manually:', emailMatch[0]);
        if (!enhanced.personal_info) enhanced.personal_info = {};
        enhanced.personal_info.email = emailMatch[0];
      }
    }
    
    // البحث عن رقم الهاتف
    if (!enhanced.personal_info?.phone || enhanced.personal_info.phone.length < 9) {
      const phoneMatch = rawText.match(/(?:\+\d{1,3}[\s\-]?)?\d{9,}/);
      if (phoneMatch) {
        console.log('✅ [ENHANCE] Found phone manually:', phoneMatch[0]);
        if (!enhanced.personal_info) enhanced.personal_info = {};
        enhanced.personal_info.phone = phoneMatch[0].replace(/\s+/g, '');
      }
    }
    
    // البحث عن الاسم إذا كان فارغاً
    if (!enhanced.personal_info?.full_name_en && !enhanced.personal_info?.full_name_ar) {
      const lines = rawText.split('\n').filter(l => l.trim().length > 3);
      if (lines.length > 0) {
        // أول سطر غالباً هو الاسم
        const firstLine = lines[0].trim();
        if (firstLine.length < 50 && !/\d{5,}/.test(firstLine)) {
          console.log('✅ [ENHANCE] Found name from first line:', firstLine);
          if (!enhanced.personal_info) enhanced.personal_info = {};
          enhanced.personal_info.full_name_en = firstLine;
        }
      }
    }
    
    return enhanced;
  }

  /**
   * عرض نتائج AI
   */
  static logAIResults(analysis) {
    console.log('📊 AI Analysis Results:');
    console.log(`   👤 Name: ${analysis.personal_info?.full_name_en || analysis.personal_info?.full_name_ar || 'N/A'}`);
    console.log(`   📧 Email: ${analysis.personal_info?.email || 'Not found'}`);
    console.log(`   📱 Phone: ${analysis.personal_info?.phone || 'Not found'}`);
    console.log(`   🎯 Specialization: ${analysis.professional_info?.specialization_en || 'N/A'}`);
    console.log(`   ⏳ Experience: ${analysis.professional_info?.years_experience || 0} years`);
  }

  /**
   * استخراج معلومات CV يدوياً (كبديل)
   */
  static extractCVInfoManually(text) {
    console.log('🔍 [MANUAL] Performing manual extraction...');
    
    const result = {
      personal_info: {
        full_name_en: '',
        email: '',
        phone: '',
        location: ''
      },
      professional_info: {
        specialization_en: '',
        years_experience: 0,
        key_skills: []
      },
      education: {
        highest_degree: '',
        institution: ''
      },
      confidence_score: 0.5,
      source: 'manual_extraction'
    };

    const lines = text.split('\n').filter(line => line.trim().length > 2);
    
    // استخراج الاسم من أول سطر معقول
    const firstValidLine = lines.find(line => 
      line.length > 3 && 
      line.length < 50 &&
      !/\d{7,}/.test(line) &&
      !/@/.test(line)
    );
    
    if (firstValidLine) {
      result.personal_info.full_name_en = firstValidLine.trim();
      console.log('📝 [MANUAL] Name:', result.personal_info.full_name_en);
    }

    // استخراج البريد الإلكتروني
    const emailMatch = text.match(/[\w._%+-]+@[\w.-]+\.[a-zA-Z]{2,}/);
    if (emailMatch) {
      result.personal_info.email = emailMatch[0];
      console.log('📝 [MANUAL] Email:', result.personal_info.email);
    }

    // استخراج الهاتف
    const phoneMatch = text.match(/(?:\+\d{1,3}[\s\-]?)?\d{9,}/);
    if (phoneMatch) {
      result.personal_info.phone = phoneMatch[0].replace(/\s+/g, '');
      console.log('📝 [MANUAL] Phone:', result.personal_info.phone);
    }

    // استخراج سنوات الخبرة
    const expMatch = text.match(/(\d+)\s*(?:years?|yrs?)/i);
    if (expMatch) {
      result.professional_info.years_experience = parseInt(expMatch[1]);
      console.log('📝 [MANUAL] Experience:', result.professional_info.years_experience);
    }

    // البحث عن تخصصات شائعة
    const specializations = [
      'Speech Therapist', 'Speech Language Pathologist', 
      'Occupational Therapist', 'Physical Therapist',
      'Psychologist', 'Special Education Teacher',
      'Behavioral Therapist', 'Social Worker'
    ];
    
    for (const spec of specializations) {
      if (text.toLowerCase().includes(spec.toLowerCase())) {
        result.professional_info.specialization_en = spec;
        console.log('📝 [MANUAL] Specialization:', spec);
        break;
      }
    }

    return result;
  }

  /**
   * تحليل مستند طبي (الدالة الأصلية)
   */
  static async analyzeDocument(filePath, fileType, fileExt = '') {
    try {
      console.log(`📄 Starting document analysis: ${filePath}`);

      let extractedText = '';

      const isPdf = fileType === 'application/pdf' || fileExt === '.pdf';
      const isImage = fileType.startsWith('image/') || ['.png', '.jpg', '.jpeg'].includes(fileExt);

      if (isPdf) {
        extractedText = await this.extractTextFromPDF(filePath);
      } else if (isImage) {
        extractedText = await this.extractTextFromImageEnhanced(filePath);
      } else {
        throw new Error('Unsupported file type');
      }

      if (extractedText.length < 50) {
        return {
          success: false,
          message: 'Could not extract enough text',
          extracted_text_preview: extractedText
        };
      }

      const aiAnalysis = await this.analyzeTextWithAI(extractedText);

      return {
        success: true,
        extracted_text: extractedText.substring(0, 1000),
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
   * تحليل نص طبي باستخدام AI
   */
  static async analyzeTextWithAI(text) {
    try {
      const prompt = `You are a medical document analyzer. Extract key information from this medical text:

${text.substring(0, 3000)}

Return ONLY valid JSON with this structure:
{
  "conditions": [],
  "medications": [],
  "allergies": [],
  "treatments": [],
  "symptoms": [],
  "test_results": [],
  "additional_notes": "",
  "confidence_score": 0.85
}`;

      const response = await GroqAIService.analyzeSymptoms(prompt, '', '');
      
      let parsedData;
      if (typeof response === 'object') {
        parsedData = response;
      } else if (typeof response === 'string') {
        const jsonMatch = response.match(/\{[\s\S]*\}/);
        parsedData = jsonMatch ? JSON.parse(jsonMatch[0]) : { raw_response: response };
      }

      return parsedData;

    } catch (error) {
      console.error('❌ AI analysis error:', error);
      return { error: error.message, confidence_score: 0 };
    }
  }
}

module.exports = DocumentAnalysisService;