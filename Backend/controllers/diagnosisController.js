const Diagnosis = require('../model/Diagnosis');

// ================= GET ALL DIAGNOSES =================
exports.getDiagnoses = async (req, res) => {
  try {
    const diagnoses = await Diagnosis.findAll({
      attributes: ['diagnosis_id', 'name', 'description']
    });

    res.status(200).json(diagnoses);

  } catch (error) {
    console.error('Error fetching diagnoses:', error);
    res.status(500).json({ 
      message: 'Failed to fetch diagnoses', 
      error: error.message 
    });
  }
};

// ================= GET SINGLE DIAGNOSIS =================
exports.getDiagnosis = async (req, res) => {
  try {
    const diagnosisId = req.params.id;

    const diagnosis = await Diagnosis.findByPk(diagnosisId, {
      attributes: ['diagnosis_id', 'name', 'description']
    });

    if (!diagnosis) {
      return res.status(404).json({ message: 'Diagnosis not found' });
    }

    res.status(200).json(diagnosis);

  } catch (error) {
    console.error('Error fetching diagnosis:', error);
    res.status(500).json({ 
      message: 'Failed to fetch diagnosis', 
      error: error.message 
    });
  }
};