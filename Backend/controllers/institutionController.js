// controllers/institutionController.js
const Institution = require('../model/Institution');

exports.getInstitutions = async (req, res) => {
  try {
    const institutions = await Institution.findAll({
      attributes: ['institution_id', 'name', 'description', 'location', 'website']
    });
    res.status(200).json(institutions);
  } catch (error) {
    console.error('Error fetching institutions:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};


