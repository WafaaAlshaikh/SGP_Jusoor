// utils/sessionSuitability.js
exports.checkSessionSuitability = (sessionType, childDiagnosis) => {
  // إذا الجلسة مناسبة لجميع الحالات
  if (!sessionType.target_conditions || sessionType.target_conditions.length === 0) {
    return { suitable: true, reason: 'Suitable for all conditions' };
  }
  
  // إذا الطفل بدون تشخيص
  if (!childDiagnosis) {
    return { 
      suitable: false, 
      reason: 'Child needs diagnosis to book specialized sessions' 
    };
  }
  
  // التحقق إذا التشخيص مدرج في الجلسات المناسبة
  const isSuitable = sessionType.target_conditions.includes(childDiagnosis);
  
  return {
    suitable: isSuitable,
    reason: isSuitable ? 
      `Suitable for ${childDiagnosis}` : 
      `Not suitable for ${childDiagnosis}. Suitable for: ${sessionType.target_conditions.join(', ')}`
  };
};